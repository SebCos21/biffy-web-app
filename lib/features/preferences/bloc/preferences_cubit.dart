import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/preferences_status.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/preferences_repository.dart';
import '../../../domain/usecases/preferences/preferences_usecases.dart';

/// Resultado de la última acción. [id] crece con cada resultado para que un
/// `BlocListener` reaccione una sola vez.
final class PreferencesOutcome {
  /// Crea el resultado numerado.
  const PreferencesOutcome(this.id, this.result);

  /// Número creciente del resultado.
  final int id;

  /// Resultado tipado con su mensaje en español.
  final PreferencesResult result;
}

/// Estado inmutable de preferencias y favoritos: [revision] sube con cada
/// cambio del repositorio para que las pantallas se vuelvan a pintar.
final class PreferencesState {
  /// Crea el estado.
  const PreferencesState({this.revision = 0, this.outcome});

  /// Contador de cambios.
  final int revision;

  /// Resultado de la última acción, si hubo.
  final PreferencesOutcome? outcome;

  /// Copia el estado cambiando solo lo indicado.
  PreferencesState copyWith({int? revision, PreferencesOutcome? outcome}) =>
      PreferencesState(
        revision: revision ?? this.revision,
        outcome: outcome ?? this.outcome,
      );
}

/// Cubit global de preferencias y favoritos. Las pantallas leen con
/// [prefsOf] / [isFavoriteDish] y escriben con [save] / [toggleFavorite].
///
/// Es un Cubit porque las pantallas necesitan el resultado en el mismo toque
/// (Gotas ganadas, aviso de favorito); las reglas viven en los casos de uso.
class PreferencesCubit extends Cubit<PreferencesState> {
  /// Escucha los cambios del repositorio.
  PreferencesCubit(this.useCases) : super(const PreferencesState()) {
    _changes = useCases.repo.changes.listen((_) => _bump());
  }

  /// Casos de uso de preferencias ya cableados.
  final PreferencesUseCases useCases;
  StreamSubscription<void>? _changes;
  int _outcomeSeq = 0;

  /// Preferencias de la cuenta (o del invitado si es `null`).
  Preferences prefsOf(String? userId) => useCases.queries.prefsOf(userId);

  /// `true` si la cuenta ya completó la encuesta.
  bool completedOf(String? userId) => useCases.queries.completedOf(userId);

  /// Platos favoritos de la cuenta.
  Set<String> favoriteDishes(String? userId) =>
      useCases.queries.favoriteDishes(userId);

  /// Sedes favoritas de la cuenta.
  Set<String> favoriteBranches(String? userId) =>
      useCases.queries.favoriteBranches(userId);

  /// `true` si el plato es favorito.
  bool isFavoriteDish(String? userId, String dishId) =>
      useCases.queries.isFavoriteDish(userId, dishId);

  /// `true` si la sede es favorita.
  bool isFavoriteBranch(String? userId, String branchId) =>
      useCases.queries.isFavoriteBranch(userId, branchId);

  /// Guarda las preferencias; el resultado trae las Gotas acreditadas.
  PreferencesResult save(String? userId, Preferences prefs) =>
      _publish(useCases.save(userId, prefs));

  /// Marca o desmarca un favorito. La caché cambia al instante; si el
  /// servidor falla se revierte (sin favoritos "fantasma").
  Future<PreferencesResult> toggleFavorite(
    String? userId,
    FavoriteKind kind,
    String id,
  ) async => _publish(await useCases.toggleFavorite(userId, kind, id));

  /// Publica el resultado de una acción.
  PreferencesResult _publish(PreferencesResult result) {
    if (!isClosed) {
      emit(
        state.copyWith(
          revision: state.revision + 1,
          outcome: PreferencesOutcome(++_outcomeSeq, result),
        ),
      );
    }
    return result;
  }

  /// Sube la revisión cuando cambia el repositorio.
  void _bump() {
    if (!isClosed) emit(state.copyWith(revision: state.revision + 1));
  }

  /// Cancela la escucha del repositorio.
  @override
  Future<void> close() {
    _changes?.cancel();
    return super.close();
  }
}
