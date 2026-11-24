import 'dart:async';

import '../../core/constants/catalog_constants.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/ports/catalog_ports.dart';
import '../../domain/repositories/session_repository.dart';

/// Conecta el contexto del catálogo con la sesión: avisa solo cuando cambian
/// el punto de entrega o el horario de demostración (no en cada cambio).
class SessionCatalogAdapter implements CatalogContextPort {
  /// Escucha el estado de la sesión.
  SessionCatalogAdapter(this._session)
    : _lastPoint = _session.current.pointId,
      _lastLunch = _session.current.settings.demoLunch {
    _sub = _session.changes.listen((_) => _onSession());
  }

  final SessionRepository _session;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  late final StreamSubscription<void> _sub;
  String _lastPoint;
  bool _lastLunch;

  /// Punto de entrega activo.
  @override
  DeliveryPoint get point => pointById(_session.current.pointId);

  /// Emite cuando cambian el punto o el horario de demostración.
  @override
  Stream<void> get changes => _changes.stream;

  /// Compara con lo último visto y avisa si cambió.
  void _onSession() {
    final s = _session.current;
    if (s.pointId == _lastPoint && s.settings.demoLunch == _lastLunch) return;
    _lastPoint = s.pointId;
    _lastLunch = s.settings.demoLunch;
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Deja de escuchar la sesión.
  void dispose() {
    _sub.cancel();
    _changes.close();
  }
}
