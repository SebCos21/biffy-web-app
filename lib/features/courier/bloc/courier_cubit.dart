import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/courier.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/courier_repository.dart';
import '../../../domain/usecases/courier/courier_usecases.dart';

/// Acciones del repartidor que terminan con un [CourierOutcome].
enum CourierAction { register, availability, zone }

/// Resultado de la última acción. [id] crece con cada resultado para que un
/// `BlocListener` reaccione una sola vez.
final class CourierOutcome {
  /// Crea el resultado numerado de una acción.
  const CourierOutcome(this.id, this.action, this.result);

  /// Número creciente del resultado.
  final int id;

  /// Acción que lo produjo.
  final CourierAction action;

  /// Resultado tipado con su mensaje en español.
  final CourierResult result;
}

/// Estado inmutable del módulo repartidor: [revision] sube con cada cambio
/// del repositorio para que las pantallas se vuelvan a pintar.
final class CourierState {
  /// Crea el estado.
  const CourierState({this.revision = 0, this.outcome});

  /// Contador de cambios.
  final int revision;

  /// Resultado de la última acción, si hubo.
  final CourierOutcome? outcome;

  /// Copia el estado cambiando solo lo indicado.
  CourierState copyWith({int? revision, CourierOutcome? outcome}) =>
      CourierState(
        revision: revision ?? this.revision,
        outcome: outcome ?? this.outcome,
      );
}

/// Cubit global del repartidor: registro, disponibilidad y zona.
///
/// Es un Cubit porque las pantallas necesitan el resultado en el mismo toque
/// (aviso si el modo Campus no está permitido, navegar tras registrarse).
/// No tiene reglas: las aplican los casos de uso de `domain/usecases/courier`.
class CourierCubit extends Cubit<CourierState> {
  /// Escucha los cambios del repositorio.
  CourierCubit(this.useCases) : super(const CourierState()) {
    _changes = useCases.repo.changes.listen((_) => _bump());
  }

  /// Casos de uso del repartidor ya cableados.
  final CourierUseCases useCases;
  StreamSubscription<void>? _changes;
  int _outcomeSeq = 0;
  bool _registering = false;

  /// Estado del repartidor de la cuenta (lectura síncrona de la caché).
  CourierStatus statusOf(String userId) => useCases.queries.statusOf(userId);

  /// Registra el perfil; un segundo toque mientras guarda se ignora.
  Future<CourierResult> register(CourierProfile profile) async {
    if (_registering) return const CourierResult('in_progress');
    _registering = true;
    CourierResult result;
    try {
      result = await useCases.register(profile);
    } on Object {
      result = const CourierResult('save_failed');
    } finally {
      _registering = false;
    }
    _publish(CourierAction.register, result);
    return result;
  }

  /// Conecta o desconecta al repartidor.
  CourierResult setOnline(bool online) =>
      _publish(CourierAction.availability, useCases.setAvailability(online));

  /// Cambia la zona; devuelve el motivo si el modo Campus no está permitido.
  CourierResult setZone(CourierZone zone) =>
      _publish(CourierAction.zone, useCases.setZone(zone));

  /// Publica el resultado de una acción.
  CourierResult _publish(CourierAction action, CourierResult result) {
    if (!isClosed) {
      emit(
        state.copyWith(
          revision: state.revision + 1,
          outcome: CourierOutcome(++_outcomeSeq, action, result),
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
