import '../../domain/ports/courier_ports.dart';
import '../../domain/usecases/university/university_usecases.dart';
import '../state/session_controller.dart';

// TODO(puente): adaptador sobre SessionController (ChangeNotifier); se
// reemplaza por el AuthBloc en el módulo 6.
/// Conecta el puerto de sesión del repartidor con `SessionController`.
class SessionCourierAdapter implements CourierSessionPort {
  /// Recibe la sesión compartida y la verificación universitaria.
  SessionCourierAdapter(this._session, this._university);
  final SessionController _session;
  final UniversityQueries _university;

  /// Id de la cuenta con sesión.
  @override
  String? get currentUserId => _session.user?.id;

  /// `true` si la verificación universitaria sigue vigente.
  @override
  bool get isVerifiedStudent =>
      _university.isVerifiedStudent(_session.user?.id);

  /// Activa el rol repartidor en la sesión.
  @override
  void activateCourierRole({required String phone}) =>
      _session.activateCourierRole(phone: phone);
}
