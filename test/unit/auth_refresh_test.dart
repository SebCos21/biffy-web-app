import 'dart:async';

import 'package:biffy/app/auth_refresh.dart';
import 'package:biffy/app/di/injection.dart';
import 'package:biffy/core/constants/catalog_constants.dart';
import 'package:biffy/data/mock/seed_users.dart';
import 'package:biffy/features/auth/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Pruebas del aviso al router: se notifica en cada evento del stream y se
/// suelta la suscripción al cerrarse.
void main() {
  test('avisa a cada oyente cuando el stream emite', () async {
    final ctrl = StreamController<int>.broadcast();
    addTearDown(ctrl.close);
    final r = StreamRefreshListenable(ctrl.stream);
    addTearDown(r.dispose);
    var a = 0, b = 0;
    void la() => a++;
    r.addListener(la);
    r.addListener(() => b++);
    expect(r.listenerCount, 2);

    ctrl.add(1);
    await Future<void>.delayed(Duration.zero);
    expect((a, b), (1, 1));

    r.removeListener(la);
    ctrl.add(2);
    await Future<void>.delayed(Duration.zero);
    expect((a, b), (1, 2));
  });

  test('dispose cancela la suscripción y deja de avisar', () async {
    final ctrl = StreamController<int>.broadcast();
    addTearDown(ctrl.close);
    final r = StreamRefreshListenable(ctrl.stream);
    var calls = 0;
    r.addListener(() => calls++);
    expect(ctrl.hasListener, isTrue);

    await r.dispose();

    expect(r.isDisposed, isTrue);
    expect(r.listenerCount, 0);
    expect(ctrl.hasListener, isFalse);
    ctrl.add(1);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 0);
    // Cerrar dos veces no falla.
    await r.dispose();
  });

  test('con el AuthBloc avisa al iniciar y cerrar sesión', () async {
    await makeServices();
    final bloc = getIt<AuthBloc>();
    final r = StreamRefreshListenable(bloc.stream);
    addTearDown(r.dispose);
    var calls = 0;
    r.addListener(() => calls++);

    await bloc.request(LoginRequested(kDemoBuyerEmail, kDemoPassword));
    await Future<void>.delayed(Duration.zero);
    final afterLogin = calls;
    expect(afterLogin, greaterThan(0));

    await bloc.request(LogoutRequested());
    await Future<void>.delayed(Duration.zero);
    expect(calls, greaterThan(afterLogin));
  });
}
