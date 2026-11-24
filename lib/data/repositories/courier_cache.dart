import 'dart:async';

import '../../domain/entities/courier.dart';
import '../../domain/entities/user.dart';

/// Caché por cuenta del estado del repartidor, compartida por los
/// repositorios de demo y de Supabase. Avisa por [changes] en cada cambio.
class CourierCache {
  final Map<String, CourierStatus> _byUser = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Emite cuando cambia algún estado.
  Stream<void> get changes => _changes.stream;

  /// Estado de la cuenta (vacío si no hay registro).
  CourierStatus statusOf(String userId) =>
      _byUser[userId] ?? const CourierStatus();

  /// Guarda el perfil y conserva disponibilidad y zona.
  CourierStatus setProfile(String userId, CourierProfile profile) =>
      _put(userId, statusOf(userId).copyWith(profile: profile));

  /// Cambia la disponibilidad.
  CourierStatus setOnline(String userId, bool online) =>
      _put(userId, statusOf(userId).copyWith(online: online));

  /// Cambia la zona de reparto.
  CourierStatus setZone(String userId, CourierZone zone) =>
      _put(userId, statusOf(userId).copyWith(zone: zone));

  /// Reemplaza el estado completo de la cuenta.
  CourierStatus replace(String userId, CourierStatus status) =>
      _put(userId, status);

  /// Guarda el estado y avisa a los oyentes.
  CourierStatus _put(String userId, CourierStatus status) {
    _byUser[userId] = status;
    if (!_changes.isClosed) _changes.add(null);
    return status;
  }

  /// Cierra el stream de cambios.
  void dispose() => _changes.close();
}
