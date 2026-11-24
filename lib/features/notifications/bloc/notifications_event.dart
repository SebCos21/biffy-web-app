part of 'notifications_bloc.dart';

/// Eventos de avisos: la UI solo despacha estos.
sealed class NotificationsEvent {
  /// Constructor base de los eventos.
  const NotificationsEvent();
}

/// Interno: la caché del repositorio cambió.
final class NotificationsChanged extends NotificationsEvent {
  /// Crea el evento de refresco.
  const NotificationsChanged();
}

/// Publica un aviso nuevo para una audiencia.
final class NotificationPushed extends NotificationsEvent {
  /// Crea el evento con el contenido del aviso.
  const NotificationPushed({
    required this.title,
    required this.body,
    required this.audience,
    this.route,
  });

  /// Título del aviso.
  final String title;

  /// Texto del aviso.
  final String body;

  /// Destinatario (`all`, `user:<id>`, `business:<id>`…).
  final String audience;

  /// Ruta a la que lleva al tocarlo.
  final String? route;
}

/// El usuario abrió un aviso: se marca como leído.
final class NotificationOpened extends NotificationsEvent {
  /// Crea el evento con el id del aviso.
  const NotificationOpened(this.id);

  /// Id del aviso abierto.
  final String id;
}

/// Marca como leídos todos los avisos visibles para el usuario y rol.
final class AllNotificationsRead extends NotificationsEvent {
  /// Crea el evento con el usuario y rol activos.
  const AllNotificationsRead(this.user, this.role);

  /// Usuario con sesión (o `null` si es invitado).
  final AppUser? user;

  /// Rol activo.
  final UserRole role;
}
