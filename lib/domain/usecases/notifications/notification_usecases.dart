import '../../../core/utils/clock.dart';
import '../../entities/app_notification.dart';
import '../../entities/user.dart';
import '../../notification_rules.dart';
import '../../repositories/notification_repository.dart';

/// Crea un aviso para una audiencia con la hora del reloj de la app.
class PushNotification {
  /// Recibe el repositorio y el reloj.
  const PushNotification(this._repo, this._clock);
  final NotificationRepository _repo;
  final Clock _clock;

  /// Publica el aviso; la caché queda actualizada antes del primer `await`.
  Future<NotificationResult> call({
    required String title,
    required String body,
    required String audience,
    String? route,
  }) => _repo.push(
    NotificationDraft(
      title: title,
      body: body,
      audience: audience,
      route: route,
      createdAt: _clock.now(),
    ),
  );
}

/// Trae los avisos guardados del usuario y empieza a escucharlos en vivo.
class SyncNotifications {
  /// Recibe el repositorio de avisos.
  const SyncNotifications(this._repo);
  final NotificationRepository _repo;

  /// Carga los avisos del usuario y se suscribe a los nuevos.
  Future<NotificationResult> call(String userId) async {
    final result = await _repo.load(userId);
    _repo.watch(userId);
    return result;
  }

  /// Deja de escuchar (al cerrar sesión).
  void stop() => _repo.unwatch();
}

/// Marca un aviso como leído.
class MarkNotificationRead {
  /// Recibe el repositorio de avisos.
  const MarkNotificationRead(this._repo);
  final NotificationRepository _repo;

  /// Marca el aviso [id]; devuelve `not_found` si no está en la caché.
  Future<NotificationResult> call(String id) => _repo.markRead(id);
}

/// Marca como leídos todos los avisos visibles y sin leer del usuario.
class MarkAllNotificationsRead {
  /// Recibe el repositorio de avisos.
  const MarkAllNotificationsRead(this._repo);
  final NotificationRepository _repo;

  /// Marca uno por uno; devuelve el primer error, o `ok` si todos salieron bien.
  Future<NotificationResult> call(AppUser? user, UserRole role) async {
    final pending = visibleNotifications(
      _repo.all,
      user,
      role,
    ).where((n) => !n.read).toList();
    NotificationResult? failure;
    for (final n in pending) {
      final r = await _repo.markRead(n.id);
      if (!r.ok) failure ??= r;
    }
    return failure ?? const NotificationResult.ok();
  }
}

/// Lecturas de solo consulta sobre la caché de avisos.
class NotificationQueries {
  /// Recibe el repositorio de avisos.
  const NotificationQueries(this._repo);
  final NotificationRepository _repo;

  /// Todos los avisos, del más nuevo al más viejo.
  List<AppNotification> get all => _repo.all;

  /// Avisos visibles para el usuario y rol.
  List<AppNotification> visibleFor(AppUser? user, UserRole role) =>
      visibleNotifications(_repo.all, user, role);

  /// Cantidad de avisos visibles sin leer.
  int unreadFor(AppUser? user, UserRole role) =>
      unreadNotifications(_repo.all, user, role);
}

/// Todos los casos de uso de avisos, ya cableados. Es lo que recibe el
/// `NotificationsBloc`.
class NotificationUseCases {
  /// Ensambla los casos de uso sobre el repositorio y el reloj.
  NotificationUseCases({required this.repo, required Clock clock})
    : push = PushNotification(repo, clock),
      sync = SyncNotifications(repo),
      markRead = MarkNotificationRead(repo),
      markAllRead = MarkAllNotificationsRead(repo),
      queries = NotificationQueries(repo);

  /// Repositorio de avisos (en memoria o Supabase).
  final NotificationRepository repo;

  /// Crear un aviso.
  final PushNotification push;

  /// Cargar y escuchar los avisos del usuario.
  final SyncNotifications sync;

  /// Marcar un aviso como leído.
  final MarkNotificationRead markRead;

  /// Marcar todos los visibles como leídos.
  final MarkAllNotificationsRead markAllRead;

  /// Lecturas sobre la caché.
  final NotificationQueries queries;
}
