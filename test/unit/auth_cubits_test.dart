import 'package:biffy/app/di/injection.dart';
import 'package:biffy/core/constants/catalog_constants.dart';
import 'package:biffy/data/mock/seed_users.dart';
import 'package:biffy/domain/entities/user.dart';
import 'package:biffy/features/auth/bloc/login_cubit.dart';
import 'package:biffy/features/auth/bloc/register_cubit.dart';
import 'package:biffy/features/auth/bloc/university_verification_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Pruebas de los cubits de autenticación: login, registro y Campus.
void main() {
  late TestServices services;

  setUp(() async {
    services = await makeServices();
  });

  group('LoginCubit', () {
    test('login correcto publica el usuario', () async {
      final cubit = LoginCubit(services.session);

      final user = await cubit.submit(kDemoBuyerEmail, kDemoPassword);

      expect(user?.role, UserRole.buyer);
      expect(cubit.state.status, LoginStatus.success);
      expect(cubit.state.error, isNull);
    });

    test('contraseña incorrecta publica el error', () async {
      final cubit = LoginCubit(services.session);

      final user = await cubit.submit(kDemoBuyerEmail, 'incorrecta');

      expect(user, isNull);
      expect(cubit.state.status, LoginStatus.error);
      expect(cubit.state.error, isNotEmpty);
    });

    test('alterna la visibilidad de la contraseña', () {
      final cubit = LoginCubit(services.session);
      expect(cubit.state.obscure, isTrue);
      cubit.toggleObscure();
      expect(cubit.state.obscure, isFalse);
    });
  });

  group('RegisterCubit', () {
    test('comprador nuevo queda listo para volver al login', () async {
      final cubit = RegisterCubit(services.session);

      final result = await cubit.submit(
        name: 'Nuevo Comprador',
        email: 'nuevo.comprador@test.co',
        password: '123456',
        phone: '300 000 0000',
      );

      expect(result.user?.role, UserRole.buyer);
      expect(result.nextLocation, isNull);
      expect(result.status, RegisterStatus.success);
    });

    test('repartidor nuevo continúa al registro de vehículo', () async {
      final cubit = RegisterCubit(services.session)
        ..roleChanged(UserRole.courier);

      final result = await cubit.submit(
        name: 'Nuevo Repartidor',
        email: 'nuevo.repartidor@test.co',
        password: '123456',
        phone: '',
      );

      expect(result.user?.role, UserRole.courier);
      expect(result.nextLocation, '/repartidor/registro');
    });

    test('restaurante pasa al formulario ampliado sin crear cuenta', () async {
      final cubit = RegisterCubit(services.session)
        ..roleChanged(UserRole.restaurant);

      final result = await cubit.submit(
        name: '',
        email: '',
        password: '',
        phone: '',
      );

      expect(result.user, isNull);
      expect(result.nextLocation, '/negocio/registro');
    });

    test('correo duplicado publica el error', () async {
      final cubit = RegisterCubit(services.session);

      final result = await cubit.submit(
        name: 'Diego',
        email: kDemoBuyerEmail,
        password: '123456',
        phone: '',
      );

      expect(result.user, isNull);
      expect(result.error, isNotEmpty);
      expect(result.status, RegisterStatus.error);
    });
  });

  group('UniversityVerificationCubit', () {
    test('envía el código demo y lo deja visible', () async {
      services.session.login(kDemoNewBuyerEmail, kDemoPassword);
      // Adaptado: el cubit ahora recibe los casos de uso y la cuenta activa;
      // se crea desde GetIt como en la app.
      final cubit = getIt<UniversityVerificationCubit>();

      await cubit.sendCode(
        universityId: 'icesi',
        email: 'camila@icesi.edu.co',
        renewal: false,
      );

      expect(cubit.state.codeSent, isTrue);
      expect(cubit.state.demoCode, '123456');
      expect(cubit.state.error, isNull);
    });

    test('un código incorrecto no activa Campus', () async {
      services.session.login(kDemoNewBuyerEmail, kDemoPassword);
      // Adaptado: el cubit ahora recibe los casos de uso y la cuenta activa;
      // se crea desde GetIt como en la app.
      final cubit = getIt<UniversityVerificationCubit>();
      await cubit.sendCode(
        universityId: 'icesi',
        email: 'camila@icesi.edu.co',
        renewal: false,
      );

      await cubit.confirmCode(
        universityId: 'icesi',
        email: 'camila@icesi.edu.co',
        code: '000000',
      );

      expect(cubit.state.isVerified, isFalse);
      expect(cubit.state.error, isNotEmpty);
    });

    test('el código correcto activa Campus y fija vencimiento', () async {
      services.session.login(kDemoNewBuyerEmail, kDemoPassword);
      // Adaptado: el cubit ahora recibe los casos de uso y la cuenta activa;
      // se crea desde GetIt como en la app.
      final cubit = getIt<UniversityVerificationCubit>();
      await cubit.sendCode(
        universityId: 'icesi',
        email: 'camila@icesi.edu.co',
        renewal: false,
      );

      await cubit.confirmCode(
        universityId: 'icesi',
        email: 'camila@icesi.edu.co',
        code: '123456',
      );

      expect(cubit.state.isVerified, isTrue);
      expect(cubit.state.expiresAt, isNotNull);
      expect(cubit.state.codeSent, isFalse);
    });
  });

  group('LoginCubit y RegisterCubit (bloc_test)', () {
    blocTest<LoginCubit, LoginState>(
      'login correcto emite enviando y luego éxito con el usuario',
      build: () => LoginCubit(services.session),
      act: (c) => c.submit(kDemoBuyerEmail, kDemoPassword),
      expect: () => [
        isA<LoginState>().having((s) => s.isSubmitting, 'enviando', isTrue),
        isA<LoginState>()
            .having((s) => s.status, 'estado', LoginStatus.success)
            .having((s) => s.user?.email, 'correo', kDemoBuyerEmail),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      'contraseña incorrecta emite enviando y luego el error en español',
      build: () => LoginCubit(services.session),
      act: (c) => c.submit(kDemoBuyerEmail, 'incorrecta'),
      expect: () => [
        isA<LoginState>().having((s) => s.isSubmitting, 'enviando', isTrue),
        isA<LoginState>()
            .having((s) => s.status, 'estado', LoginStatus.error)
            .having((s) => s.error, 'error', isNotEmpty),
      ],
      verify: (_) => expect(services.session.isLoggedIn, isFalse),
    );

    blocTest<RegisterCubit, RegisterState>(
      'registrar un comprador nuevo emite enviando y luego éxito',
      build: () => RegisterCubit(services.session),
      act: (c) => c.submit(
        name: 'Nueva Compradora',
        email: 'nueva.compradora@test.co',
        password: '123456',
        phone: '',
      ),
      expect: () => [
        isA<RegisterState>().having((s) => s.isSubmitting, 'enviando', isTrue),
        isA<RegisterState>()
            .having((s) => s.status, 'estado', RegisterStatus.success)
            .having((s) => s.user?.role, 'rol', UserRole.buyer),
      ],
    );

    blocTest<RegisterCubit, RegisterState>(
      'un correo ya registrado emite el error en español',
      build: () => RegisterCubit(services.session),
      act: (c) => c.submit(
        name: 'Diego',
        email: kDemoBuyerEmail,
        password: '123456',
        phone: '',
      ),
      expect: () => [
        isA<RegisterState>().having((s) => s.isSubmitting, 'enviando', isTrue),
        isA<RegisterState>()
            .having((s) => s.status, 'estado', RegisterStatus.error)
            .having((s) => s.error, 'error', isNotEmpty),
      ],
    );
  });
}
