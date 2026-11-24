import 'package:biffy/core/widgets/offline_banner.dart';
import 'package:biffy/data/repositories/catalog_snapshot.dart';
import 'package:biffy/data/repositories/supabase_catalog_repository.dart';
import 'package:biffy/shared/state/catalog_controller.dart';
import 'package:biffy/shared/state/controller_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Fuente de filas que puede simular la falta de red.
class SwitchableSource {
  /// Si es `true`, la lectura falla como sin red.
  bool fail = false;

  /// Devuelve una sede con un plato o lanza si [fail].
  Future<CatalogRows> call() async {
    if (fail) throw Exception('Sin red');
    return const CatalogRows(
      branches: [
        {'id': 'br-1', 'business_id': 'biz-1', 'name': 'Sede'},
      ],
      dishes: [
        {'id': 'd-1', 'branch_id': 'br-1', 'name': 'Plato'},
      ],
    );
  }
}

/// Monta el aviso con un catálogo que lee de [repo].
Future<void> pumpBanner(
  WidgetTester tester,
  SupabaseCatalogRepository repo,
) async {
  // Adaptado: antes AppServices + Provider; ahora GetIt (makeServices) y
  // ControllerScope, igual que el resto de la app.
  final services = await makeServices();
  final catalog = CatalogController(repo, services.session, services.clock);
  await tester.pumpWidget(
    ControllerScope(
      controllers: {CatalogController: catalog},
      child: MaterialApp(
        home: Scaffold(body: ListView(children: const [OfflineBanner()])),
      ),
    ),
  );
}

/// Pruebas del aviso de catálogo sin conexión en sus tres estados.
void main() {
  testWidgets('con red no muestra nada', (tester) async {
    final repo = SupabaseCatalogRepository.forTest(
      source: SwitchableSource().call,
    );
    await repo.refresh();
    await pumpBanner(tester, repo);

    expect(find.byKey(const Key('offline-banner')), findsNothing);
    expect(find.byKey(const Key('offline-empty')), findsNothing);
  });

  testWidgets('sin red con copia muestra la franja y Reintentar la quita', (
    tester,
  ) async {
    final source = SwitchableSource()..fail = true;
    final saved = await SwitchableSource().call();
    final repo = SupabaseCatalogRepository.forTest(
      source: source.call,
      cache: MemoryCatalogCache(encodeCatalogRows(saved)),
    );
    await repo.refresh();
    await pumpBanner(tester, repo);

    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(find.textContaining('mostrando el menú guardado'), findsOneWidget);

    source.fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('offline-banner')), findsNothing);
  });

  testWidgets('sin red y sin copia muestra el error con reintento', (
    tester,
  ) async {
    final repo = SupabaseCatalogRepository.forTest(
      source: (SwitchableSource()..fail = true).call,
    );
    await repo.refresh();
    await pumpBanner(tester, repo);

    expect(find.byKey(const Key('offline-empty')), findsOneWidget);
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
