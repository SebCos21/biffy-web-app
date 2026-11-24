import 'dart:async';
import 'dart:typed_data';

import 'package:biffy/app/di/injection.dart';
import 'package:biffy/core/constants/catalog_constants.dart';
import 'package:biffy/core/utils/clock.dart';
import 'package:biffy/data/models/catalog.dart';
import 'package:biffy/data/repositories/catalog_snapshot.dart';
import 'package:biffy/data/repositories/in_memory_catalog_repository.dart';
import 'package:biffy/data/repositories/supabase_catalog_repository.dart';
import 'package:biffy/domain/ports/catalog_ports.dart';
import 'package:biffy/domain/repositories/catalog_repository.dart';
import 'package:biffy/domain/usecases/catalog/catalog_usecases.dart';
import 'package:biffy/features/catalog/bloc/catalog_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Contexto falso: un punto fijo y un stream para simular que cambió.
class _FakeContext implements CatalogContextPort {
  _FakeContext(this.point);

  @override
  DeliveryPoint point;

  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  /// Simula que la sesión cambió de punto de entrega.
  void move(DeliveryPoint p) {
    point = p;
    _changes.add(null);
  }
}

/// Catálogo en memoria cuyas escrituras de platos rechaza la base (RLS).
class _DeniedRepo extends InMemoryCatalogRepository {
  @override
  Future<CatalogResult> upsertDish(Dish dish) async => CatalogResult.denied(
    CatalogAction.saveDish,
    const CatalogWriteDenied('editar el plato'),
  );
}

/// Catálogo en memoria que lanza al marcar agotado (fallo inesperado).
class _ThrowingRepo extends InMemoryCatalogRepository {
  @override
  Future<CatalogResult> setDishSoldOut(String dishId, bool soldOut) =>
      Future.error(StateError('sin red'));
}

/// Fuente de filas para el repositorio de Supabase de pruebas.
Future<CatalogRows> _rows() async => const CatalogRows(
  branches: [
    {'id': 'br-1', 'business_id': 'biz-1', 'name': 'Sede'},
  ],
  dishes: [
    {'id': 'd-1', 'branch_id': 'br-1', 'name': 'Plato'},
  ],
);

/// Coincide con un estado cuyo último resultado tiene [code].
TypeMatcher<CatalogState> _outcome(String code) =>
    isA<CatalogState>().having((s) => s.outcome?.result.code, 'code', code);

/// Pruebas con bloc_test del catálogo: escrituras, errores tipados, alcance y
/// el comportamiento sin conexión de HU-2.
void main() {
  late _FakeContext context;
  final clock = Clock.fixed(kTestNow);

  /// Bloc sobre [repo] con el contexto falso.
  CatalogBloc bloc(CatalogRepository repo) =>
      CatalogBloc(CatalogUseCases(repo: repo, context: context, clock: clock));

  setUp(() {
    context = _FakeContext(pointById('icesi-biblioteca'));
  });

  group('CatalogBloc · escrituras', () {
    late InMemoryCatalogRepository repo;
    setUp(() => repo = InMemoryCatalogRepository());

    blocTest<CatalogBloc, CatalogState>(
      'guardar un plato emite ok y el plato queda en el catálogo',
      build: () => bloc(repo),
      act: (b) {
        final d = repo.dishById('qbano-pollo')!..name = 'Pollo nuevo';
        return b.request(DishSaved(d));
      },
      expect: () => contains(_outcome('ok')),
      verify: (b) => expect(b.dishById('qbano-pollo')!.name, 'Pollo nuevo'),
    );

    blocTest<CatalogBloc, CatalogState>(
      'si RLS rechaza la escritura emite forbidden con mensaje en español',
      build: () => bloc(_DeniedRepo()),
      act: (b) => b.request(DishSaved(b.dishById('qbano-pollo')!)),
      expect: () => [
        _outcome('forbidden').having(
          (s) => s.outcome?.result.message,
          'mensaje',
          startsWith('No tienes permiso para editar el plato.'),
        ),
      ],
    );

    blocTest<CatalogBloc, CatalogState>(
      '«Disponible» se revierte si la base no lo guarda',
      build: () => bloc(_DeniedRepo()),
      act: (b) =>
          b.request(DishAvailabilityChanged(b.dishById('qbano-pollo')!, false)),
      expect: () => [_outcome('forbidden')],
      verify: (b) => expect(b.dishById('qbano-pollo')!.active, isTrue),
    );

    blocTest<CatalogBloc, CatalogState>(
      'una excepción del repositorio se convierte en network',
      build: () => bloc(_ThrowingRepo()),
      act: (b) =>
          b.request(DishSoldOutChanged(b.dishById('qbano-pollo')!, true)),
      expect: () => [
        _outcome('network').having(
          (s) => s.outcome?.result.message,
          'mensaje',
          'No pudimos guardar el cambio.',
        ),
      ],
      verify: (b) => expect(b.dishById('qbano-pollo')!.soldOut, isFalse),
    );

    blocTest<CatalogBloc, CatalogState>(
      'pausar un negocio pausa todas sus sedes',
      build: () => bloc(repo),
      act: (b) {
        final biz = b.restaurantById('qbano-icesi')!.businessId;
        return b.request(BusinessPauseChanged(biz, true));
      },
      expect: () => contains(_outcome('ok')),
      verify: (b) => expect(
        b.isBusinessPaused(b.restaurantById('qbano-icesi')!.businessId),
        isTrue,
      ),
    );

    blocTest<CatalogBloc, CatalogState>(
      'en demo no hay Storage: subir la foto devuelve el error en español',
      build: () => bloc(repo),
      act: (b) =>
          b.request(DishPhotoUploaded(businessId: 'biz', bytes: Uint8List(0))),
      expect: () => [
        _outcome('network').having(
          (s) => s.outcome?.result.message,
          'mensaje',
          'No pudimos subir la foto.',
        ),
      ],
    );
  });

  group('CatalogBloc · lecturas y alcance', () {
    blocTest<CatalogBloc, CatalogState>(
      'cambiar el punto de entrega repinta el catálogo con la regla de alcance',
      build: () => bloc(InMemoryCatalogRepository()),
      act: (b) => context.move(pointById('chapinero')),
      expect: () => [
        isA<CatalogState>().having((s) => s.revision, 'revision', 1),
      ],
      verify: (b) => expect(
        b.reachableRestaurants.map((r) => r.id),
        isNot(contains('qbano-icesi')),
      ),
    );
  });

  group('CatalogBloc · sin conexión (HU-2)', () {
    blocTest<CatalogBloc, CatalogState>(
      'con copia guardada y sin red queda offline y el reintento lo informa',
      build: () => bloc(
        SupabaseCatalogRepository.forTest(
          source: () => Future.error(Exception('Sin red')),
          cache: MemoryCatalogCache(encodeCatalogRows(_rowsSync)),
        ),
      ),
      act: (b) => b.request(CatalogRefreshRequested()),
      expect: () => [
        _outcome('network')
            .having((s) => s.offline, 'offline', isTrue)
            .having(
              (s) => s.outcome?.result.message,
              'mensaje',
              contains('mostrando el menú guardado'),
            ),
      ],
      verify: (b) {
        expect(b.offline, isTrue);
        expect(b.hasCatalog, isTrue);
      },
    );

    blocTest<CatalogBloc, CatalogState>(
      'con red el reintento sale ok y deja de estar offline',
      build: () => bloc(SupabaseCatalogRepository.forTest(source: _rows)),
      act: (b) => b.request(CatalogRefreshRequested()),
      expect: () =>
          contains(_outcome('ok').having((s) => s.offline, 'offline', isFalse)),
      verify: (b) => expect(b.restaurantById('br-1'), isNotNull),
    );

    test(
      'sin cliente, una escritura remota vuelve como resultado (no lanza)',
      () async {
        final repo = SupabaseCatalogRepository.forTest(source: _rows);
        await repo.refresh();
        final r = await repo.deleteDish('d-1');
        expect(r.ok, isFalse);
        expect(r.code, 'network');
        expect(r.message, 'No pudimos eliminar el producto.');
      },
    );
  });

  test('el CatalogBloc de la app se registra una sola vez en GetIt', () async {
    await makeServices();
    expect(getIt<CatalogBloc>(), same(getIt<CatalogBloc>()));
  });
}

/// Mismas filas que [_rows], ya resueltas, para guardarlas como copia.
const _rowsSync = CatalogRows(
  branches: [
    {'id': 'br-1', 'business_id': 'biz-1', 'name': 'Sede'},
  ],
  dishes: [
    {'id': 'd-1', 'branch_id': 'br-1', 'name': 'Plato'},
  ],
);
