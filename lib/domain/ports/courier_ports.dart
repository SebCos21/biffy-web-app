/// Lo que los casos de uso del repartidor necesitan saber de la sesión.
/// Lo implementa un adaptador sobre la sesión actual.
abstract interface class CourierSessionPort {
  /// Id de la cuenta con sesión, o `null` si es invitado.
  String? get currentUserId;

  /// `true` si la cuenta tiene una verificación universitaria vigente.
  bool get isVerifiedStudent;

  /// Pasa la sesión al rol repartidor y, si la cuenta no tenía teléfono,
  /// guarda el del registro.
  void activateCourierRole({required String phone});
}
