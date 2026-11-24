import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/auth_errors.dart';
import '../../../domain/entities/catalog.dart';
import '../../../domain/entities/session.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/usecases/auth/auth_usecases.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Bloc global de la sesión: iniciar sesión, registro con rol, restaurar,
/// cerrar sesión, rol activo, perfil, punto de entrega y ajustes.
///
/// Traduce eventos en casos de uso (`domain/usecases/auth`) y publica el
/// resultado en [AuthState.outcome]. El estado vive en `SessionRepository`;
/// el Bloc lo refleja y avisa a las pantallas y al router.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  /// Se suscribe al estado de la sesión.
  AuthBloc(this.useCases)
    : super(AuthState(session: useCases.queries.current)) {
    on<AuthChanged>(
      (e, emit) => emit(
        state.copyWith(session: _q.current, revision: state.revision + 1),
      ),
    );
    on<LoginRequested>(
      (e, emit) => _run(e, emit, () => useCases.signIn(e.email, e.password)),
    );
    on<RegisterRequested>(
      (e, emit) => _run(
        e,
        emit,
        () => useCases.signUp(
          name: e.name,
          email: e.email,
          password: e.password,
          role: e.role,
          phone: e.phone,
        ),
      ),
    );
    on<SessionRestoreRequested>((e, emit) => _run(e, emit, useCases.restore.call));
    on<SessionRefreshRequested>((e, emit) => _run(e, emit, useCases.refresh.call));
    on<LogoutRequested>(
      (e, emit) => _run(
        e,
        emit,
        e.local ? () async => useCases.signOut.local() : useCases.signOut.call,
      ),
    );
    on<DemoAccountSelected>(
      (e, emit) => _run(e, emit, () async => useCases.signIn.demoAccount(e.user)),
    );
    on<ActiveRoleChanged>(
      (e, emit) =>
          _run(e, emit, () async => useCases.account.setActiveRole(e.role)),
    );
    on<ProfileUpdateRequested>(
      (e, emit) => _run(
        e,
        emit,
        () => useCases.account.updateProfile(name: e.name, phone: e.phone),
      ),
    );
    on<BusinessLinked>(
      (e, emit) =>
          _run(e, emit, () async => useCases.account.linkBusiness(e.businessId)),
    );
    on<BusinessRegistrationRequested>(
      (e, emit) =>
          _run(e, emit, () => useCases.account.registerBusiness(e.payload)),
    );
    on<DeliveryPointChanged>(
      (e, emit) =>
          _run(e, emit, () async => useCases.settings.setPoint(e.pointId)),
    );
    on<DefaultPaymentChanged>(
      (e, emit) => _run(
        e,
        emit,
        () async => useCases.settings.setDefaultPayment(e.method),
      ),
    );
    on<SettingsChanged>(
      (e, emit) => _run(
        e,
        emit,
        () async => useCases.settings.updateSettings(e.settings),
      ),
    );
    _changes = useCases.session.changes.listen((_) => add(AuthChanged()));
  }

  /// Casos de uso de la sesión ya cableados.
  final AuthUseCases useCases;
  StreamSubscription<void>? _changes;
  int _outcomeSeq = 0;

  AuthQueries get _q => useCases.queries;

  /// Despacha [event] y espera su resultado (para navegar o avisar en el
  /// mismo toque, p. ej. después de iniciar sesión).
  Future<AuthResult> request(AuthEvent event) {
    add(event);
    return event.result;
  }

  /// Ejecuta un caso de uso, publica el resultado y completa el evento. Una
  /// excepción se convierte en `network` en vez de llegar a la pantalla.
  Future<void> _run(
    AuthEvent event,
    Emitter<AuthState> emit,
    Future<AuthResult> Function() operation,
  ) async {
    AuthResult result;
    try {
      result = await operation();
    } on Object {
      result = const AuthResult('network');
    }
    emit(
      state.copyWith(
        session: _q.current,
        revision: state.revision + 1,
        outcome: AuthOutcome(++_outcomeSeq, result),
      ),
    );
    event._complete(result);
  }

  // ------------------------------------------------------------- Lecturas
  // Atajos síncronos: leen el estado de la sesión (fuente de verdad).

  /// Cuenta con sesión iniciada, si hay.
  AppUser? get user => _q.user;

  /// `true` si hay una cuenta activa.
  bool get isLoggedIn => _q.isLoggedIn;

  /// Rol con el que se está usando la app.
  UserRole get activeRole => _q.activeRole;

  /// Ajustes vigentes.
  AppSettings get settings => _q.settings;

  /// Punto de entrega activo.
  DeliveryPoint get point => _q.point;

  /// Id del punto de entrega activo.
  String get pointId => _q.pointId;

  /// Negocio vinculado a la cuenta, si es restaurante.
  String? get businessId => _q.businessId;

  /// `true` si la cuenta ya registró perfil de repartidor.
  bool get hasCourierProfile => _q.hasCourierProfile;

  /// Medio de pago preferido.
  PaymentMethod get defaultPayment => _q.defaultPayment;

  /// `true` si la autenticación vive en un servidor.
  bool get isRemote => _q.isRemote;

  /// Cuentas de demostración (vacío con servidor).
  List<AppUser> get demoAccounts => _q.demoAccounts;

  /// Cuenta conocida por id.
  AppUser? accountById(String id) => _q.accountById(id);

  /// Cuenta dueña del negocio.
  AppUser? accountByBusiness(String businessId) =>
      _q.accountByBusiness(businessId);

  /// Cancela la escucha de la sesión.
  @override
  Future<void> close() {
    _changes?.cancel();
    return super.close();
  }
}
