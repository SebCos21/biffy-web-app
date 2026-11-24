import 'package:biffy/core/utils/clock.dart';
import 'package:biffy/data/repositories/in_memory_notification_repository.dart';
import 'package:biffy/data/repositories/in_memory_preferences_repository.dart';
import 'package:biffy/data/repositories/in_memory_university_repository.dart';
import 'package:biffy/data/repositories/in_memory_wallet_repository.dart';
import 'package:biffy/domain/entities/university_status.dart';
import 'package:biffy/domain/repositories/university_repository.dart';
import 'package:biffy/domain/usecases/notifications/notification_usecases.dart';
import 'package:biffy/domain/usecases/preferences/preferences_usecases.dart';
import 'package:biffy/domain/usecases/university/university_usecases.dart';
import 'package:biffy/domain/usecases/wallet/wallet_usecases.dart';
import 'package:biffy/features/auth/bloc/university_verification_cubit.dart';
import 'package:biffy/features/university/bloc/university_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 10, 12);

/// Repositorio "remoto" que devuelve un registro de verificación fijo.
class _RemoteRecord extends InMemoryUniversityRepository {
  _RemoteRecord(this.record, {this.code = 'ok'});
  final UniversityRecord record;
  final String code;

  @override
  bool get isRemote => true;

  @override
  Future<UniversityResult> load(String userId) async =>
      UniversityResult(code, record: code == 'ok' ? record : null);
}

/// Pruebas con bloc_test de la verificación universitaria.
void main() {
  late InMemoryUniversityRepository repo;
  late PreferencesUseCases prefs;
  late NotificationUseCases notifications;

  /// Casos de uso sobre [r] con preferencias y avisos en memoria.
  UniversityUseCases useCases([UniversityRepository? r]) => UniversityUseCases(
    repo: r ?? repo,
    preferences: prefs,
    push: notifications.push,
    clock: Clock.fixed(_now),
  );

  setUp(() {
    repo = InMemoryUniversityRepository();
    final clock = Clock.fixed(_now);
    notifications = NotificationUseCases(
      repo: InMemoryNotificationRepository(),
      clock: clock,
    );
    prefs = PreferencesUseCases(
      repo: InMemoryPreferencesRepository(),
      credit: WalletUseCases(
        repo: InMemoryWalletRepository(),
        clock: clock,
      ).credit,
      push: notifications.push,
    );
  });

  group('UniversityVerificationCubit', () {
    blocTest<UniversityVerificationCubit, UniversityVerificationState>(
      'enviar el código emite «enviando» y luego el código demo',
      build: () => UniversityVerificationCubit(useCases(), () => 'u1'),
      act: (c) => c.sendCode(
        universityId: 'icesi',
        email: 'ana@icesi.edu.co',
        renewal: false,
      ),
      expect: () => [
        isA<UniversityVerificationState>().having(
          (s) => s.sending,
          'sending',
          isTrue,
        ),
        isA<UniversityVerificationState>()
            .having((s) => s.codeSent, 'codeSent', isTrue)
            .having((s) => s.demoCode, 'demoCode', '123456')
            .having((s) => s.error, 'error', isNull),
      ],
    );

    blocTest<UniversityVerificationCubit, UniversityVerificationState>(
      'un correo de otro dominio emite el error en español',
      build: () => UniversityVerificationCubit(useCases(), () => 'u1'),
      act: (c) => c.sendCode(
        universityId: 'icesi',
        email: 'ana@gmail.com',
        renewal: false,
      ),
      expect: () => [
        isA<UniversityVerificationState>(),
        isA<UniversityVerificationState>()
            .having((s) => s.codeSent, 'codeSent', isFalse)
            .having(
              (s) => s.error,
              'error',
              'El correo no pertenece a la universidad',
            ),
      ],
    );

    blocTest<UniversityVerificationCubit, UniversityVerificationState>(
      'el código correcto activa Campus por 30 días y avisa al usuario',
      build: () => UniversityVerificationCubit(useCases(), () => 'u1'),
      act: (c) async {
        await c.sendCode(
          universityId: 'icesi',
          email: 'ana@icesi.edu.co',
          renewal: false,
        );
        await c.confirmCode(
          universityId: 'icesi',
          email: 'ana@icesi.edu.co',
          code: '123456',
        );
      },
      skip: 2,
      expect: () => [
        isA<UniversityVerificationState>(),
        isA<UniversityVerificationState>()
            .having((s) => s.isVerified, 'isVerified', isTrue)
            .having(
              (s) => s.expiresAt,
              'expiresAt',
              _now.add(const Duration(days: 30)),
            ),
      ],
      verify: (_) {
        expect(prefs.queries.prefsOf('u1').universityId, 'icesi');
        expect(
          notifications.queries.all.first.title,
          'Universidad verificada (simulación) 🎓',
        );
      },
    );

    blocTest<UniversityVerificationCubit, UniversityVerificationState>(
      'un código incorrecto no activa Campus',
      build: () => UniversityVerificationCubit(useCases(), () => 'u1'),
      act: (c) async {
        await c.sendCode(
          universityId: 'icesi',
          email: 'ana@icesi.edu.co',
          renewal: false,
        );
        await c.confirmCode(
          universityId: 'icesi',
          email: 'ana@icesi.edu.co',
          code: '000000',
        );
      },
      skip: 2,
      expect: () => [
        isA<UniversityVerificationState>(),
        isA<UniversityVerificationState>()
            .having((s) => s.isVerified, 'isVerified', isFalse)
            .having((s) => s.error, 'error', 'El código no es correcto'),
      ],
    );

    blocTest<UniversityVerificationCubit, UniversityVerificationState>(
      'sin sesión pide iniciar sesión',
      build: () => UniversityVerificationCubit(useCases(), () => null),
      act: (c) => c.sendCode(
        universityId: 'icesi',
        email: 'ana@icesi.edu.co',
        renewal: false,
      ),
      expect: () => [
        isA<UniversityVerificationState>(),
        isA<UniversityVerificationState>().having(
          (s) => s.error,
          'error',
          'Inicia sesión primero',
        ),
      ],
    );
  });

  group('UniversityCubit', () {
    blocTest<UniversityCubit, UniversityState>(
      'en demo, elegir otra universidad descarta la verificación anterior',
      setUp: () => repo.setStatus(
        'u1',
        const UniversityStatus(verifiedUniversityId: 'icesi'),
      ),
      build: () => UniversityCubit(useCases()),
      act: (c) => c.choose('u1', 'unal'),
      verify: (c) {
        expect(c.isVerifiedStudent('u1'), isFalse);
        expect(c.universityIdOf('u1'), 'unal');
      },
    );

    blocTest<UniversityCubit, UniversityState>(
      'una verificación vencida deja de contar',
      setUp: () => repo.setStatus(
        'u1',
        UniversityStatus(
          verifiedUniversityId: 'icesi',
          expiresAt: DateTime(2025),
        ),
      ),
      build: () => UniversityCubit(useCases()),
      verify: (c) {
        expect(c.isVerifiedStudent('u1'), isFalse);
        expect(c.verifiedUniversityId('u1'), isNull);
      },
    );

    blocTest<UniversityCubit, UniversityState>(
      'cargar una verificación vigente repinta y habilita Campus',
      build: () => UniversityCubit(
        useCases(
          _RemoteRecord(
            UniversityRecord(
              verified: true,
              universityId: 'icesi',
              expiresAt: _now.add(const Duration(days: 5)),
            ),
          ),
        ),
      ),
      act: (c) => c.useCases.load('u1'),
      expect: () => isNotEmpty,
      verify: (c) => expect(c.isVerifiedStudent('u1'), isTrue),
    );

    blocTest<UniversityCubit, UniversityState>(
      'sin red cargar no cambia nada ni habilita Campus',
      build: () => UniversityCubit(
        useCases(
          _RemoteRecord(
            const UniversityRecord(verified: true, universityId: 'icesi'),
            code: 'network',
          ),
        ),
      ),
      act: (c) async => expect((await c.useCases.load('u1')).ok, isFalse),
      verify: (c) => expect(c.isVerifiedStudent('u1'), isFalse),
    );
  });

  group('Cargar la verificación al iniciar sesión', () {
    test('vigente: queda verificada y fija la universidad', () async {
      final r = _RemoteRecord(
        UniversityRecord(
          verified: true,
          universityId: 'icesi',
          email: 'ana@icesi.edu.co',
          expiresAt: _now.add(const Duration(days: 5)),
        ),
      );
      final uc = useCases(r);
      await uc.load('u1');
      expect(uc.queries.isVerifiedStudent('u1'), isTrue);
      expect(prefs.queries.prefsOf('u1').universityId, 'icesi');
    });

    test('vencida: conserva el correo pero no habilita Campus', () async {
      final r = _RemoteRecord(
        UniversityRecord(
          verified: true,
          universityId: 'icesi',
          email: 'ana@icesi.edu.co',
          expiresAt: _now.subtract(const Duration(days: 1)),
        ),
      );
      final uc = useCases(r);
      await uc.load('u1');
      expect(uc.queries.isVerifiedStudent('u1'), isFalse);
      expect(uc.queries.emailOf('u1'), 'ana@icesi.edu.co');
    });

    test('sin red no cambia nada', () async {
      final r = _RemoteRecord(
        const UniversityRecord(verified: true, universityId: 'icesi'),
        code: 'network',
      );
      final uc = useCases(r);
      final res = await uc.load('u1');
      expect(res.ok, isFalse);
      expect(uc.queries.isVerifiedStudent('u1'), isFalse);
    });
  });
}
