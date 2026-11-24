import 'dart:async';

import 'package:flutter/foundation.dart';

/// Avisa al router cada vez que [stream] emite (p. ej. el del `AuthBloc`),
/// para que vuelva a evaluar sus redirecciones.
///
/// Implementa [Listenable] a mano (sin `ChangeNotifier`): guarda los oyentes,
/// los llama en cada evento y cancela la suscripción en [dispose].
class StreamRefreshListenable implements Listenable {
  /// Se suscribe a [stream].
  StreamRefreshListenable(Stream<Object?> stream) {
    _sub = stream.listen((_) => _notify());
  }

  late final StreamSubscription<Object?> _sub;
  final List<VoidCallback> _listeners = [];
  bool _disposed = false;

  /// `true` después de [dispose].
  bool get isDisposed => _disposed;

  /// Cantidad de oyentes registrados (para pruebas y depuración).
  int get listenerCount => _listeners.length;

  /// Registra un oyente.
  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  /// Quita un oyente.
  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  /// Llama a cada oyente (sobre una copia, por si alguno se quita).
  void _notify() {
    if (_disposed) return;
    for (final l in List<VoidCallback>.of(_listeners)) {
      l();
    }
  }

  /// Cancela la suscripción y suelta a los oyentes.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _listeners.clear();
    await _sub.cancel();
  }
}
