import 'package:flutter/foundation.dart';

import '../../core/constants/catalog_constants.dart';
import '../../core/utils/clock.dart';
import '../../data/models/catalog.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/addresses/address_usecases.dart';
import '../../domain/usecases/courier/courier_usecases.dart';
import '../../domain/usecases/notifications/notification_usecases.dart';
import '../../domain/usecases/preferences/preferences_usecases.dart';
import '../../domain/usecases/university/university_usecases.dart';
import '../../domain/usecases/wallet/wallet_usecases.dart';

/// Sesión simulada: usuario, rol activo, datos personales y preferencias.
class SessionController extends ChangeNotifier {
  /// Recibe el repositorio de auth, los casos de uso de avisos y el reloj.
  SessionController(
    this._auth,
    this._notifications,
    this._clock, {
    required CourierQueries couriers,
    required LoadCourier loadCourier,
    required WalletUseCases wallet,
    required PreferencesUseCases preferences,
    required this._addresses,
    required this._university,
    ProfileRepository? profile,
  }) : _couriers = couriers, // ignore: prefer_initializing_formals
       _loadCourier = loadCourier, // ignore: prefer_initializing_formals
       _wallet = wallet, // ignore: prefer_initializing_formals
       _prefs = preferences,
       _profile = profile; // ignore: prefer_initializing_formals

  final AuthRepository _auth;

  // TODO(puente): la sesión publica y sincroniza avisos con los casos de uso
  // de notificaciones hasta que el AuthBloc la reemplace (módulo 6).
  final NotificationUseCases _notifications;
  final Clock _clock;

  // TODO(puente): la sesión lee el perfil de repartidor (router) y lo carga al
  // iniciar sesión hasta que el AuthBloc la reemplace (módulo 6).
  final CourierQueries _couriers;
  final LoadCourier _loadCourier;

  // TODO(puente): la sesión acredita la bienvenida y la encuesta y carga la
  // billetera al iniciar sesión hasta que el AuthBloc la reemplace (módulo 6).
  final WalletUseCases _wallet;

  // TODO(puente): la sesión hereda las preferencias del invitado, las carga al
  // iniciar sesión y fija la universidad elegida hasta el AuthBloc (módulo 6).
  final PreferencesUseCases _prefs;
  // TODO(puente): la sesión crea la dirección inicial al registrarse, la
  // carga al iniciar sesión y fija el punto de entrega hasta el AuthBloc.
  final AddressUseCases _addresses;

  // TODO(puente): la sesión carga la verificación universitaria al iniciar
  // sesión hasta que el AuthBloc la reemplace (módulo 6).
  final UniversityUseCases _university;

  /// Repositorio de datos personales; null en modo demo.
  final ProfileRepository? _profile;

  AppUser? _user;
  UserRole _activeRole = UserRole.buyer;
  final Map<String, UserData> _data = {};
  final UserData _guest = UserData();
  AppSettings _settings = const AppSettings();
  String _pointId = 'icesi-biblioteca';

  /// Usuario con sesión iniciada, si hay.
  AppUser? get user => _user;

  /// `true` si hay una cuenta activa.
  bool get isLoggedIn => _user != null;

  /// Rol con el que se está usando la app.
  UserRole get activeRole => _activeRole;

  /// Ajustes locales vigentes.
  AppSettings get settings => _settings;

  /// Repositorio de autenticación en uso.
  AuthRepository get auth => _auth;

  /// Datos del usuario activo o del invitado.
  UserData get data => _user == null ? _guest : dataFor(_user!.id);

  /// Datos de un usuario, creándolos si no existen.
  UserData dataFor(String userId) => _data.putIfAbsent(userId, UserData.new);

  /// Punto de entrega activo.
  DeliveryPoint get point => pointById(_pointId);

  /// Id del punto de entrega activo.
  String get pointId => _pointId;

  /// `true` si el usuario ya registró perfil de repartidor.
  bool get hasCourierProfile => _couriers.hasProfile(_user?.id);

  /// Negocio vinculado a la cuenta, si es restaurante.
  String? get businessId => _user?.businessId;

  // ---------------------------------------------------------------- Auth

  /// Inicia sesión de forma síncrona (modo demo).
  AppUser login(String email, String password) {
    final u = _auth.login(email, password);
    _startSession(u);
    return u;
  }

  /// Acceso rápido a cuentas de demostración.
  void loginAs(AppUser u) => _startSession(u);

  /// Registra la cuenta y crea su dirección inicial.
  AppUser register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String phone = '',
  }) {
    final u = _auth.register(
      name: name,
      email: email,
      password: password,
      role: role,
      phone: phone,
    );
    // La dirección inicial del comprador es su punto de entrega actual.
    if (role == UserRole.buyer) _addresses.createInitial(u.id, point);
    _startSession(u);
    return u;
  }

  /// Activa la cuenta, hereda preferencias y acredita bienvenida.
  void _startSession(AppUser u, {bool localWelcome = true}) {
    _user = u;
    _activeRole = u.role;
    final d = dataFor(u.id);
    // Las preferencias del modo invitado se conservan si la cuenta no tiene.
    _prefs.adoptGuest(u.id);
    // En modo remoto las Gotas de bienvenida las acredita la base.
    if (localWelcome && !d.welcomeGranted && u.role == UserRole.buyer) {
      d.welcomeGranted = true;
      _wallet.credit(u.id, kWelcomeGotas, 'Bienvenida a Biffy (demo)');
      _notifications.push(
        title: '¡Bienvenido a Biffy! 🐝',
        body: 'Te regalamos $kWelcomeGotas Gotas de demostración.',
        audience: 'user:${u.id}',
        route: '/recompensas',
      );
    }
    final addr = _addresses.queries.defaultOf(u.id);
    if (addr != null) _pointId = addr.pointId;
    notifyListeners();
  }

  /// Cierra la sesión local y vuelve al modo invitado.
  void logout() {
    _notifications.sync.stop();
    _user = null;
    _activeRole = UserRole.buyer;
    notifyListeners();
  }

  // ----------------------------------------------------- Auth asíncrona
  // Las pantallas usan esta ruta: con Supabase habla con Auth; en demo
  // resuelve al instante contra los datos en memoria.

  /// Inicia sesión contra el backend y trae los datos remotos.
  Future<AppUser> loginAsync(String email, String password) async {
    final u = await _auth.signIn(email, password);
    _startSession(u, localWelcome: !_auth.isRemote);
    await _hydrateRemote(u);
    return u;
  }

  /// Registra la cuenta por la ruta asíncrona.
  Future<AppUser> registerAsync({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String phone = '',
  }) async {
    final u = await _auth.signUp(
      name: name,
      email: email,
      password: password,
      role: role,
      phone: phone,
    );

    if (_auth.isRemote) {
      _startSession(u, localWelcome: false);
      await _hydrateRemote(u);
      return u;
    }

    // La dirección inicial del comprador es su punto de entrega actual.
    if (role == UserRole.buyer) _addresses.createInitial(u.id, point);
    _startSession(u);
    return u;
  }

  /// Cierra la sesión remota y la local.
  Future<void> logoutAsync() async {
    await _auth.signOut();
    logout();
  }

  /// Recupera la sesión persistida al abrir la app (solo backend real).
  Future<AppUser?> restoreAsync() async {
    final u = await _auth.restoreSession();
    if (u == null) return null;
    _startSession(u, localWelcome: !_auth.isRemote);
    await _hydrateRemote(u);
    return u;
  }

  /// Vuelve a leer saldo, direcciones y perfil desde el backend.
  ///
  /// Se usa después de canjear Gotas o de completar preferencias.
  Future<void> refreshRemote() async {
    final u = _user;
    if (u == null || !_auth.isRemote) return;
    await _hydrateRemote(u);
  }

  /// Trae saldo, direcciones y perfil del backend sin romper la sesión si
  /// falla la red: la sesión ya es válida y se conserva la caché local.
  Future<void> _hydrateRemote(AppUser u) async {
    try {
      await _hydrateRemoteData(u);
    } on Object {
      // Sin red o con RLS caída: se mantiene lo que ya había en memoria.
    }
  }

  /// Lecturas remotas de la hidratación (pueden lanzar si falla la red).
  Future<void> _hydrateRemoteData(AppUser u) async {
    // Las tres lecturas base van en paralelo. La billetera (saldo y cupones)
    // la carga su propio caso de uso; en demo no hace nada.
    final walletF = _wallet.load(u.id);
    final savedF = _addresses.load(u.id);
    final courierF = _loadCourier(u.id, contactEmail: u.email);

    final wallet = await walletF;
    final saved = await savedF;
    final d = dataFor(u.id);

    // Con servidor la bienvenida ya la acreditó la base.
    if (_auth.isRemote && wallet.ok) d.welcomeGranted = true;

    // Las direcciones del backend fijan el punto de entrega (regla de radio).
    final first = saved.address;
    if (first != null) _pointId = first.pointId;

    // Perfil de repartidor: evita pedirle el registro a una cuenta que ya lo
    // tiene (si existe, queda conectada y en su zona).
    await courierF;

    // Preferencias, ajustes y favoritos del usuario (en paralelo).
    final profile = _profile;
    if (profile != null) {
      // Preferencias y favoritos los carga su propio caso de uso.
      final prefsF = _prefs.load(u.id);
      final settingsF = profile.settings(u.id);
      // Avisos guardados: se cargan en paralelo y luego se escuchan en vivo.
      final notifsF = _notifications.sync(u.id);
      // Verificación universitaria: la carga y aplica su propio caso de uso.
      final verificationF = _university.load(u.id);

      await prefsF;

      final s = await settingsF;
      if (s != null) {
        _settings = s;
        _clock.simulateLunch = s.demoLunch;
      }

      await verificationF;

      // Notificaciones guardadas (los cupones llegan con la billetera).
      await notifsF;
    }

    notifyListeners();
  }

  /// Cambia el rol activo de la sesión.
  void setActiveRole(UserRole role) {
    _activeRole = role;
    notifyListeners();
  }

  /// Actualiza nombre y teléfono del usuario (local y remoto).
  Future<void> updateProfile({String? name, String? phone}) async {
    final u = _user;
    if (u == null) return;
    if (name != null && name.trim().isNotEmpty) u.name = name.trim();
    if (phone != null) u.phone = phone.trim();
    notifyListeners();

    if (_auth.isRemote) {
      await _auth.saveProfile(u.id, name: name, phone: phone);
    }
  }

  /// Vincula la cuenta a un negocio y pasa al rol restaurante.
  void linkBusiness(String businessId) {
    _user?.businessId = businessId;
    _activeRole = UserRole.restaurant;
    notifyListeners();
  }

  // ------------------------------------------------------- Ubicación

  /// Cambia el punto de entrega activo.
  void setPoint(String id) {
    if (_pointId == id) return;
    _pointId = id;
    notifyListeners();
  }

  /// Guarda el medio de pago preferido.
  void setDefaultPayment(PaymentMethod m) {
    data.defaultPayment = m;
    notifyListeners();
  }

  // ---------------------------------------------------------- Ajustes

  /// Guarda los ajustes y aplica el horario de demostración.
  void updateSettings(AppSettings s) {
    _settings = s;
    _clock.simulateLunch = s.demoLunch;
    final u = _user;
    if (u != null && _profile != null) _profile.saveSettings(u.id, s);
    notifyListeners();
  }

  // ------------------------------------------------------- Repartidor

  /// Pasa al rol repartidor tras registrarse; si la cuenta no tenía teléfono
  /// guarda el del registro. Lo llama el adaptador de `RegisterCourier`.
  void activateCourierRole({required String phone}) {
    if (_user != null && phone.isNotEmpty && _user!.phone.isEmpty) {
      _user!.phone = phone;
    }
    _activeRole = UserRole.courier;
    notifyListeners();
  }
}
