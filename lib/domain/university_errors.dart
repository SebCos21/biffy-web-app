/// Resultado de verificar el correo universitario (mismos valores que antes
/// vivían en la sesión).
enum VerifyResult {
  ok,
  codeSent,
  invalidEmail,
  domainMismatch,
  unknownUniversity,
  notAuthenticated,
  notLoggedIn,
  invalidToken,
  expiredToken,
  tooManyAttempts,
  notFound,
  rateLimited,
  tokenRequired,
  rpcError,
}

/// Traduce el resultado de la verificación a un mensaje en español (vacío
/// cuando terminó bien).
String verifyResultMessage(VerifyResult result) => switch (result) {
  VerifyResult.ok || VerifyResult.codeSent => '',
  VerifyResult.invalidEmail => 'Escribe un correo válido',
  VerifyResult.domainMismatch => 'El correo no pertenece a la universidad',
  VerifyResult.unknownUniversity => 'No encontramos esa universidad',
  VerifyResult.notAuthenticated ||
  VerifyResult.notLoggedIn => 'Inicia sesión primero',
  VerifyResult.invalidToken => 'El código no es correcto',
  VerifyResult.expiredToken => 'El código venció. Pide uno nuevo',
  VerifyResult.tooManyAttempts => 'Demasiados intentos. Pide un código nuevo',
  VerifyResult.notFound => 'No hay una verificación pendiente',
  VerifyResult.rateLimited => 'Espera un momento antes de pedir otro código',
  VerifyResult.tokenRequired => 'Primero pide el código a tu correo',
  VerifyResult.rpcError => 'No pudimos completar la verificación',
};
