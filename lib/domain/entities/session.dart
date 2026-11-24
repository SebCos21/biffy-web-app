import 'user.dart';

/// Punto de entrega con el que arranca la app (también el del invitado).
const kDefaultPointId = 'icesi-biblioteca';

/// Estado de la sesión: cuenta activa, rol con el que se usa la app, punto de
/// entrega y ajustes. Es inmutable: cada cambio crea uno nuevo con [copyWith].
///
/// [AppUser] conserva campos editables (nombre, teléfono, negocio); quien los
/// cambia avisa al repositorio para que la UI se repinte.
class SessionSnapshot {
  /// Crea el estado; por defecto invitado, comprador y punto de la biblioteca.
  const SessionSnapshot({
    this.user,
    this.activeRole = UserRole.buyer,
    this.pointId = kDefaultPointId,
    this.settings = const AppSettings(),
  });

  /// Cuenta con sesión iniciada, si hay.
  final AppUser? user;

  /// Rol con el que se está usando la app.
  final UserRole activeRole;

  /// Punto de entrega activo (fija la regla de alcance).
  final String pointId;

  /// Ajustes de la app (notificaciones, modo oscuro, horario demo…).
  final AppSettings settings;

  /// `true` si hay una cuenta activa.
  bool get isLoggedIn => user != null;

  /// Copia el estado cambiando solo lo indicado ([clearUser] cierra sesión).
  SessionSnapshot copyWith({
    AppUser? user,
    bool clearUser = false,
    UserRole? activeRole,
    String? pointId,
    AppSettings? settings,
  }) => SessionSnapshot(
    user: clearUser ? null : (user ?? this.user),
    activeRole: activeRole ?? this.activeRole,
    pointId: pointId ?? this.pointId,
    settings: settings ?? this.settings,
  );
}
