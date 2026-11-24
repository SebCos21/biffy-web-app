/// Traduce el código de una operación de la billetera a un mensaje en español.
///
/// Nunca devuelve el código crudo: uno desconocido se muestra como genérico.
String walletErrorMessage(String code) => switch (code) {
  'ok' => 'Listo.',
  'insufficient' => 'Saldo insuficiente',
  'not_logged_in' => 'Inicia sesión para usar tus Gotas.',
  'not_found' => 'Ese cupón ya no está disponible.',
  'network' => 'No pudimos actualizar tu saldo. Revisa tu conexión.',
  _ => 'Algo salió mal con tus Gotas. Intenta de nuevo.',
};

/// `true` si el fallo fue de conexión con el servidor.
bool isWalletTransportError(String code) => code == 'network';
