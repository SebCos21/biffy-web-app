import '../entities/user.dart';

/// Contrato de los ajustes de la app del usuario (lo demás del perfil vive en
/// sus propios repositorios). En modo demo no hay repositorio (todo vive en
/// memoria).
abstract interface class ProfileRepository {
  /// Lee los ajustes guardados del usuario.
  Future<AppSettings?> settings(String userId);

  /// Guarda los ajustes del usuario.
  Future<void> saveSettings(String userId, AppSettings s);
}
