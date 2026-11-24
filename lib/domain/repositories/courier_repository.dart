import '../courier_errors.dart' as errors;
import '../entities/courier.dart';
import '../entities/user.dart';

/// Resultado de una operación del repartidor, igual en demo y con servidor.
///
/// [code] es `ok`, `not_logged_in`, `no_profile`,
/// `campus_requires_verification`, `save_failed`, `network` o `in_progress`.
class CourierResult {
  /// Crea el resultado con su código y el estado resultante, si aplica.
  const CourierResult(this.code, {this.status});

  /// Operación exitosa.
  const CourierResult.ok([CourierStatus? status]) : this('ok', status: status);

  /// Código de la operación.
  final String code;

  /// Estado del repartidor tras la operación, si aplica.
  final CourierStatus? status;

  /// `true` si la operación terminó bien.
  bool get ok => code == 'ok';

  /// Mensaje en español para mostrar; nunca expone el código crudo.
  String get message => errors.courierErrorMessage(code);

  /// `true` si falló la conexión con el servidor.
  bool get isTransportError => errors.isCourierTransportError(code);

  /// Representación corta para depurar.
  @override
  String toString() => 'CourierResult($code)';
}

/// Contrato del estado del repartidor. Guarda una caché por cuenta que las
/// pantallas leen de forma síncrona y avisa por [changes] cuando cambia.
///
/// El perfil se guarda en el servidor (`courier_profiles`) cuando hay uno; la
/// disponibilidad y la zona son locales en los dos modos (límite conocido).
abstract interface class CourierRepository {
  /// Estado del repartidor de la cuenta (vacío si no se ha registrado).
  CourierStatus statusOf(String userId);

  /// Emite cada vez que cambia la caché.
  Stream<void> get changes;

  /// `true` si el perfil se guarda en un servidor.
  bool get isRemote;

  /// Guarda el perfil. La caché se actualiza antes de esperar a la red.
  Future<CourierResult> saveProfile(String userId, CourierProfile profile);

  /// Trae el perfil guardado de la cuenta. Si existe, la deja conectada y en
  /// zona Campus cuando el perfil tiene universidad (no-op en demo).
  Future<CourierResult> load(String userId, {String contactEmail = ''});

  /// Cambia la disponibilidad (solo local).
  CourierResult setOnline(String userId, bool online);

  /// Cambia la zona de reparto (solo local).
  CourierResult setZone(String userId, CourierZone zone);

  /// Solo para datos de demostración: deja una cuenta ya registrada.
  void insertSeed(String userId, CourierProfile profile);
}
