import '../../domain/entities/preferences_status.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/preferences_repository.dart';
import 'preferences_cache.dart';

/// Preferencias y favoritos del modo demo y de las pruebas: solo en memoria.
class InMemoryPreferencesRepository implements PreferencesRepository {
  final PreferencesCache _cache = PreferencesCache();

  /// Estado de la cuenta.
  @override
  PreferencesStatus statusOf(String account) => _cache.statusOf(account);

  /// Emite cuando cambia la caché.
  @override
  Stream<void> get changes => _cache.changes;

  /// En demo no hay servidor.
  @override
  bool get isRemote => false;

  /// Reemplaza el estado en memoria.
  @override
  void replace(String account, PreferencesStatus status) =>
      _cache.replace(account, status);

  /// En demo no hay nada que guardar en un servidor.
  @override
  Future<PreferencesResult> persistPreferences(
    String userId,
    Preferences prefs, {
    required bool completed,
    required bool completeSurvey,
  }) async => const PreferencesResult.ok();

  /// Cambia el favorito en memoria.
  @override
  Future<PreferencesResult> setFavorite(
    String userId,
    FavoriteKind kind,
    String id,
    bool favorite,
  ) async {
    _cache.replace(
      userId,
      _cache.statusOf(userId).withFavorite(kind, id, favorite),
    );
    return const PreferencesResult.ok();
  }

  /// En demo no hay preferencias remotas que cargar.
  @override
  Future<PreferencesResult> load(String userId) async =>
      const PreferencesResult.ok();

  /// Cierra el stream de cambios.
  void dispose() => _cache.dispose();
}
