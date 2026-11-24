part of 'auth_bloc.dart';

/// Resultado de la última acción. [id] crece con cada resultado para que un
/// `BlocListener` reaccione una sola vez.
final class AuthOutcome {
  /// Crea el resultado numerado.
  const AuthOutcome(this.id, this.result);

  /// Número creciente del resultado.
  final int id;

  /// Resultado tipado con su mensaje en español.
  final AuthResult result;

  /// `true` si la acción terminó bien.
  bool get ok => result.ok;
}

/// Estado inmutable de la sesión que observan las pantallas.
///
/// [session] es la foto inmutable de la sesión; [revision] sube con cada
/// cambio (también cuando la cuenta cambia en sitio, p. ej. su nombre).
final class AuthState {
  /// Crea el estado.
  const AuthState({
    this.session = const SessionSnapshot(),
    this.revision = 0,
    this.outcome,
  });

  /// Cuenta, rol, punto y ajustes.
  final SessionSnapshot session;

  /// Contador de cambios.
  final int revision;

  /// Resultado de la última acción, si hubo.
  final AuthOutcome? outcome;

  /// Copia el estado cambiando solo lo indicado.
  AuthState copyWith({
    SessionSnapshot? session,
    int? revision,
    AuthOutcome? outcome,
  }) => AuthState(
    session: session ?? this.session,
    revision: revision ?? this.revision,
    outcome: outcome ?? this.outcome,
  );
}
