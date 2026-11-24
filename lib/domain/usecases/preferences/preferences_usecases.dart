import 'dart:async';

import '../../../core/constants/catalog_constants.dart';
import '../../entities/catalog.dart';
import '../../entities/preferences_status.dart';
import '../../entities/user.dart';
import '../../repositories/preferences_repository.dart';
import '../notifications/notification_usecases.dart';
import '../wallet/wallet_usecases.dart';

/// Lecturas síncronas de preferencias y favoritos. Sin sesión (`null`) se
/// lee la cuenta de invitado.
class PreferencesQueries {
  /// Recibe el repositorio.
  const PreferencesQueries(this._repo);
  final PreferencesRepository _repo;

  /// Estado de la cuenta (o del invitado).
  PreferencesStatus statusOf(String? userId) =>
      _repo.statusOf(userId ?? kGuestAccount);

  /// Preferencias de la cuenta.
  Preferences prefsOf(String? userId) => statusOf(userId).prefs;

  /// `true` si ya completó la encuesta.
  bool completedOf(String? userId) => statusOf(userId).completed;

  /// Platos favoritos.
  Set<String> favoriteDishes(String? userId) =>
      userId == null ? const {} : statusOf(userId).favoriteDishes;

  /// Sedes favoritas.
  Set<String> favoriteBranches(String? userId) =>
      userId == null ? const {} : statusOf(userId).favoriteBranches;

  /// `true` si el plato es favorito.
  bool isFavoriteDish(String? userId, String dishId) =>
      favoriteDishes(userId).contains(dishId);

  /// `true` si la sede es favorita.
  bool isFavoriteBranch(String? userId, String branchId) =>
      favoriteBranches(userId).contains(branchId);

  /// Medio de pago preferido (también el del invitado).
  PaymentMethod defaultPaymentOf(String? userId) =>
      statusOf(userId).defaultPayment;
}

/// Guarda las preferencias; la primera vez con sesión acredita 300 Gotas y
/// avisa al usuario.
class SavePreferences {
  /// Recibe el repositorio, la billetera y los avisos.
  const SavePreferences(this._repo, this._credit, this._push);
  final PreferencesRepository _repo;
  final CreditGotas _credit;
  final PushNotification _push;

  /// Devuelve las Gotas acreditadas en [PreferencesResult.awarded].
  PreferencesResult call(String? userId, Preferences prefs) {
    final account = userId ?? kGuestAccount;
    final current = _repo.statusOf(account);
    var next = current.copyWith(prefs: prefs, completed: true);
    var awarded = 0;
    if (userId != null && !current.rewarded) {
      next = next.copyWith(rewarded: true);
      awarded = kSurveyGotas;
    }
    _repo.replace(account, next);

    if (awarded > 0) {
      _credit(userId!, awarded, 'Completaste tus preferencias');
      _push(
        title: '+$kSurveyGotas Gotas 💧',
        body: 'Gracias por completar tus preferencias.',
        audience: 'user:$userId',
        route: '/recompensas',
      );
    }

    // Persistencia remota: preferencias + recompensa única de la encuesta.
    if (userId != null) {
      unawaited(
        _repo.persistPreferences(
          userId,
          prefs,
          completed: true,
          completeSurvey: awarded > 0,
        ),
      );
    }
    return PreferencesResult.ok(awarded: awarded);
  }
}

/// Agrega o quita un favorito; exige sesión.
class ToggleFavorite {
  /// Recibe el repositorio.
  const ToggleFavorite(this._repo);
  final PreferencesRepository _repo;

  /// La caché cambia antes del primer `await`; si el servidor falla se
  /// revierte y el resultado es `network`.
  Future<PreferencesResult> call(
    String? userId,
    FavoriteKind kind,
    String id,
  ) async {
    if (userId == null) return const PreferencesResult('not_logged_in');
    final on = !_repo.statusOf(userId).favoritesOf(kind).contains(id);
    return _repo.setFavorite(userId, kind, id, on);
  }
}

/// Al iniciar sesión, la cuenta hereda las preferencias del invitado si aún
/// no tiene las suyas.
class AdoptGuestPreferences {
  /// Recibe el repositorio.
  const AdoptGuestPreferences(this._repo);
  final PreferencesRepository _repo;

  /// Copia preferencias y encuesta completada del invitado a [userId].
  void call(String userId) {
    final mine = _repo.statusOf(userId);
    final guest = _repo.statusOf(kGuestAccount);
    if (mine.completed || !guest.completed) return;
    _repo.replace(userId, mine.copyWith(prefs: guest.prefs, completed: true));
  }
}

/// Cambia la universidad elegida en las preferencias (solo local).
class SetPreferredUniversity {
  /// Recibe el repositorio.
  const SetPreferredUniversity(this._repo);
  final PreferencesRepository _repo;

  /// Fija o quita ([universityId] `null`) la universidad de la cuenta.
  void call(String? userId, String? universityId) {
    final account = userId ?? kGuestAccount;
    final s = _repo.statusOf(account);
    if (s.prefs.universityId == universityId) return;
    _repo.replace(
      account,
      s.copyWith(
        prefs: universityId == null
            ? s.prefs.copyWith(clearUniversity: true)
            : s.prefs.copyWith(universityId: universityId),
      ),
    );
  }
}

/// Guarda el medio de pago preferido (solo local, como antes).
class SetDefaultPayment {
  /// Recibe el repositorio.
  const SetDefaultPayment(this._repo);
  final PreferencesRepository _repo;

  /// Fija [method] para la cuenta (o el invitado).
  void call(String? userId, PaymentMethod method) {
    final account = userId ?? kGuestAccount;
    _repo.replace(
      account,
      _repo.statusOf(account).copyWith(defaultPayment: method),
    );
  }
}

/// Trae preferencias y favoritos al iniciar sesión.
class LoadPreferences {
  /// Recibe el repositorio.
  const LoadPreferences(this._repo);
  final PreferencesRepository _repo;

  /// Carga los datos de [userId]; no hace nada en demo.
  Future<PreferencesResult> call(String userId) => _repo.load(userId);
}

/// Todos los casos de uso de preferencias y favoritos, ya cableados.
class PreferencesUseCases {
  /// Ensambla los casos de uso sobre el repositorio, la billetera y avisos.
  PreferencesUseCases({
    required this.repo,
    required CreditGotas credit,
    required PushNotification push,
  }) : queries = PreferencesQueries(repo),
       save = SavePreferences(repo, credit, push),
       toggleFavorite = ToggleFavorite(repo),
       adoptGuest = AdoptGuestPreferences(repo),
       setUniversity = SetPreferredUniversity(repo),
       setDefaultPayment = SetDefaultPayment(repo),
       load = LoadPreferences(repo);

  /// Repositorio (en memoria o Supabase).
  final PreferencesRepository repo;

  /// Lecturas.
  final PreferencesQueries queries;

  /// Guardar preferencias (con la recompensa de la encuesta).
  final SavePreferences save;

  /// Marcar o desmarcar favoritos.
  final ToggleFavorite toggleFavorite;

  /// Heredar las preferencias del invitado.
  final AdoptGuestPreferences adoptGuest;

  /// Cambiar la universidad elegida.
  final SetPreferredUniversity setUniversity;

  /// Cambiar el medio de pago preferido.
  final SetDefaultPayment setDefaultPayment;

  /// Cargar del servidor.
  final LoadPreferences load;
}
