import 'user.dart';

/// Cuenta bajo la que se guardan las preferencias del modo invitado (se
/// heredan al iniciar sesión si la cuenta no tiene las suyas).
const kGuestAccount = 'guest';

/// Qué se marca como favorito.
enum FavoriteKind {
  /// Un plato.
  dish,

  /// Una sede (restaurante).
  branch,
}

/// Preferencias, encuesta y favoritos de una cuenta. Es inmutable: cada
/// cambio crea un estado nuevo con [copyWith].
class PreferencesStatus {
  /// Crea el estado; por defecto vacío y sin encuesta.
  const PreferencesStatus({
    this.prefs = const Preferences(),
    this.completed = false,
    this.rewarded = false,
    this.favoriteDishes = const {},
    this.favoriteBranches = const {},
  });

  /// Gustos, estilo de vida, alergias, presupuesto y universidad elegida.
  final Preferences prefs;

  /// `true` si ya completó la encuesta de preferencias.
  final bool completed;

  /// `true` si ya recibió las Gotas de la encuesta (una sola vez).
  final bool rewarded;

  /// Platos favoritos (ids).
  final Set<String> favoriteDishes;

  /// Sedes favoritas (ids).
  final Set<String> favoriteBranches;

  /// Favoritos del tipo indicado.
  Set<String> favoritesOf(FavoriteKind kind) =>
      kind == FavoriteKind.dish ? favoriteDishes : favoriteBranches;

  /// Copia el estado cambiando solo lo indicado.
  PreferencesStatus copyWith({
    Preferences? prefs,
    bool? completed,
    bool? rewarded,
    Set<String>? favoriteDishes,
    Set<String>? favoriteBranches,
  }) => PreferencesStatus(
    prefs: prefs ?? this.prefs,
    completed: completed ?? this.completed,
    rewarded: rewarded ?? this.rewarded,
    favoriteDishes: favoriteDishes ?? this.favoriteDishes,
    favoriteBranches: favoriteBranches ?? this.favoriteBranches,
  );

  /// Copia con el favorito [id] agregado o quitado.
  PreferencesStatus withFavorite(FavoriteKind kind, String id, bool on) {
    final next = {...favoritesOf(kind)};
    on ? next.add(id) : next.remove(id);
    final fixed = Set<String>.unmodifiable(next);
    return kind == FavoriteKind.dish
        ? copyWith(favoriteDishes: fixed)
        : copyWith(favoriteBranches: fixed);
  }
}
