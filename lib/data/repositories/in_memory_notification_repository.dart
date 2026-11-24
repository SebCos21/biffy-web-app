import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import 'notification_cache.dart';

/// Avisos del modo demo y de las pruebas: viven solo en memoria, sin red.
class InMemoryNotificationRepository implements NotificationRepository {
  final NotificationCache _cache = NotificationCache();

  /// Todos los avisos, del más nuevo al más viejo.
  @override
  List<AppNotification> get all => _cache.all;

  /// Emite cuando cambia la caché.
  @override
  Stream<void> get changes => _cache.changes;

  /// En demo no hay servidor.
  @override
  bool get isRemote => false;

  /// Crea el aviso en memoria.
  @override
  Future<NotificationResult> push(NotificationDraft draft) async =>
      NotificationResult.ok(_cache.insert(draft));

  /// En demo no hay avisos guardados que traer.
  @override
  Future<NotificationResult> load(String userId) async =>
      const NotificationResult.ok();

  /// En demo no hay Realtime.
  @override
  void watch(String userId) {}

  /// En demo no hay suscripción que cancelar.
  @override
  void unwatch() {}

  /// Marca el aviso como leído en memoria.
  @override
  Future<NotificationResult> markRead(String id) async {
    final n = _cache.markRead(id);
    return n == null
        ? const NotificationResult('not_found')
        : NotificationResult.ok(n);
  }

  /// Cierra el stream de cambios.
  void dispose() => _cache.dispose();
}
