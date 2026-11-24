import 'dart:async';

import '../../domain/entities/university_status.dart';

/// Caché por cuenta de la verificación universitaria y del código pendiente,
/// compartida por los repositorios de demo y de Supabase.
class UniversityCache {
  final Map<String, UniversityStatus> _byUser = {};
  final Map<String, String?> _pending = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Emite cuando cambia alguna cuenta.
  Stream<void> get changes => _changes.stream;

  /// Estado de la cuenta.
  UniversityStatus statusOf(String userId) =>
      _byUser[userId] ?? const UniversityStatus();

  /// Reemplaza el estado y avisa.
  void setStatus(String userId, UniversityStatus status) {
    _byUser[userId] = status;
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Código de demostración pendiente.
  String? pendingCodeOf(String userId) => _pending[userId];

  /// Guarda o descarta el código pendiente.
  void setPendingCode(String userId, String? code) => _pending[userId] = code;

  /// Cierra el stream de cambios.
  void dispose() => _changes.close();
}
