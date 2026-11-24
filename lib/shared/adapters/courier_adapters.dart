import '../../domain/ports/courier_ports.dart';
import '../../domain/usecases/auth/auth_usecases.dart';
import '../../domain/usecases/university/university_usecases.dart';

/// Conecta el puerto de sesión del repartidor con los casos de uso de la
/// sesión y de la verificación universitaria.
class SessionCourierAdapter implements CourierSessionPort {
  /// Recibe la sesión y la verificación universitaria.
  SessionCourierAdapter(this._auth, this._university);
  final AuthUseCases _auth;
  final UniversityQueries _university;

  /// Id de la cuenta con sesión.
  @override
  String? get currentUserId => _auth.queries.user?.id;

  /// `true` si la verificación universitaria sigue vigente.
  @override
  bool get isVerifiedStudent =>
      _university.isVerifiedStudent(_auth.queries.user?.id);

  /// Activa el rol repartidor en la sesión.
  @override
  void activateCourierRole({required String phone}) =>
      _auth.account.activateCourierRole(phone: phone);
}
