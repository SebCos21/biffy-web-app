import 'user.dart';

/// Estado del repartidor de una cuenta: perfil, disponibilidad y zona.
///
/// Es inmutable: cada cambio crea un estado nuevo con [copyWith].
class CourierStatus {
  /// Crea el estado; por defecto sin perfil, desconectado y en zona general.
  const CourierStatus({
    this.profile,
    this.online = false,
    this.zone = CourierZone.general,
  });

  /// Datos de registro del repartidor (`null` si no se ha registrado).
  final CourierProfile? profile;

  /// `true` si está conectado y recibe ofertas.
  final bool online;

  /// Zona en la que acepta pedidos (general o campus).
  final CourierZone zone;

  /// `true` si la cuenta ya completó el registro de repartidor.
  bool get hasProfile => profile != null;

  /// Copia el estado cambiando solo lo indicado.
  CourierStatus copyWith({
    CourierProfile? profile,
    bool? online,
    CourierZone? zone,
  }) => CourierStatus(
    profile: profile ?? this.profile,
    online: online ?? this.online,
    zone: zone ?? this.zone,
  );
}
