import 'dart:io';

import 'package:biffy/app/di/injection.dart';
import 'package:biffy/data/mock/seed_users.dart';
import 'package:biffy/data/repositories/auth_repository.dart';
import 'package:biffy/core/constants/catalog_constants.dart';
import 'package:biffy/domain/repositories/catalog_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Autenticación demo cuyo cierre en el servidor falla por red.
class _OfflineSignOutAuth extends InMemoryAuthRepository {
  /// Usa las mismas cuentas semilla de la demo.
  _OfflineSignOutAuth()
    : super(seedUsers(getIt<CatalogRepository>().businesses));

  @override
  Future<void> signOut() async => throw const SocketException('sin red');
}

/// Abre el perfil con Diego, cierra sesión y confirma.
Future<void> _logoutFromProfile(WidgetTester tester, TestServices s) async {
  s.session.login(kDemoBuyerEmail, kDemoPassword);
  await pumpBiffy(tester, services: s, initialLocation: '/perfil');
  await tapVisible(tester, find.byKey(const Key('logout')));
  await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
  await tester.pumpAndSettle();
}

/// Cerrar sesión desde el perfil siempre sale al login, con o sin red.
void main() {
  testWidgets('cerrar sesión sale al login', (tester) async {
    final s = await makeServices();
    await _logoutFromProfile(tester, s);

    expect(s.session.isLoggedIn, isFalse);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.text('Sesión cerrada'), findsOneWidget);
  });

  testWidgets('sin red cierra igual en el equipo, avisa y sale al login', (
    tester,
  ) async {
    final s = await makeServices(auth: _OfflineSignOutAuth.new);
    await _logoutFromProfile(tester, s);

    expect(s.session.isLoggedIn, isFalse);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(
      find.textContaining('no pudimos avisar al servidor'),
      findsOneWidget,
    );
  });
}
