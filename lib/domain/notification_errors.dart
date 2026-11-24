/// Traduce el código de una operación de avisos a un mensaje en español.
///
/// Nunca devuelve el código crudo: un código desconocido se muestra como un
/// error genérico.
String notificationErrorMessage(String code) => switch (code) {
  'ok' => 'Listo.',
  'not_found' => 'Ese aviso ya no está disponible.',
  'network' =>
    'No pudimos sincronizar tus avisos. Revisa tu conexión; '
        'los verás aquí mientras tanto.',
  'server_error' => 'No pudimos actualizar tus avisos. Intenta de nuevo.',
  _ => 'Algo salió mal con tus avisos. Intenta de nuevo.',
};

/// `true` si el fallo fue de conexión (el aviso local se conserva igual).
bool isNotificationTransportError(String code) =>
    code == 'network' || code == 'server_error';
