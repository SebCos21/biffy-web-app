import '../entities/session.dart';

/// Contrato del estado de la sesión en el equipo. Se lee de forma síncrona y
/// avisa por [changes] en cada cambio.
///
/// La sesión vive en el equipo en los dos modos: con Supabase la cuenta la
/// valida `AuthRepository` (y Supabase Auth guarda el token); este
/// repositorio solo recuerda quién está activo y con qué rol, punto y ajustes.
abstract interface class SessionRepository {
  /// Estado actual.
  SessionSnapshot get current;

  /// Emite cada vez que cambia el estado.
  Stream<void> get changes;

  /// Reemplaza el estado y avisa.
  void replace(SessionSnapshot snapshot);

  /// Avisa que la cuenta activa cambió en sitio (nombre, teléfono, negocio).
  void touch();
}
