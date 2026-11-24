import 'entities/user.dart';

/// Resultado de una operación de la sesión, igual en demo y con servidor.
///
/// [code] es `ok`, `auth_error` (el servidor o la demo rechazaron los datos;
/// el texto llega en [message]), `network` o `not_logged_in`.
class AuthResult {
  /// Crea el resultado con su código, el mensaje del servidor y el usuario.
  const AuthResult(this.code, {this.serverMessage, this.user, this.businessId});

  /// Operación exitosa (con la cuenta afectada, si aplica).
  const AuthResult.ok([this.user, this.businessId])
    : code = 'ok',
      serverMessage = null;

  /// Código de la operación.
  final String code;

  /// Cuenta que inició sesión o se registró, si aplica.
  final AppUser? user;

  /// Negocio creado (solo al registrar un negocio).
  final String? businessId;

  /// Texto que devolvió el servidor o la demo (`AuthException`), si hubo.
  final String? serverMessage;

  /// `true` si la operación terminó bien.
  bool get ok => code == 'ok';

  /// Mensaje en español para mostrar; nunca expone el código crudo.
  String get message => serverMessage ?? authErrorMessage(code);

  /// `true` si falló la conexión con el servidor.
  bool get isTransportError => code == 'network';

  /// Representación corta para depurar.
  @override
  String toString() => 'AuthResult($code)';
}

/// Texto en español para cada código de la sesión sin mensaje propio.
String authErrorMessage(String code) => switch (code) {
  'ok' => 'Listo.',
  'not_logged_in' => 'Inicia sesión primero.',
  'network' => 'No pudimos conectar con el servidor. Revisa tu conexión.',
  _ => 'Algo salió mal con tu sesión. Intenta de nuevo.',
};
