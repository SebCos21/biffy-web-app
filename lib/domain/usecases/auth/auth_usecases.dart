import '../../../core/constants/catalog_constants.dart';
import '../../../core/utils/clock.dart';
import '../../auth_errors.dart';
import '../../entities/catalog.dart';
import '../../entities/session.dart';
import '../../entities/user.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/session_repository.dart';
import '../addresses/address_usecases.dart';
import '../courier/courier_usecases.dart';
import '../notifications/notification_usecases.dart';
import '../preferences/preferences_usecases.dart';
import '../university/university_usecases.dart';
import '../wallet/wallet_usecases.dart';

/// Lecturas síncronas de la sesión.
class AuthQueries {
  /// Recibe la sesión, la autenticación, el repartidor y las preferencias.
  const AuthQueries(this._session, this._auth, this._couriers, this._prefs);
  final SessionRepository _session;
  final AuthRepository _auth;
  final CourierQueries _couriers;
  final PreferencesQueries _prefs;

  /// Estado completo de la sesión.
  SessionSnapshot get current => _session.current;

  /// Cuenta con sesión iniciada, si hay.
  AppUser? get user => _session.current.user;

  /// `true` si hay una cuenta activa.
  bool get isLoggedIn => user != null;

  /// Rol con el que se está usando la app.
  UserRole get activeRole => _session.current.activeRole;

  /// Ajustes vigentes.
  AppSettings get settings => _session.current.settings;

  /// Id del punto de entrega activo.
  String get pointId => _session.current.pointId;

  /// Punto de entrega activo.
  DeliveryPoint get point => pointById(pointId);

  /// Negocio vinculado a la cuenta, si es restaurante.
  String? get businessId => user?.businessId;

  /// `true` si la cuenta ya registró perfil de repartidor.
  bool get hasCourierProfile => _couriers.hasProfile(user?.id);

  /// Medio de pago preferido de la cuenta (o del invitado).
  PaymentMethod get defaultPayment => _prefs.defaultPaymentOf(user?.id);

  /// `true` si la autenticación vive en un servidor.
  bool get isRemote => _auth.isRemote;

  /// Cuentas de demostración (vacío con servidor).
  List<AppUser> get demoAccounts => _auth.demoAccounts;

  /// Cuenta conocida por id.
  AppUser? accountById(String id) => _auth.byId(id);

  /// Cuenta dueña del negocio, si se conoce.
  AppUser? accountByBusiness(String businessId) => _auth.byBusiness(businessId);
}

/// Piezas compartidas por los casos de uso de la sesión.
class _Deps {
  _Deps({
    required this.auth,
    required this.session,
    required this.profile,
    required this.clock,
    required this.notifications,
    required this.wallet,
    required this.prefs,
    required this.addresses,
    required this.loadCourier,
    required this.university,
  });

  final AuthRepository auth;
  final SessionRepository session;
  final ProfileRepository profile;
  final Clock clock;
  final NotificationUseCases notifications;
  final WalletUseCases wallet;
  final PreferencesUseCases prefs;
  final AddressUseCases addresses;
  final LoadCourier loadCourier;
  final UniversityUseCases university;

  /// Reemplaza el estado de la sesión.
  void set(SessionSnapshot Function(SessionSnapshot s) change) =>
      session.replace(change(session.current));

  /// Activa la cuenta: hereda las preferencias del invitado, en demo acredita
  /// la bienvenida una sola vez y toma el punto de la dirección predeterminada.
  void startSession(AppUser u, {bool localWelcome = true}) {
    prefs.adoptGuest(u.id);
    if (localWelcome &&
        !wallet.repo.welcomeGrantedOf(u.id) &&
        u.role == UserRole.buyer) {
      wallet.repo.markWelcomeGranted(u.id);
      wallet.credit(u.id, kWelcomeGotas, 'Bienvenida a Biffy (demo)');
      notifications.push(
        title: '¡Bienvenido a Biffy! 🐝',
        body: 'Te regalamos $kWelcomeGotas Gotas de demostración.',
        audience: 'user:${u.id}',
        route: '/recompensas',
      );
    }
    final addr = addresses.queries.defaultOf(u.id);
    set(
      (s) => s.copyWith(
        user: u,
        activeRole: u.role,
        pointId: addr?.pointId,
      ),
    );
  }

  /// Trae billetera, direcciones, repartidor, preferencias, ajustes, avisos y
  /// verificación sin romper la sesión si falla la red.
  Future<void> hydrate(AppUser u) async {
    try {
      final walletF = wallet.load(u.id);
      final savedF = addresses.load(u.id);
      final courierF = loadCourier(u.id, contactEmail: u.email);

      final loaded = await walletF;
      final saved = await savedF;
      // Con servidor la bienvenida ya la acreditó la base.
      if (auth.isRemote && loaded.ok) wallet.repo.markWelcomeGranted(u.id);
      // Las direcciones del servidor fijan el punto de entrega.
      final first = saved.address;
      if (first != null) set((s) => s.copyWith(pointId: first.pointId));

      await courierF;

      final prefsF = prefs.load(u.id);
      final settingsF = profile.settings(u.id);
      final notifsF = notifications.sync(u.id);
      final verificationF = university.load(u.id);

      await prefsF;
      final settings = await settingsF;
      if (settings != null) {
        clock.simulateLunch = settings.demoLunch;
        set((s) => s.copyWith(settings: settings));
      }
      await verificationF;
      await notifsF;
    } on Object {
      // Sin red o con RLS caída: se mantiene lo que ya había en memoria.
    }
    session.touch();
  }

  /// Cierra la sesión local y vuelve al modo invitado.
  void logout() {
    notifications.sync.stop();
    set((s) => s.copyWith(clearUser: true, activeRole: UserRole.buyer));
  }
}

/// Traduce un fallo de la autenticación a [AuthResult].
AuthResult _failure(Object e, String networkMessage) => e is AuthException
    ? AuthResult('auth_error', serverMessage: e.message)
    : AuthResult('network', serverMessage: networkMessage);

/// Inicia sesión con correo y contraseña.
class SignIn {
  const SignIn._(this._d);
  final _Deps _d;

  /// Demo (síncrono): valida contra las cuentas en memoria.
  AuthResult demo(String email, String password) {
    try {
      final u = _d.auth.login(email, password);
      _d.startSession(u);
      return AuthResult.ok(u);
    } on Object catch (e) {
      return _failure(e, 'No pudimos iniciar sesión. Revisa tu conexión.');
    }
  }

  /// Con el servidor (o la demo por la misma ruta) y luego hidrata los datos.
  Future<AuthResult> call(String email, String password) async {
    try {
      final u = await _d.auth.signIn(email, password);
      _d.startSession(u, localWelcome: !_d.auth.isRemote);
      await _d.hydrate(u);
      return AuthResult.ok(u);
    } on Object catch (e) {
      return _failure(e, 'No pudimos iniciar sesión. Revisa tu conexión.');
    }
  }

  /// Acceso rápido a una cuenta de demostración.
  AuthResult demoAccount(AppUser u) {
    _d.startSession(u);
    return AuthResult.ok(u);
  }
}

/// Crea una cuenta con su rol.
class SignUp {
  const SignUp._(this._d);
  final _Deps _d;

  /// Demo (síncrono): crea la cuenta y, si es comprador, su dirección inicial.
  AuthResult demo({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String phone = '',
  }) {
    try {
      final u = _d.auth.register(
        name: name,
        email: email,
        password: password,
        role: role,
        phone: phone,
      );
      if (role == UserRole.buyer) {
        _d.addresses.createInitial(u.id, pointById(_d.session.current.pointId));
      }
      _d.startSession(u);
      return AuthResult.ok(u);
    } on Object catch (e) {
      return _failure(e, 'No pudimos crear la cuenta. Revisa tu conexión.');
    }
  }

  /// Con servidor la base crea perfil y bienvenida; en demo, como [demo].
  Future<AuthResult> call({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String phone = '',
  }) async {
    try {
      final u = await _d.auth.signUp(
        name: name,
        email: email,
        password: password,
        role: role,
        phone: phone,
      );
      if (_d.auth.isRemote) {
        _d.startSession(u, localWelcome: false);
        await _d.hydrate(u);
        return AuthResult.ok(u);
      }
      if (role == UserRole.buyer) {
        _d.addresses.createInitial(u.id, pointById(_d.session.current.pointId));
      }
      _d.startSession(u);
      return AuthResult.ok(u);
    } on Object catch (e) {
      return _failure(e, 'No pudimos crear la cuenta. Revisa tu conexión.');
    }
  }
}

/// Recupera la sesión guardada al abrir la app (solo con servidor).
class RestoreSession {
  const RestoreSession._(this._d);
  final _Deps _d;

  /// `ok` con la cuenta, `ok` sin cuenta si no había, o `network`.
  Future<AuthResult> call() async {
    try {
      final u = await _d.auth.restoreSession();
      if (u == null) return const AuthResult.ok();
      _d.startSession(u, localWelcome: !_d.auth.isRemote);
      await _d.hydrate(u);
      return AuthResult.ok(u);
    } on Object catch (e) {
      return _failure(e, 'No pudimos recuperar tu sesión.');
    }
  }
}

/// Cierra la sesión.
class SignOut {
  const SignOut._(this._d);
  final _Deps _d;

  /// Solo local (demo y pruebas).
  AuthResult local() {
    _d.logout();
    return const AuthResult.ok();
  }

  /// Cierra la sesión remota y la local (la local siempre, aunque falle la red).
  Future<AuthResult> call() async {
    try {
      await _d.auth.signOut();
    } on Object {
      // Sin red igual se cierra en el equipo.
    }
    return local();
  }
}

/// Vuelve a leer saldo, direcciones y perfil del servidor (tras canjes o
/// preferencias). No hace nada en demo ni sin sesión.
class RefreshAccount {
  const RefreshAccount._(this._d);
  final _Deps _d;

  /// Hidrata de nuevo la cuenta activa.
  Future<AuthResult> call() async {
    final u = _d.session.current.user;
    if (u == null || !_d.auth.isRemote) return const AuthResult.ok();
    await _d.hydrate(u);
    return AuthResult.ok(u);
  }
}

/// Cambios del perfil y del modo de uso de la cuenta activa.
class UpdateAccount {
  const UpdateAccount._(this._d);
  final _Deps _d;

  /// Cambia el rol con el que se usa la app.
  AuthResult setActiveRole(UserRole role) {
    _d.set((s) => s.copyWith(activeRole: role));
    return const AuthResult.ok();
  }

  /// Actualiza nombre y teléfono (local y, con servidor, en `profiles`).
  Future<AuthResult> updateProfile({String? name, String? phone}) async {
    final u = _d.session.current.user;
    if (u == null) return const AuthResult('not_logged_in');
    if (name != null && name.trim().isNotEmpty) u.name = name.trim();
    if (phone != null) u.phone = phone.trim();
    _d.session.touch();
    if (!_d.auth.isRemote) return AuthResult.ok(u);
    try {
      await _d.auth.saveProfile(u.id, name: name, phone: phone);
      return AuthResult.ok(u);
    } on Object catch (e) {
      return _failure(e, 'No pudimos guardar tus datos. Intenta de nuevo.');
    }
  }

  /// Vincula la cuenta a un negocio y pasa al rol restaurante.
  AuthResult linkBusiness(String businessId) {
    _d.session.current.user?.businessId = businessId;
    _d.set((s) => s.copyWith(activeRole: UserRole.restaurant));
    return const AuthResult.ok();
  }

  /// Alta real del negocio con `register_business` y vínculo de la cuenta.
  Future<AuthResult> registerBusiness(Map<String, dynamic> payload) async {
    try {
      final id = await _d.auth.registerBusiness(payload);
      if (id == null) {
        return const AuthResult(
          'auth_error',
          serverMessage:
              'No pudimos crear el negocio. Revisa los datos o tu conexión.',
        );
      }
      linkBusiness(id);
      return AuthResult.ok(_d.session.current.user, id);
    } on Object catch (e) {
      return _failure(
        e,
        'No pudimos crear el negocio. Revisa los datos o tu conexión.',
      );
    }
  }

  /// Pasa al rol repartidor tras registrarse; si la cuenta no tenía teléfono
  /// guarda el del registro.
  AuthResult activateCourierRole({required String phone}) {
    final u = _d.session.current.user;
    if (u != null && phone.isNotEmpty && u.phone.isEmpty) u.phone = phone;
    _d.set((s) => s.copyWith(activeRole: UserRole.courier));
    return const AuthResult.ok();
  }
}

/// Punto de entrega, medio de pago y ajustes.
class UpdateSessionSettings {
  const UpdateSessionSettings._(this._d);
  final _Deps _d;

  /// Cambia el punto de entrega activo.
  AuthResult setPoint(String pointId) {
    if (_d.session.current.pointId != pointId) {
      _d.set((s) => s.copyWith(pointId: pointId));
    }
    return const AuthResult.ok();
  }

  /// Guarda el medio de pago preferido.
  AuthResult setDefaultPayment(PaymentMethod method) {
    _d.prefs.setDefaultPayment(_d.session.current.user?.id, method);
    _d.session.touch();
    return const AuthResult.ok();
  }

  /// Guarda los ajustes, aplica el horario de demostración y, con cuenta,
  /// los persiste (no espera a la red).
  AuthResult updateSettings(AppSettings settings) {
    _d.clock.simulateLunch = settings.demoLunch;
    _d.set((s) => s.copyWith(settings: settings));
    final u = _d.session.current.user;
    if (u != null) {
      _d.profile.saveSettings(u.id, settings).catchError((Object _) {});
    }
    return const AuthResult.ok();
  }
}

/// Todos los casos de uso de la sesión, ya cableados. Lo recibe el `AuthBloc`.
class AuthUseCases {
  /// Ensambla los casos de uso.
  factory AuthUseCases({
    required AuthRepository auth,
    required SessionRepository session,
    required ProfileRepository profile,
    required Clock clock,
    required NotificationUseCases notifications,
    required WalletUseCases wallet,
    required PreferencesUseCases preferences,
    required AddressUseCases addresses,
    required CourierQueries couriers,
    required LoadCourier loadCourier,
    required UniversityUseCases university,
  }) {
    final d = _Deps(
      auth: auth,
      session: session,
      profile: profile,
      clock: clock,
      notifications: notifications,
      wallet: wallet,
      prefs: preferences,
      addresses: addresses,
      loadCourier: loadCourier,
      university: university,
    );
    return AuthUseCases._(
      session,
      AuthQueries(session, auth, couriers, preferences.queries),
      d,
    );
  }

  AuthUseCases._(this.session, this.queries, _Deps d)
    : signIn = SignIn._(d),
      signUp = SignUp._(d),
      restore = RestoreSession._(d),
      signOut = SignOut._(d),
      refresh = RefreshAccount._(d),
      account = UpdateAccount._(d),
      settings = UpdateSessionSettings._(d);

  /// Estado de la sesión (en memoria en los dos modos).
  final SessionRepository session;

  /// Lecturas.
  final AuthQueries queries;

  /// Iniciar sesión (servidor, demo síncrona y cuentas demo).
  final SignIn signIn;

  /// Registrar una cuenta con su rol.
  final SignUp signUp;

  /// Restaurar la sesión guardada.
  final RestoreSession restore;

  /// Cerrar sesión.
  final SignOut signOut;

  /// Volver a leer la cuenta del servidor.
  final RefreshAccount refresh;

  /// Rol, perfil, negocio y repartidor.
  final UpdateAccount account;

  /// Punto, medio de pago y ajustes.
  final UpdateSessionSettings settings;
}
