/// Traduce el código de una operación de preferencias o favoritos a un
/// mensaje en español. Nunca devuelve el código crudo.
String preferencesErrorMessage(String code) => switch (code) {
  'ok' => 'Listo.',
  'not_logged_in' => 'Inicia sesión para guardar favoritos.',
  'network' =>
    'No pudimos guardar el cambio. Revisa tu conexión e intenta de nuevo.',
  _ => 'Algo salió mal con tus preferencias. Intenta de nuevo.',
};

/// `true` si el fallo fue de conexión con el servidor.
bool isPreferencesTransportError(String code) => code == 'network';
