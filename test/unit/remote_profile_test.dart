import 'package:biffy/core/utils/clock.dart';
import 'package:biffy/data/models/user.dart';
import 'package:biffy/data/repositories/auth_repository.dart';
import 'package:biffy/data/repositories/in_memory_address_repository.dart';
import 'package:biffy/data/repositories/in_memory_courier_repository.dart';
import 'package:biffy/data/repositories/in_memory_notification_repository.dart';
import 'package:biffy/data/repositories/in_memory_preferences_repository.dart';
import 'package:biffy/data/repositories/in_memory_university_repository.dart';
import 'package:biffy/domain/entities/university_status.dart';
import 'package:biffy/domain/repositories/university_repository.dart';
import 'package:biffy/domain/university_errors.dart';
import 'package:biffy/domain/usecases/university/university_usecases.dart';
import 'package:biffy/data/repositories/in_memory_wallet_repository.dart';
import 'package:biffy/domain/repositories/courier_repository.dart';
import 'package:biffy/domain/usecases/addresses/address_usecases.dart';
import 'package:biffy/domain/usecases/courier/courier_usecases.dart';
import 'package:biffy/domain/usecases/notifications/notification_usecases.dart';
import 'package:biffy/domain/usecases/preferences/preferences_usecases.dart';
import 'package:biffy/domain/usecases/wallet/wallet_usecases.dart';
import 'package:biffy/shared/adapters/courier_adapters.dart';
import 'package:biffy/shared/state/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositorio remoto falso que registra las escrituras del perfil.
class _FakeRemoteAuth implements AuthRepository {
  _FakeRemoteAuth() {
    user = AppUser(
      id: 'u-remote',
      name: 'Ana',
      email: 'ana@icesi.edu.co',
      role: UserRole.buyer,
    );
  }

  late AppUser user;

  /// Últimos datos de perfil guardados.
  ({String? name, String? phone})? savedProfile;

  @override
  bool get isRemote => true;

  @override
  List<AppUser> get demoAccounts => const [];

  @override
  AppUser login(String email, String password) => throw UnimplementedError();

  @override
  AppUser register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String phone = '',
  }) => throw UnimplementedError();

  @override
  AppUser? byId(String id) => id == user.id ? user : null;

  @override
  AppUser? byBusiness(String businessId) => null;

  @override
  Future<AppUser> signIn(String email, String password) async => user;

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String phone = '',
  }) async => user;

  @override
  Future<void> signOut() async {}

  @override
  Future<AppUser?> restoreSession() async => user;

  @override
  Future<String?> registerBusiness(Map<String, dynamic> payload) async => null;

  @override
  Future<void> saveProfile(String userId, {String? name, String? phone}) async {
    savedProfile = (name: name, phone: phone);
  }
}

/// Verificación universitaria "remota" falsa con resultados configurables
/// (antes estos dobles vivían en el AuthRepository falso).
class _FakeRemoteUniversity extends InMemoryUniversityRepository {
  /// Código que devolverá el RPC de verificación.
  String verifyCode = 'ok';

  /// Llamadas al RPC de verificación.
  int verifyCalls = 0;

  /// Resultado configurable del envío del código.
  String sendCodeResult = 'ok';

  /// Resultado configurable de la confirmación del código.
  String confirmCodeResult = 'ok';

  @override
  bool get isRemote => true;

  @override
  Future<UniversityResult> verify(String universityId, String email) async {
    verifyCalls++;
    return UniversityResult(verifyCode);
  }

  @override
  Future<UniversityResult> sendCode({
    required String userId,
    required String universityId,
    required String email,
    bool renewal = false,
  }) async => UniversityResult(sendCodeResult);

  @override
  Future<UniversityResult> confirmCode({
    required String userId,
    required String email,
    required String code,
  }) async => UniversityResult(confirmCodeResult);
}

/// Casos de uso de verificación sobre [repo] (preferencias y avisos en
/// memoria).
UniversityUseCases _uni(UniversityRepository repo) {
  final clock = Clock.fixed(DateTime(2026));
  final notifications = NotificationUseCases(
    repo: InMemoryNotificationRepository(),
    clock: clock,
  );
  final wallet = WalletUseCases(repo: InMemoryWalletRepository(), clock: clock);
  return UniversityUseCases(
    repo: repo,
    preferences: PreferencesUseCases(
      repo: InMemoryPreferencesRepository(),
      credit: wallet.credit,
      push: notifications.push,
    ),
    push: notifications.push,
    clock: clock,
  );
}

/// Repositorio de repartidor "remoto" falso que registra el perfil guardado.
class _FakeRemoteCourier extends InMemoryCourierRepository {
  /// Último perfil de repartidor guardado.
  CourierProfile? saved;

  @override
  bool get isRemote => true;

  @override
  Future<CourierResult> saveProfile(String userId, CourierProfile profile) {
    saved = profile;
    return super.saveProfile(userId, profile);
  }
}

/// Crea un controlador de sesión con el repositorio remoto falso.
SessionController _session(
  _FakeRemoteAuth auth, {
  CourierRepository? couriers,
  UniversityRepository? university,
}) {
  final c = couriers ?? InMemoryCourierRepository();
  final clock = Clock.fixed(DateTime(2026));
  final notifications = NotificationUseCases(
    repo: InMemoryNotificationRepository(),
    clock: clock,
  );
  final wallet = WalletUseCases(repo: InMemoryWalletRepository(), clock: clock);
  final preferences = PreferencesUseCases(
    repo: InMemoryPreferencesRepository(),
    credit: wallet.credit,
    push: notifications.push,
  );
  return SessionController(
    auth,
    notifications,
    clock,
    couriers: CourierQueries(c),
    loadCourier: LoadCourier(c),
    wallet: wallet,
    preferences: preferences,
    addresses: AddressUseCases(repo: InMemoryAddressRepository()),
    university: UniversityUseCases(
      repo: university ?? InMemoryUniversityRepository(),
      preferences: preferences,
      push: notifications.push,
      clock: clock,
    ),
  );
}

void main() {
  group('Perfil remoto', () {
    test('guardar nombre y teléfono llama al backend', () async {
      final auth = _FakeRemoteAuth();
      final s = _session(auth)..loginAs(auth.user);

      await s.updateProfile(name: 'Ana María', phone: '300 111 2233');

      expect(auth.savedProfile?.name, 'Ana María');
      expect(auth.savedProfile?.phone, '300 111 2233');
      expect(s.user?.name, 'Ana María');
    });

    test('guardar perfil de repartidor lo persiste y activa el rol', () async {
      final auth = _FakeRemoteAuth();
      final couriers = _FakeRemoteCourier();
      final s = _session(auth, couriers: couriers)..loginAs(auth.user);
      const profile = CourierProfile(
        fullName: 'Ana Repartidora',
        docType: 'CC',
        docNumber: '1000000009',
        phone: '300 111 2233',
        vehicle: Vehicle.bicycle,
        contactEmail: 'ana@icesi.edu.co',
      );

      // Antes: s.saveCourierProfile; ahora el caso de uso del módulo
      // repartidor, conectado a la sesión por su adaptador.
      final result = await RegisterCourier(
        couriers,
        SessionCourierAdapter(s, _uni(InMemoryUniversityRepository()).queries),
      )(profile);

      expect(result.ok, isTrue);
      expect(couriers.saved?.fullName, 'Ana Repartidora');
      expect(couriers.saved?.vehicle, Vehicle.bicycle);
      expect(s.activeRole, UserRole.courier);
      expect(s.hasCourierProfile, isTrue);
    });

    test('restoreAsync recupera la sesión persistida', () async {
      final auth = _FakeRemoteAuth();
      final s = _session(auth);

      final restored = await s.restoreAsync();

      expect(restored?.id, auth.user.id);
      expect(s.isLoggedIn, isTrue);
    });

    test('logoutAsync limpia la sesión', () async {
      final auth = _FakeRemoteAuth();
      final s = _session(auth)..loginAs(auth.user);

      await s.logoutAsync();

      expect(s.isLoggedIn, isFalse);
      expect(s.user, isNull);
    });
  });

  group('Verificación universitaria remota', () {
    test('un dominio distinto devuelve domainMismatch sin verificar', () async {
      final auth = _FakeRemoteAuth();
      final remote = _FakeRemoteUniversity()..verifyCode = 'domain_mismatch';
      final s = _session(auth, university: remote)..loginAs(auth.user);
      final uni = _uni(remote);

      final result = await uni.verify(s.user?.id, 'icesi', 'ana@gmail.com');

      expect(result, VerifyResult.domainMismatch);
      expect(remote.verifyCalls, 1);
      expect(uni.queries.isVerifiedStudent(s.user?.id), isFalse);
    });

    test('un correo inválido no llama al backend', () async {
      final auth = _FakeRemoteAuth();
      final remote = _FakeRemoteUniversity();
      final s = _session(auth, university: remote)..loginAs(auth.user);
      final uni = _uni(remote);

      final result = await uni.verify(s.user?.id, 'icesi', 'sin-arroba');

      expect(result, VerifyResult.invalidEmail);
      expect(remote.verifyCalls, 0);
    });

    test('ok guarda la universidad verificada en la sesión', () async {
      final auth = _FakeRemoteAuth();
      final remote = _FakeRemoteUniversity();
      final s = _session(auth, university: remote)..loginAs(auth.user);
      final uni = _uni(remote);

      final result = await uni.verify(s.user?.id, 'icesi', 'ana@icesi.edu.co');

      expect(result, VerifyResult.ok);
      expect(uni.queries.verifiedUniversityId(s.user?.id), 'icesi');
      expect(uni.queries.emailOf(s.user?.id), 'ana@icesi.edu.co');
    });

    test('un error del RPC se traduce a rpcError', () async {
      final auth = _FakeRemoteAuth();
      final remote = _FakeRemoteUniversity()..verifyCode = 'algo_raro';
      final s = _session(auth, university: remote)..loginAs(auth.user);
      final uni = _uni(remote);

      final result = await uni.verify(s.user?.id, 'icesi', 'ana@icesi.edu.co');

      expect(result, VerifyResult.rpcError);
    });
  });

  group('Código institucional', () {
    test('enviar el código devuelve codeSent', () async {
      final auth = _FakeRemoteAuth();
      final remote = _FakeRemoteUniversity();
      final s = _session(auth, university: remote)..loginAs(auth.user);
      final uni = _uni(remote);

      final result = await uni.sendCode(
        s.user?.id,
        'icesi',
        'ana@icesi.edu.co',
      );

      expect(result, VerifyResult.codeSent);
    });

    test('un código correcto activa la verificación por 30 días', () async {
      final auth = _FakeRemoteAuth();
      final remote = _FakeRemoteUniversity();
      final s = _session(auth, university: remote)..loginAs(auth.user);
      final uni = _uni(remote);

      final result = await uni.confirmCode(
        s.user?.id,
        universityId: 'icesi',
        email: 'ana@icesi.edu.co',
        code: '123456',
      );

      expect(result, VerifyResult.ok);
      expect(uni.queries.isVerifiedStudent(s.user?.id), isTrue);
      expect(uni.queries.expiresAt(s.user?.id), isNotNull);
    });

    test('un código incorrecto devuelve invalidToken', () async {
      final auth = _FakeRemoteAuth();
      final remote = _FakeRemoteUniversity()
        ..confirmCodeResult = 'invalid_token';
      final s = _session(auth, university: remote)..loginAs(auth.user);
      final uni = _uni(remote);

      final result = await uni.confirmCode(
        s.user?.id,
        universityId: 'icesi',
        email: 'ana@icesi.edu.co',
        code: '000000',
      );

      expect(result, VerifyResult.invalidToken);
      expect(uni.queries.isVerifiedStudent(s.user?.id), isFalse);
    });

    test('una verificación vencida deja de contar', () async {
      final auth = _FakeRemoteAuth();
      final remote = _FakeRemoteUniversity();
      final s = _session(auth, university: remote)..loginAs(auth.user);
      final uni = _uni(remote);
      remote.setStatus(
        s.user!.id,
        UniversityStatus(
          verifiedUniversityId: 'icesi',
          expiresAt: DateTime(2025),
        ),
      );

      expect(uni.queries.isVerifiedStudent(s.user?.id), isFalse);
      expect(uni.queries.verifiedUniversityId(s.user?.id), isNull);
    });
  });
}
