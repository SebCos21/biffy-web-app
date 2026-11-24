import '../../domain/entities/courier.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/courier_repository.dart';
import 'courier_cache.dart';

/// Estado del repartidor en modo demo y pruebas: solo en memoria, sin red.
class InMemoryCourierRepository implements CourierRepository {
  final CourierCache _cache = CourierCache();

  /// Estado de la cuenta.
  @override
  CourierStatus statusOf(String userId) => _cache.statusOf(userId);

  /// Emite cuando cambia la caché.
  @override
  Stream<void> get changes => _cache.changes;

  /// En demo no hay servidor.
  @override
  bool get isRemote => false;

  /// Guarda el perfil en memoria.
  @override
  Future<CourierResult> saveProfile(
    String userId,
    CourierProfile profile,
  ) async => CourierResult.ok(_cache.setProfile(userId, profile));

  /// En demo el perfil ya vive en memoria: no hay nada que traer.
  @override
  Future<CourierResult> load(String userId, {String contactEmail = ''}) async =>
      CourierResult.ok(_cache.statusOf(userId));

  /// Cambia la disponibilidad en memoria.
  @override
  CourierResult setOnline(String userId, bool online) =>
      CourierResult.ok(_cache.setOnline(userId, online));

  /// Cambia la zona en memoria.
  @override
  CourierResult setZone(String userId, CourierZone zone) =>
      CourierResult.ok(_cache.setZone(userId, zone));

  /// Deja la cuenta demo ya registrada como repartidor.
  @override
  void insertSeed(String userId, CourierProfile profile) =>
      _cache.setProfile(userId, profile);

  /// Cierra el stream de cambios.
  void dispose() => _cache.dispose();
}
