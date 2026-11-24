import 'dart:async';

import '../../domain/entities/catalog.dart';
import '../../domain/ports/catalog_ports.dart';
import '../state/session_controller.dart';

// TODO(puente): adaptador sobre SessionController (ChangeNotifier); se
// reemplaza por el AuthBloc en el módulo 6.
/// Conecta el contexto del catálogo con la sesión: avisa solo cuando cambian
/// el punto de entrega o el horario de demostración (no en cada cambio).
class SessionCatalogAdapter implements CatalogContextPort {
  /// Escucha la sesión compartida.
  SessionCatalogAdapter(this._session)
    : _lastPoint = _session.pointId,
      _lastLunch = _session.settings.demoLunch {
    _session.addListener(_onSession);
  }

  final SessionController _session;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  String _lastPoint;
  bool _lastLunch;

  /// Punto de entrega activo.
  @override
  DeliveryPoint get point => _session.point;

  /// Emite cuando cambian el punto o el horario de demostración.
  @override
  Stream<void> get changes => _changes.stream;

  /// Compara con lo último visto y avisa si cambió.
  void _onSession() {
    final lunch = _session.settings.demoLunch;
    if (_session.pointId == _lastPoint && lunch == _lastLunch) return;
    _lastPoint = _session.pointId;
    _lastLunch = lunch;
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Deja de escuchar la sesión.
  void dispose() {
    _session.removeListener(_onSession);
    _changes.close();
  }
}
