import 'dart:async';

import '../../domain/entities/session.dart';
import '../../domain/repositories/session_repository.dart';

/// Estado de la sesión en memoria. Se usa en demo **y** con Supabase: la
/// cuenta la valida `AuthRepository`; aquí solo se recuerda la activa.
class InMemorySessionRepository implements SessionRepository {
  SessionSnapshot _current = const SessionSnapshot();
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Estado actual.
  @override
  SessionSnapshot get current => _current;

  /// Emite en cada cambio.
  @override
  Stream<void> get changes => _changes.stream;

  /// Reemplaza el estado y avisa.
  @override
  void replace(SessionSnapshot snapshot) {
    _current = snapshot;
    touch();
  }

  /// Avisa un cambio en sitio de la cuenta activa.
  @override
  void touch() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Cierra el stream de cambios.
  void dispose() => _changes.close();
}
