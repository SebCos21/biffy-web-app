import 'package:biffy/data/repositories/catalog_snapshot.dart';
import 'package:biffy/data/repositories/supabase_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fuente de filas controlable: devuelve [rows] o falla como sin red.
class FakeSource {
  /// Crea la fuente con las filas que devolverá.
  FakeSource(this.rows);

  /// Filas que devuelve cada lectura correcta.
  CatalogRows rows;

  /// Si es `true`, la próxima lectura lanza como si no hubiera red.
  bool fail = false;

  /// Lectura simulada del backend.
  Future<CatalogRows> call() async {
    if (fail) throw Exception('Sin red');
    return rows;
  }
}

/// Caché que falla al escribir (disco lleno o bloqueado).
class ThrowingCache implements CatalogCache {
  /// No hay copia que leer.
  @override
  Future<String?> read() async => null;

  /// Siempre falla al escribir.
  @override
  Future<void> write(String value) async => throw Exception('Disco lleno');
}

/// Caché en memoria que cuenta cuántas veces se leyó.
class CountingCache extends MemoryCatalogCache {
  /// Crea la caché con una copia previa.
  CountingCache([super.value]);

  /// Lecturas hechas.
  int reads = 0;

  /// Cuenta la lectura y devuelve la copia.
  @override
  Future<String?> read() {
    reads++;
    return super.read();
  }
}

/// Catálogo de prueba: una sede viva, una borrada y platos de ambas.
CatalogRows fixture({bool withOwner = false}) => CatalogRows(
  publicBusinesses: [
    {
      'id': 'biz-1',
      'brand': 'Marca pública',
      'cuisine': 'almuerzo',
      'description': 'Menú del día',
    },
  ],
  ownBusinesses: withOwner
      ? [
          {
            'id': 'biz-1',
            'brand': 'Marca completa',
            'legal_name': 'Marca SAS',
            'nit': '900123456',
            'cuisine': 'almuerzo',
            'description': 'Menú del día',
            'bank_name': 'Banco Secreto',
            'account_number': '0011223344',
          },
        ]
      : const [],
  branches: [
    {'id': 'br-1', 'business_id': 'biz-1', 'name': 'Sede viva'},
    {
      'id': 'br-2',
      'business_id': 'biz-1',
      'name': 'Sede borrada',
      'deleted_at': '2026-11-01T10:00:00Z',
    },
  ],
  dishes: [
    {'id': 'd-1', 'branch_id': 'br-1', 'name': 'Plato vivo', 'price': 12000},
    {
      'id': 'd-2',
      'branch_id': 'br-1',
      'name': 'Plato borrado',
      'deleted_at': '2026-11-01T10:00:00Z',
    },
    {'id': 'd-3', 'branch_id': 'br-2', 'name': 'Plato de sede borrada'},
  ],
  options: [
    {
      'id': 'o-1',
      'dish_id': 'd-1',
      'kind': 'size',
      'label': 'Grande',
      'price_delta': 2000,
    },
    {
      'id': 'o-2',
      'dish_id': 'd-2',
      'kind': 'extra',
      'label': 'Queso',
      'price_delta': 1500,
    },
  ],
);

void main() {
  group('Catálogo sin conexión (HU-2)', () {
    test('guarda la copia sin datos bancarios y la vuelve a leer', () async {
      final cache = MemoryCatalogCache();
      final online = SupabaseCatalogRepository.forTest(
        source: FakeSource(fixture(withOwner: true)).call,
        cache: cache,
      );
      await online.refresh();

      final saved = cache.value!;
      expect(saved, contains('Sede viva'));
      expect(saved, isNot(contains('account_number')));
      expect(saved, isNot(contains('bank_name')));
      expect(saved, isNot(contains('Banco Secreto')));

      final offline = SupabaseCatalogRepository.forTest(
        source: (FakeSource(fixture())..fail = true).call,
        cache: cache,
      );
      await offline.refresh();
      expect(offline.offline, isTrue);
      expect(offline.restaurants.map((r) => r.id), ['br-1']);
      expect(offline.businessById('biz-1')!.brand, 'Marca pública');
    });

    test('descarta sedes y platos con deleted_at y sus opciones', () async {
      final repo = SupabaseCatalogRepository.forTest(
        source: FakeSource(fixture()).call,
      );
      await repo.refresh();

      expect(repo.restaurants.map((r) => r.id), ['br-1']);
      expect(repo.dishes.map((d) => d.id), ['d-1']);
      expect(repo.dishById('d-1')!.sizes.map((o) => o.id), ['o-1']);
      expect(repo.dishById('d-2'), isNull);
      expect(repo.dishById('d-3'), isNull);
    });

    test('la fila completa del dueño pisa a la pública', () async {
      final repo = SupabaseCatalogRepository.forTest(
        source: FakeSource(fixture(withOwner: true)).call,
      );
      await repo.refresh();

      final b = repo.businessById('biz-1')!;
      expect(b.brand, 'Marca completa');
      expect(b.legalName, 'Marca SAS');
      expect(b.bankName, 'Banco Secreto');
      expect(repo.businesses, hasLength(1));
    });

    test('un comprador solo recibe los datos públicos', () async {
      final repo = SupabaseCatalogRepository.forTest(
        source: FakeSource(fixture()).call,
      );
      await repo.refresh();

      final b = repo.businessById('biz-1')!;
      expect(b.brand, 'Marca pública');
      expect(b.legalName, isEmpty);
      expect(b.nit, isEmpty);
    });

    test('si falla la red conserva lo último y se recupera', () async {
      final source = FakeSource(fixture());
      final repo = SupabaseCatalogRepository.forTest(source: source.call);
      await repo.refresh();
      expect(repo.offline, isFalse);
      expect(repo.lastSync, isNotNull);

      source.fail = true;
      await repo.refresh();
      expect(repo.offline, isTrue);
      expect(repo.restaurants.map((r) => r.id), ['br-1']);

      source.fail = false;
      await repo.refresh();
      expect(repo.offline, isFalse);
    });

    test('arranque sin red recupera la copia (una sola vez)', () async {
      final cache = CountingCache(encodeCatalogRows(fixture()));
      final repo = SupabaseCatalogRepository.forTest(
        source: (FakeSource(fixture())..fail = true).call,
        cache: cache,
      );
      await repo.refresh();
      expect(repo.offline, isTrue);
      expect(repo.lastSync, isNull);
      expect(repo.dishes.map((d) => d.id), ['d-1']);

      await repo.refresh();
      expect(cache.reads, 1);
    });

    test('sin red y sin copia queda vacío sin lanzar', () async {
      final repo = SupabaseCatalogRepository.forTest(
        source: (FakeSource(fixture())..fail = true).call,
      );
      await expectLater(repo.refresh(), completes);
      expect(repo.offline, isTrue);
      expect(repo.restaurants, isEmpty);
      expect(repo.dishes, isEmpty);
    });

    test('una copia dañada se ignora', () async {
      for (final bad in ['{no es json', '[]', '{"v":2,"branches":[]}']) {
        final repo = SupabaseCatalogRepository.forTest(
          source: (FakeSource(fixture())..fail = true).call,
          cache: MemoryCatalogCache(bad),
        );
        await repo.refresh();
        expect(repo.restaurants, isEmpty, reason: bad);
      }
      expect(decodeCatalogRows(null), isNull);
      expect(decodeCatalogRows(''), isNull);
    });

    test('si la caché falla al escribir la app sigue', () async {
      final repo = SupabaseCatalogRepository.forTest(
        source: FakeSource(fixture()).call,
        cache: ThrowingCache(),
      );
      await expectLater(repo.refresh(), completes);
      expect(repo.offline, isFalse);
      expect(repo.restaurants, hasLength(1));
    });

    test('CatalogRows va y vuelve por JSON sin las filas del dueño', () {
      final rows = fixture(withOwner: true);
      final back = decodeCatalogRows(encodeCatalogRows(rows))!;
      expect(back.publicBusinesses, rows.publicBusinesses);
      expect(back.ownBusinesses, isEmpty);
      expect(back.branches, rows.branches);
      expect(back.dishes, rows.dishes);
      expect(back.options, rows.options);
      expect(back.isEmpty, isFalse);
      expect(const CatalogRows().isEmpty, isTrue);
      expect(
        () => CatalogRows.fromJson({'v': 2}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
