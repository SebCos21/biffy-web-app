import '../entities/preferences_status.dart';
import '../entities/user.dart';
import '../preferences_errors.dart';

/// Resultado de una operación de preferencias o favoritos, igual en demo y
/// con servidor. [code] es `ok`, `not_logged_in` o `network`.
class PreferencesResult {
  /// Crea el resultado con su código y las Gotas acreditadas, si aplica.
  const PreferencesResult(this.code, {this.awarded = 0});

  /// Operación exitosa.
  const PreferencesResult.ok({this.awarded = 0}) : code = 'ok';

  /// Código de la operación.
  final String code;

  /// Gotas acreditadas por la encuesta (300 la primera vez; si no, 0).
  final int awarded;

  /// `true` si la operación terminó bien.
  bool get ok => code == 'ok';

  /// Mensaje en español para mostrar; nunca expone el código crudo.
  String get message => preferencesErrorMessage(code);

  /// `true` si falló la conexión con el servidor.
  bool get isTransportError => isPreferencesTransportError(code);

  /// Representación corta para depurar.
  @override
  String toString() => 'PreferencesResult($code)';
}

/// Contrato de preferencias, encuesta y favoritos por cuenta. Guarda una
/// caché que se lee de forma síncrona y avisa por [changes] cuando cambia.
/// El invitado usa la cuenta [kGuestAccount].
abstract interface class PreferencesRepository {
  /// Estado de la cuenta (vacío si no hay datos).
  PreferencesStatus statusOf(String account);

  /// Emite cada vez que cambia la caché.
  Stream<void> get changes;

  /// `true` si los datos se guardan en un servidor.
  bool get isRemote;

  /// Reemplaza el estado de la cuenta en la caché (sin escribir al servidor).
  void replace(String account, PreferencesStatus status);

  /// Guarda las preferencias en el servidor y, si [completeSurvey], acredita
  /// la encuesta en la base. No-op en demo. Nunca lanza.
  Future<PreferencesResult> persistPreferences(
    String userId,
    Preferences prefs, {
    required bool completed,
    required bool completeSurvey,
  });

  /// Marca o desmarca un favorito: la caché cambia al instante y, si el
  /// servidor falla, se revierte y devuelve `network` (sin favoritos
  /// "fantasma", criterio 8 de HU-2).
  Future<PreferencesResult> setFavorite(
    String userId,
    FavoriteKind kind,
    String id,
    bool favorite,
  );

  /// Trae preferencias y favoritos del servidor (no-op en demo). Nunca lanza.
  Future<PreferencesResult> load(String userId);
}
