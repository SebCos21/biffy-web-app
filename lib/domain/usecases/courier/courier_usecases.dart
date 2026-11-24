import '../../entities/courier.dart';
import '../../entities/user.dart';
import '../../ports/courier_ports.dart';
import '../../repositories/courier_repository.dart';

/// Registra (o actualiza) el perfil del repartidor y activa ese rol.
class RegisterCourier {
  /// Recibe el repositorio y la sesión.
  const RegisterCourier(this._repo, this._session);
  final CourierRepository _repo;
  final CourierSessionPort _session;

  /// Guarda el perfil local al instante, activa el rol y espera al servidor.
  /// Si el servidor falla devuelve `save_failed`; el perfil local se conserva.
  Future<CourierResult> call(CourierProfile profile) async {
    final userId = _session.currentUserId;
    if (userId == null) return const CourierResult('not_logged_in');
    final pending = _repo.saveProfile(userId, profile);
    _session.activateCourierRole(phone: profile.phone);
    return pending;
  }
}

/// Conecta o desconecta al repartidor.
class SetCourierAvailability {
  /// Recibe el repositorio y la sesión.
  const SetCourierAvailability(this._repo, this._session);
  final CourierRepository _repo;
  final CourierSessionPort _session;

  /// Exige sesión y perfil de repartidor.
  CourierResult call(bool online) {
    final userId = _session.currentUserId;
    if (userId == null) return const CourierResult('not_logged_in');
    if (!_repo.statusOf(userId).hasProfile) {
      return const CourierResult('no_profile');
    }
    return _repo.setOnline(userId, online);
  }
}

/// Cambia la zona de reparto; el modo Campus exige universidad verificada.
class SetCourierZone {
  /// Recibe el repositorio y la sesión.
  const SetCourierZone(this._repo, this._session);
  final CourierRepository _repo;
  final CourierSessionPort _session;

  /// Devuelve `campus_requires_verification` si falta la verificación.
  CourierResult call(CourierZone zone) {
    final userId = _session.currentUserId;
    if (userId == null) return const CourierResult('not_logged_in');
    if (zone == CourierZone.campus && !_session.isVerifiedStudent) {
      return const CourierResult('campus_requires_verification');
    }
    return _repo.setZone(userId, zone);
  }
}

/// Trae el perfil de repartidor guardado al iniciar sesión.
class LoadCourier {
  /// Recibe el repositorio.
  const LoadCourier(this._repo);
  final CourierRepository _repo;

  /// Carga el perfil de la cuenta; nunca lanza.
  Future<CourierResult> call(String userId, {String contactEmail = ''}) =>
      _repo.load(userId, contactEmail: contactEmail);
}

/// Lecturas síncronas del estado del repartidor.
class CourierQueries {
  /// Recibe el repositorio.
  const CourierQueries(this._repo);
  final CourierRepository _repo;

  /// Estado de la cuenta (vacío si no hay perfil).
  CourierStatus statusOf(String userId) => _repo.statusOf(userId);

  /// `true` si la cuenta tiene perfil de repartidor (`false` sin sesión).
  bool hasProfile(String? userId) =>
      userId != null && _repo.statusOf(userId).hasProfile;
}

/// Todos los casos de uso del repartidor, ya cableados. Lo recibe el
/// `CourierCubit`.
class CourierUseCases {
  /// Ensambla los casos de uso sobre el repositorio y la sesión.
  CourierUseCases({required this.repo, required CourierSessionPort session})
    : register = RegisterCourier(repo, session),
      setAvailability = SetCourierAvailability(repo, session),
      setZone = SetCourierZone(repo, session),
      load = LoadCourier(repo),
      queries = CourierQueries(repo);

  /// Repositorio del repartidor (en memoria o Supabase).
  final CourierRepository repo;

  /// Registrar el perfil.
  final RegisterCourier register;

  /// Conectarse o desconectarse.
  final SetCourierAvailability setAvailability;

  /// Cambiar de zona.
  final SetCourierZone setZone;

  /// Cargar el perfil guardado.
  final LoadCourier load;

  /// Lecturas.
  final CourierQueries queries;
}
