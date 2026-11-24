import 'dart:async';

import '../../domain/entities/preferences_status.dart';

/// Caché por cuenta de preferencias y favoritos, compartida por los
/// repositorios de demo y de Supabase. Avisa por [changes] en cada cambio.
class PreferencesCache {
  final Map<String, PreferencesStatus> _byAccount = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Emite cuando cambia alguna cuenta.
  Stream<void> get changes => _changes.stream;

  /// Estado de la cuenta (vacío si no hay datos).
  PreferencesStatus statusOf(String account) =>
      _byAccount[account] ?? const PreferencesStatus();

  /// Reemplaza el estado de la cuenta y avisa.
  void replace(String account, PreferencesStatus status) {
    _byAccount[account] = status;
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Cierra el stream de cambios.
  void dispose() => _changes.close();
}
