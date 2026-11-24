/// Traduce el código de una operación del repartidor a un mensaje en español.
///
/// Nunca devuelve el código crudo: uno desconocido se muestra como genérico.
String courierErrorMessage(String code) => switch (code) {
  'ok' => 'Listo.',
  'not_logged_in' => 'Inicia sesión para usar el modo repartidor.',
  'no_profile' => 'Completa tu registro de repartidor primero.',
  'campus_requires_verification' =>
    'El modo Campus requiere universidad verificada.',
  'save_failed' =>
    'No pudimos guardar tu perfil de repartidor. Intenta de nuevo.',
  'network' => 'No pudimos leer tu perfil de repartidor. Revisa tu conexión.',
  'in_progress' => 'Estamos guardando tu perfil, espera un momento.',
  _ => 'Algo salió mal con tu perfil de repartidor. Intenta de nuevo.',
};

/// `true` si el fallo fue de conexión con el servidor.
bool isCourierTransportError(String code) =>
    code == 'network' || code == 'save_failed';
