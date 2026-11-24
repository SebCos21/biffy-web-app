import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/repositories/notification_repository.dart';
import '../models/app_notification.dart';
import 'notification_cache.dart';

/// Notificaciones en Supabase: las crea la base (0022) y llegan por Realtime.
/// Las que crea la app se ven al instante (caché) y las personales se guardan.
class SupabaseNotificationRepository implements NotificationRepository {
  /// Usa el cliente de Supabase indicado o el global.
  SupabaseNotificationRepository([sb.SupabaseClient? client])
    : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;
  final NotificationCache _cache = NotificationCache();

  /// Cancela la suscripción en vivo del usuario actual.
  void Function()? _stopWatching;
  String? _watchingUserId;

  /// Todos los avisos conocidos, del más nuevo al más viejo.
  @override
  List<AppNotification> get all => _cache.all;

  /// Emite cuando cambia la caché.
  @override
  Stream<void> get changes => _cache.changes;

  /// Los avisos viven en el servidor.
  @override
  bool get isRemote => true;

  /// Muestra el aviso al instante y guarda los personales (`user:<id>`).
  /// Si la base falla, el aviso local se conserva y se devuelve `network`.
  @override
  Future<NotificationResult> push(NotificationDraft draft) async {
    final n = _cache.insert(draft);
    if (!n.audience.startsWith('user:')) return NotificationResult.ok(n);
    try {
      await _client.from('notifications').insert({
        'user_id': n.audience.substring(5),
        'audience': n.audience,
        'title': n.title,
        'body': n.body,
        'route': n.route,
      });
      return NotificationResult.ok(n);
    } on Object {
      return NotificationResult('network', notification: n);
    }
  }

  /// Trae los últimos 50 avisos del usuario y los une a la caché.
  @override
  Future<NotificationResult> load(String userId) async {
    try {
      final rows = await _client
          .from('notifications')
          .select('id, title, body, audience, route, read_at, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      _cache.merge(rows.map(notificationFromRow));
      return const NotificationResult.ok();
    } on Object {
      // Sin red se conserva lo que ya había en la caché.
      return const NotificationResult('network');
    }
  }

  /// Escucha en Realtime los avisos nuevos o leídos del usuario.
  @override
  void watch(String userId) {
    if (_watchingUserId == userId) return;
    unwatch();
    _watchingUserId = userId;
    try {
      final channel = _client
          .channel('biffy-notifications-$userId')
          .onPostgresChanges(
            event: sb.PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: sb.PostgresChangeFilter(
              type: sb.PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final row = payload.newRecord;
              if (row['id'] == null) return;
              _cache.upsert(notificationFromRow(row));
            },
          )
          .subscribe();
      _stopWatching = () => _client.removeChannel(channel);
    } on Object {
      _stopWatching = null;
    }
  }

  /// Cancela la suscripción en vivo.
  @override
  void unwatch() {
    _stopWatching?.call();
    _stopWatching = null;
    _watchingUserId = null;
  }

  /// Marca el aviso como leído en la caché y, si tiene uuid, en la base.
  @override
  Future<NotificationResult> markRead(String id) async {
    final n = _cache.markRead(id);
    if (n == null) return const NotificationResult('not_found');
    // Los ids locales (`n1`) no son uuid: solo existen en la caché.
    if (!_uuid.hasMatch(id)) return NotificationResult.ok(n);
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
      return NotificationResult.ok(n);
    } on Object {
      // El estado local ya cambió; se informa el fallo de red.
      return NotificationResult('network', notification: n);
    }
  }

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Convierte una fila de `notifications` al modelo (hora local).
  @visibleForTesting
  static AppNotification notificationFromRow(Map<String, dynamic> row) =>
      AppNotification(
        id: row['id'] as String,
        title: (row['title'] as String?) ?? '',
        body: (row['body'] as String?) ?? '',
        audience: (row['audience'] as String?) ?? 'all',
        createdAt:
            DateTime.tryParse(
              (row['created_at'] as String?) ?? '',
            )?.toLocal() ??
            DateTime.now(),
        route: row['route'] as String?,
        read: row['read_at'] != null,
      );

  /// Cancela Realtime y cierra la caché.
  void dispose() {
    unwatch();
    _cache.dispose();
  }
}
