/// Traduce el código de una operación de direcciones a un mensaje en español.
/// Nunca devuelve el código crudo.
String addressErrorMessage(String code) => switch (code) {
  'ok' => 'Listo.',
  'not_logged_in' => 'Inicia sesión para guardar direcciones.',
  'not_found' => 'Esa dirección ya no existe.',
  'network' =>
    'Guardamos la dirección en este equipo, pero no pudimos sincronizarla. '
        'Revisa tu conexión.',
  _ => 'Algo salió mal con tus direcciones. Intenta de nuevo.',
};

/// `true` si el fallo fue de conexión con el servidor.
bool isAddressTransportError(String code) => code == 'network';
