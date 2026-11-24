import 'dart:async';

import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

/// Caché en memoria de avisos que comparten los repositorios de demo y de
/// Supabase: ordena, evita duplicados y avisa por [changes].
class NotificationCache {
  final List<AppNotification> _items = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _seq = 0;

  /// Avisos del más nuevo al más viejo (solo lectura).
  List<AppNotification> get all => List.unmodifiable(_items);

  /// Emite cuando cambia la caché.
  Stream<void> get changes => _changes.stream;

  /// Crea el aviso con un id local (`n1`, `n2`…) y lo pone de primero.
  AppNotification insert(NotificationDraft d) {
    final n = AppNotification(
      id: 'n${++_seq}',
      title: d.title,
      body: d.body,
      audience: d.audience,
      createdAt: d.createdAt,
      route: d.route,
    );
    _items.insert(0, n);
    _emit();
    return n;
  }

  /// Une avisos ya guardados sin duplicar ids y reordena por fecha.
  void merge(Iterable<AppNotification> items) {
    final known = {for (final n in _items) n.id};
    var changed = false;
    for (final n in items) {
      if (known.add(n.id)) {
        _items.add(n);
        changed = true;
      }
    }
    if (!changed) return;
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _emit();
  }

  /// Agrega o actualiza (estado leído) un aviso que llega en vivo.
  void upsert(AppNotification n) {
    for (final item in _items) {
      if (item.id == n.id) {
        if (item.read == n.read) return;
        item.read = n.read;
        _emit();
        return;
      }
    }
    merge([n]);
  }

  /// Marca el aviso como leído; devuelve `null` si no existe.
  AppNotification? markRead(String id) {
    for (final n in _items) {
      if (n.id == id) {
        n.read = true;
        _emit();
        return n;
      }
    }
    return null;
  }

  /// Avisa a los oyentes si el controlador sigue abierto.
  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Cierra el stream de cambios.
  void dispose() => _changes.close();
}
