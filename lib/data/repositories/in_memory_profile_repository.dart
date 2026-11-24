import '../../domain/entities/user.dart';
import '../../domain/repositories/profile_repository.dart';

/// Ajustes del modo demo y de las pruebas: no se guardan fuera del equipo
/// (la sesión los conserva mientras la app está abierta).
class InMemoryProfileRepository implements ProfileRepository {
  /// En demo no hay ajustes guardados que leer.
  @override
  Future<AppSettings?> settings(String userId) async => null;

  /// En demo los ajustes no se persisten.
  @override
  Future<void> saveSettings(String userId, AppSettings s) async {}
}
