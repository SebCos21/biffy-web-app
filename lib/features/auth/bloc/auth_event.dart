part of 'auth_bloc.dart';

/// Eventos de la sesión: la UI solo despacha estos.
///
/// Cada evento lleva su resultado: [AuthBloc.request] lo despacha y espera a
/// que el manejador lo complete (para navegar después del cambio).
sealed class AuthEvent {
  /// Crea el evento con su resultado pendiente.
  AuthEvent();

  final Completer<AuthResult> _done = Completer<AuthResult>();

  /// Resultado de la operación (lo completa el Bloc).
  Future<AuthResult> get result => _done.future;

  /// Completa el resultado una sola vez.
  void _complete(AuthResult r) {
    if (!_done.isCompleted) _done.complete(r);
  }
}

/// Interno: cambió el estado de la sesión.
final class AuthChanged extends AuthEvent {
  /// Crea el evento de refresco.
  AuthChanged();
}

/// Iniciar sesión con correo y contraseña.
final class LoginRequested extends AuthEvent {
  /// Crea el evento con las credenciales.
  LoginRequested(this.email, this.password);

  /// Correo de la cuenta.
  final String email;

  /// Contraseña.
  final String password;
}

/// Crear una cuenta con su rol.
final class RegisterRequested extends AuthEvent {
  /// Crea el evento con los datos del formulario.
  RegisterRequested({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.phone = '',
  });

  /// Nombre de la persona.
  final String name;

  /// Correo de la cuenta.
  final String email;

  /// Contraseña.
  final String password;

  /// Rol con el que se registra.
  final UserRole role;

  /// Teléfono (opcional).
  final String phone;
}

/// Recuperar la sesión guardada al abrir la app.
final class SessionRestoreRequested extends AuthEvent {
  /// Crea el evento.
  SessionRestoreRequested();
}

/// Volver a leer la cuenta del servidor (tras canjes o preferencias).
final class SessionRefreshRequested extends AuthEvent {
  /// Crea el evento.
  SessionRefreshRequested();
}

/// Cerrar sesión.
final class LogoutRequested extends AuthEvent {
  /// Crea el evento (cierra en el servidor y en el equipo).
  LogoutRequested();
}

/// Entrar con una cuenta de demostración.
final class DemoAccountSelected extends AuthEvent {
  /// Crea el evento con la cuenta elegida.
  DemoAccountSelected(this.user);

  /// Cuenta de demostración.
  final AppUser user;
}

/// Cambiar el rol con el que se usa la app.
final class ActiveRoleChanged extends AuthEvent {
  /// Crea el evento con el rol.
  ActiveRoleChanged(this.role);

  /// Rol nuevo.
  final UserRole role;
}

/// Actualizar nombre y teléfono.
final class ProfileUpdateRequested extends AuthEvent {
  /// Crea el evento con los datos nuevos.
  ProfileUpdateRequested({this.name, this.phone});

  /// Nombre nuevo, si cambia.
  final String? name;

  /// Teléfono nuevo, si cambia.
  final String? phone;
}

/// Vincular la cuenta a un negocio ya creado (demo).
final class BusinessLinked extends AuthEvent {
  /// Crea el evento con el negocio.
  BusinessLinked(this.businessId);

  /// Id del negocio.
  final String businessId;
}

/// Registrar el negocio en el servidor (`register_business`) y vincularlo.
final class BusinessRegistrationRequested extends AuthEvent {
  /// Crea el evento con los datos del negocio y sus sedes.
  BusinessRegistrationRequested(this.payload);

  /// Datos que espera el RPC.
  final Map<String, dynamic> payload;
}

/// Cambiar el punto de entrega activo.
final class DeliveryPointChanged extends AuthEvent {
  /// Crea el evento con el punto.
  DeliveryPointChanged(this.pointId);

  /// Id del punto de entrega.
  final String pointId;
}

/// Cambiar el medio de pago preferido.
final class DefaultPaymentChanged extends AuthEvent {
  /// Crea el evento con el medio de pago.
  DefaultPaymentChanged(this.method);

  /// Medio de pago elegido.
  final PaymentMethod method;
}

/// Guardar los ajustes de la app.
final class SettingsChanged extends AuthEvent {
  /// Crea el evento con los ajustes nuevos.
  SettingsChanged(this.settings);

  /// Ajustes nuevos.
  final AppSettings settings;
}
