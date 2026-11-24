import 'package:biffy/data/models/user.dart';
import 'package:biffy/data/repositories/in_memory_courier_repository.dart';
import 'package:biffy/domain/ports/courier_ports.dart';
import 'package:biffy/domain/repositories/courier_repository.dart';
import 'package:biffy/domain/usecases/courier/courier_usecases.dart';
import 'package:biffy/features/courier/bloc/courier_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sesión falsa: cuenta, verificación y si se activó el rol repartidor.
class _FakeSession implements CourierSessionPort {
  @override
  String? currentUserId = 'u1';

  @override
  bool isVerifiedStudent = false;

  /// Teléfono recibido al activar el rol (null si no se activó).
  String? activatedWithPhone;

  @override
  void activateCourierRole({required String phone}) =>
      activatedWithPhone = phone;
}

/// Repositorio cuyo guardado remoto falla (conserva el perfil local).
class _FailingSaveRepo extends InMemoryCourierRepository {
  @override
  Future<CourierResult> saveProfile(String userId, CourierProfile p) async {
    final local = await super.saveProfile(userId, p);
    return CourierResult('save_failed', status: local.status);
  }
}

const _profile = CourierProfile(
  fullName: 'Ana Repartidora',
  docType: 'CC',
  docNumber: '1000000009',
  phone: '300 111 2233',
  vehicle: Vehicle.bicycle,
  contactEmail: 'ana@icesi.edu.co',
);

/// Cubit sobre el repositorio y la sesión indicados.
CourierCubit _cubit(CourierRepository repo, CourierSessionPort session) =>
    CourierCubit(CourierUseCases(repo: repo, session: session));

/// Coincide con un estado cuyo último resultado es [action] con [code].
TypeMatcher<CourierState> _outcome(CourierAction action, String code) =>
    isA<CourierState>()
        .having((s) => s.outcome?.action, 'action', action)
        .having((s) => s.outcome?.result.code, 'code', code);

/// Pruebas con bloc_test del repartidor: registro, disponibilidad y zona.
void main() {
  late InMemoryCourierRepository repo;
  late _FakeSession session;

  setUp(() {
    repo = InMemoryCourierRepository();
    session = _FakeSession();
  });

  group('CourierCubit', () {
    blocTest<CourierCubit, CourierState>(
      'registrarse guarda el perfil, activa el rol y emite ok',
      build: () => _cubit(repo, session),
      act: (c) => c.register(_profile),
      expect: () => contains(_outcome(CourierAction.register, 'ok')),
      verify: (c) {
        expect(c.statusOf('u1').profile?.fullName, 'Ana Repartidora');
        expect(session.activatedWithPhone, '300 111 2233');
      },
    );

    blocTest<CourierCubit, CourierState>(
      'si el servidor falla emite save_failed y el perfil local se conserva',
      build: () => _cubit(_FailingSaveRepo(), session),
      act: (c) => c.register(_profile),
      expect: () => contains(_outcome(CourierAction.register, 'save_failed')),
      verify: (c) {
        expect(c.state.outcome?.result.message, contains('No pudimos guardar'));
        expect(c.statusOf('u1').hasProfile, isTrue);
      },
    );

    blocTest<CourierCubit, CourierState>(
      'conectarse con perfil emite ok y queda en línea',
      setUp: () => repo.insertSeed('u1', _profile),
      build: () => _cubit(repo, session),
      act: (c) => c.setOnline(true),
      // El resultado y, luego, el refresco que llega por `changes`.
      expect: () => [
        _outcome(CourierAction.availability, 'ok'),
        _outcome(
          CourierAction.availability,
          'ok',
        ).having((s) => s.revision, 'revision', 2),
      ],
      verify: (c) => expect(c.statusOf('u1').online, isTrue),
    );

    blocTest<CourierCubit, CourierState>(
      'conectarse sin perfil emite no_profile',
      build: () => _cubit(repo, session),
      act: (c) => c.setOnline(true),
      expect: () => [_outcome(CourierAction.availability, 'no_profile')],
      verify: (c) => expect(c.statusOf('u1').online, isFalse),
    );

    blocTest<CourierCubit, CourierState>(
      'el modo Campus sin verificación emite el motivo en español',
      build: () => _cubit(repo, session),
      act: (c) => c.setZone(CourierZone.campus),
      expect: () => [
        _outcome(CourierAction.zone, 'campus_requires_verification').having(
          (s) => s.outcome?.result.message,
          'mensaje',
          'El modo Campus requiere universidad verificada.',
        ),
      ],
      verify: (c) => expect(c.statusOf('u1').zone, CourierZone.general),
    );

    blocTest<CourierCubit, CourierState>(
      'el modo Campus con verificación cambia la zona',
      setUp: () => session.isVerifiedStudent = true,
      build: () => _cubit(repo, session),
      act: (c) => c.setZone(CourierZone.campus),
      expect: () => [
        _outcome(CourierAction.zone, 'ok'),
        _outcome(
          CourierAction.zone,
          'ok',
        ).having((s) => s.revision, 'revision', 2),
      ],
      verify: (c) => expect(c.statusOf('u1').zone, CourierZone.campus),
    );

    blocTest<CourierCubit, CourierState>(
      'sin sesión no se puede registrar',
      setUp: () => session.currentUserId = null,
      build: () => _cubit(repo, session),
      act: (c) => c.register(_profile),
      expect: () => [_outcome(CourierAction.register, 'not_logged_in')],
      verify: (_) => expect(session.activatedWithPhone, isNull),
    );
  });

  group('Repositorio en memoria', () {
    test('guardar el perfil conserva disponibilidad y zona', () async {
      repo.setOnline('u1', true);
      repo.setZone('u1', CourierZone.campus);
      await repo.saveProfile('u1', _profile);
      final s = repo.statusOf('u1');
      expect(s.online, isTrue);
      expect(s.zone, CourierZone.campus);
      expect(s.hasProfile, isTrue);
    });

    test('una cuenta sin registro no tiene perfil', () {
      expect(CourierQueries(repo).hasProfile('nadie'), isFalse);
      expect(CourierQueries(repo).hasProfile(null), isFalse);
    });
  });
}
