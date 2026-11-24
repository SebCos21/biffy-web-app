part of 'notifications_bloc.dart';

/// Acciones sobre avisos que terminan con un [NotificationOutcome].
enum NotificationAction { push, open, markAllRead }

/// Resultado de la última acción. [id] crece con cada resultado para que un
/// `BlocListener` reaccione una sola vez.
final class NotificationOutcome {
  /// Crea el resultado numerado de una acción.
  const NotificationOutcome(this.id, this.action, this.result);

  /// Número creciente del resultado.
  final int id;

  /// Acción que lo produjo.
  final NotificationAction action;

  /// Resultado tipado con su mensaje en español.
  final NotificationResult result;

  /// `true` si la acción terminó bien.
  bool get ok => result.ok;
}

/// Estado inmutable de los avisos de la app.
///
/// [AppNotification.read] cambia en sitio en la caché; [revision] sube con
/// cada refresco para que la UI se vuelva a pintar.
final class NotificationsState {
  /// Crea el estado con la lista de avisos.
  const NotificationsState({
    this.items = const [],
    this.revision = 0,
    this.outcome,
  });

  /// Todos los avisos, del más nuevo al más viejo.
  final List<AppNotification> items;

  /// Contador de refrescos.
  final int revision;

  /// Resultado de la última acción, si hubo.
  final NotificationOutcome? outcome;

  /// Copia el estado cambiando solo lo indicado.
  NotificationsState copyWith({
    List<AppNotification>? items,
    int? revision,
    NotificationOutcome? outcome,
  }) => NotificationsState(
    items: items ?? this.items,
    revision: revision ?? this.revision,
    outcome: outcome ?? this.outcome,
  );
}
