import 'dart:io';

import 'package:biffy/app/di/injection.dart';
import 'package:biffy/core/constants/catalog_constants.dart';
import 'package:biffy/data/mock/seed_users.dart';
import 'package:biffy/domain/entities/user.dart';
import 'package:biffy/domain/repositories/auth_repository.dart';
import 'package:biffy/domain/usecases/auth/auth_usecases.dart';
import 'package:biffy/features/addresses/bloc/addresses_cubit.dart';
import 'package:biffy/features/auth/bloc/auth_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Coincide con un estado cuyo último resultado terminó con [code].
TypeMatcher<AuthState> _outcome(String code) =>
    isA<AuthState>().having((s) => s.outcome?.result.code, 'code', code);

/// Autenticación "remota" sin red: toda llamada al servidor falla.
class _OfflineAuth extends Fake implements AuthRepository {
  @override
  bool get isRemote => true;

  @override
  Future<AppUser?> restoreSession() async =>
      throw const SocketException('sin red');

  @override
  Future<AppUser> signIn(String email, String password) async =>
      throw const SocketException('sin red');

  @override
  Future<void> signOut() async => throw const SocketException('sin red');
}

/// Pruebas con bloc_test del AuthBloc: login, registro con rol, restaurar,
/// cerrar sesión, rol activo, punto de entrega y ajustes.
void main() {
  setUp(() async => makeServices());

  AuthBloc build() => AuthBloc(getIt<AuthUseCases>());

  /// AuthBloc con la autenticación sin red.
  AuthBloc offline() {
    getIt.registerLazySingleton<AuthRepository>(_OfflineAuth.new);
    return AuthBloc(getIt<AuthUseCases>());
  }

  group('Iniciar sesión', () {
    blocTest<AuthBloc, AuthState>(
      'con credenciales demo entra con el rol de la cuenta',
      build: build,
      act: (b) => b.add(LoginRequested(kDemoCourierEmail, kDemoPassword)),
      expect: () => contains(
        _outcome('ok')
            .having((s) => s.session.user?.email, 'correo', kDemoCourierEmail)
            .having((s) => s.session.activeRole, 'rol', UserRole.courier),
      ),
    );

    blocTest<AuthBloc, AuthState>(
      'con contraseña incorrecta emite auth_error en español y no entra',
      build: build,
      act: (b) => b.add(LoginRequested(kDemoBuyerEmail, 'mal')),
      expect: () => contains(
        _outcome(
          'auth_error',
        ).having((s) => s.outcome?.result.message, 'mensaje', isNotEmpty),
      ),
      verify: (b) => expect(b.isLoggedIn, isFalse),
    );

    blocTest<AuthBloc, AuthState>(
      'sin red emite network con mensaje y no entra',
      build: offline,
      act: (b) => b.add(LoginRequested(kDemoBuyerEmail, kDemoPassword)),
      expect: () => contains(
        _outcome('network').having(
          (s) => s.outcome?.result.message,
          'mensaje',
          'No pudimos iniciar sesión. Revisa tu conexión.',
        ),
      ),
      verify: (b) => expect(b.isLoggedIn, isFalse),
    );
  });

  group('Registro con rol', () {
    blocTest<AuthBloc, AuthState>(
      'un comprador nuevo entra y recibe su dirección inicial',
      build: build,
      act: (b) => b.add(
        RegisterRequested(
          name: 'Nueva',
          email: 'nueva@icesi.edu.co',
          password: '123456',
          role: UserRole.buyer,
        ),
      ),
      expect: () => contains(
        _outcome(
          'ok',
        ).having((s) => s.session.user?.role, 'rol', UserRole.buyer),
      ),
      verify: (b) => expect(
        getIt<AddressesCubit>().defaultOf(b.user?.id)?.pointId,
        b.pointId,
      ),
    );

    blocTest<AuthBloc, AuthState>(
      'un correo ya registrado emite auth_error',
      build: build,
      act: (b) => b.add(
        RegisterRequested(
          name: 'X',
          email: kDemoBuyerEmail,
          password: '123456',
          role: UserRole.buyer,
        ),
      ),
      expect: () => contains(_outcome('auth_error')),
      verify: (b) => expect(b.isLoggedIn, isFalse),
    );
  });

  group('Restaurar y cerrar sesión', () {
    blocTest<AuthBloc, AuthState>(
      'en demo no hay sesión guardada: ok sin cuenta',
      build: build,
      act: (b) => b.add(SessionRestoreRequested()),
      expect: () => [_outcome('ok')],
      verify: (b) => expect(b.user, isNull),
    );

    blocTest<AuthBloc, AuthState>(
      'sin red restaurar emite network sin romper la app',
      build: offline,
      act: (b) => b.add(SessionRestoreRequested()),
      expect: () => [_outcome('network')],
      verify: (b) => expect(b.isLoggedIn, isFalse),
    );

    blocTest<AuthBloc, AuthState>(
      'cerrar sesión vuelve a invitado y al rol comprador',
      build: build,
      setUp: () => getIt<AuthBloc>().login(kDemoCourierEmail, kDemoPassword),
      act: (b) => b.add(LogoutRequested()),
      expect: () => contains(
        _outcome('ok')
            .having((s) => s.session.user, 'cuenta', isNull)
            .having((s) => s.session.activeRole, 'rol', UserRole.buyer),
      ),
    );

    blocTest<AuthBloc, AuthState>(
      'sin red cierra igual en el equipo y emite network con aviso',
      build: () {
        // Entra con la demo antes de quedarse sin red.
        getIt<AuthBloc>().login(kDemoBuyerEmail, kDemoPassword);
        return offline();
      },
      act: (b) => b.add(LogoutRequested()),
      expect: () => contains(
        _outcome('network')
            .having((s) => s.session.user, 'cuenta', isNull)
            .having(
              (s) => s.outcome?.result.message,
              'mensaje',
              contains('no pudimos avisar al servidor'),
            ),
      ),
      verify: (b) => expect(b.isLoggedIn, isFalse),
    );
  });

  group('Rol, perfil, punto y ajustes', () {
    blocTest<AuthBloc, AuthState>(
      'cambiar el rol activo lo publica en el estado',
      build: build,
      act: (b) => b.add(ActiveRoleChanged(UserRole.restaurant)),
      expect: () => contains(
        _outcome(
          'ok',
        ).having((s) => s.session.activeRole, 'rol', UserRole.restaurant),
      ),
    );

    blocTest<AuthBloc, AuthState>(
      'actualizar el perfil sin sesión emite not_logged_in',
      build: build,
      act: (b) => b.add(ProfileUpdateRequested(name: 'X')),
      expect: () => contains(_outcome('not_logged_in')),
    );

    blocTest<AuthBloc, AuthState>(
      'cambiar el punto de entrega y los ajustes',
      build: build,
      act: (b) {
        b.add(DeliveryPointChanged('icesi-plazoleta'));
        b.add(SettingsChanged(b.settings.copyWith(darkMode: true)));
      },
      verify: (b) {
        expect(b.state.session.pointId, 'icesi-plazoleta');
        expect(b.state.session.settings.darkMode, isTrue);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'un cambio de sesión hecho por fuera (casos de uso) llega al Bloc',
      build: build,
      act: (b) =>
          getIt<AuthUseCases>().signIn.demo(kDemoBuyerEmail, kDemoPassword),
      expect: () => contains(
        isA<AuthState>()
            .having((s) => s.outcome, 'sin resultado', isNull)
            .having((s) => s.session.user?.email, 'correo', kDemoBuyerEmail),
      ),
    );
  });

  test('request espera el resultado del evento', () async {
    final b = build();
    addTearDown(b.close);
    final r = await b.request(LoginRequested(kDemoBuyerEmail, kDemoPassword));
    expect(r.ok, isTrue);
    expect(r.user?.email, kDemoBuyerEmail);
    expect(b.isLoggedIn, isTrue);
  });
}
