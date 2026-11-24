import 'dart:async';

import '../../domain/entities/address.dart';

/// Direcciones de una cuenta dentro de la caché.
class _Book {
  final List<Address> addresses = [];
  String? defaultId;
}

/// Caché por cuenta de direcciones, compartida por los repositorios de demo
/// y de Supabase. Avisa por [changes] en cada cambio.
class AddressCache {
  final Map<String, _Book> _books = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _seq = 0;

  /// Emite cuando cambia alguna cuenta.
  Stream<void> get changes => _changes.stream;

  /// Libreta de la cuenta, creándola si no existe.
  _Book _of(String userId) => _books.putIfAbsent(userId, _Book.new);

  /// Direcciones de la cuenta (solo lectura).
  List<Address> addressesOf(String userId) =>
      List.unmodifiable(_of(userId).addresses);

  /// Id de la predeterminada.
  String? defaultIdOf(String userId) => _of(userId).defaultId;

  /// Dirección por id dentro de la cuenta.
  Address? byId(String userId, String id) {
    for (final a in _of(userId).addresses) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Crea (id local `addr-N` si viene vacío) o reemplaza la dirección.
  Address save(String userId, Address a, {required bool makeDefault}) {
    final book = _of(userId);
    final saved = a.id.isEmpty
        ? (Address(
            id: 'addr-${++_seq}',
            label: a.label,
            line: a.line,
            details: a.details,
            neighborhood: a.neighborhood,
            reference: a.reference,
            pointId: a.pointId,
          )..dbId = a.dbId)
        : a;
    final i = book.addresses.indexWhere((x) => x.id == saved.id);
    if (i >= 0) {
      // Una edición llega como objeto nuevo: conserva el uuid de la base para
      // actualizar la fila en vez de crear otra.
      saved.dbId ??= book.addresses[i].dbId;
      book.addresses[i] = saved;
    } else {
      book.addresses.add(saved);
    }
    if (makeDefault || book.defaultId == null) book.defaultId = saved.id;
    _emit();
    return saved;
  }

  /// Quita la dirección; si era la predeterminada elige la primera.
  Address? delete(String userId, String id) {
    final book = _of(userId);
    final removed = byId(userId, id);
    book.addresses.removeWhere((a) => a.id == id);
    if (book.defaultId == id) {
      book.defaultId = book.addresses.isEmpty ? null : book.addresses.first.id;
    }
    _emit();
    return removed;
  }

  /// Marca la predeterminada.
  void setDefault(String userId, String id) {
    _of(userId).defaultId = id;
    _emit();
  }

  /// Reemplaza todas las direcciones y la predeterminada.
  void replaceAll(String userId, List<Address> list, {String? defaultId}) {
    final book = _of(userId);
    book.addresses
      ..clear()
      ..addAll(list);
    book.defaultId = defaultId;
    _emit();
  }

  /// Avisa que una dirección cambió en sitio (p. ej. llegó su uuid).
  void touch() => _emit();

  /// Avisa a los oyentes si el stream sigue abierto.
  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Cierra el stream de cambios.
  void dispose() => _changes.close();
}
