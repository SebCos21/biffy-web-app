import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/address.dart';
import '../../../domain/repositories/address_repository.dart';
import '../../../domain/usecases/addresses/address_usecases.dart';

/// Resultado de la última acción. [id] crece con cada resultado para que un
/// `BlocListener` reaccione una sola vez.
final class AddressesOutcome {
  /// Crea el resultado numerado.
  const AddressesOutcome(this.id, this.result);

  /// Número creciente del resultado.
  final int id;

  /// Resultado tipado con su mensaje en español.
  final AddressResult result;
}

/// Estado inmutable de las direcciones: [revision] sube con cada cambio del
/// repositorio para que las pantallas se vuelvan a pintar.
final class AddressesState {
  /// Crea el estado.
  const AddressesState({this.revision = 0, this.outcome});

  /// Contador de cambios.
  final int revision;

  /// Resultado de la última acción, si hubo.
  final AddressesOutcome? outcome;

  /// Copia el estado cambiando solo lo indicado.
  AddressesState copyWith({int? revision, AddressesOutcome? outcome}) =>
      AddressesState(
        revision: revision ?? this.revision,
        outcome: outcome ?? this.outcome,
      );
}

/// Cubit global de direcciones de entrega. Las pantallas leen con
/// [addressesOf] / [defaultOf] y escriben con [save], [delete] y
/// [setDefault]; las reglas viven en `domain/usecases/addresses`.
class AddressesCubit extends Cubit<AddressesState> {
  /// Escucha los cambios del repositorio.
  AddressesCubit(this.useCases) : super(const AddressesState()) {
    _changes = useCases.repo.changes.listen((_) => _bump());
  }

  /// Casos de uso de direcciones ya cableados.
  final AddressUseCases useCases;
  StreamSubscription<void>? _changes;
  int _outcomeSeq = 0;

  /// Direcciones de la cuenta.
  List<Address> addressesOf(String? userId) =>
      useCases.queries.addressesOf(userId);

  /// Dirección por id.
  Address? byId(String? userId, String? id) =>
      useCases.queries.byId(userId, id);

  /// Dirección predeterminada (o la primera).
  Address? defaultOf(String? userId) => useCases.queries.defaultOf(userId);

  /// Guarda una dirección nueva o editada.
  Future<AddressResult> save(
    String? userId,
    Address address, {
    bool makeDefault = false,
  }) async =>
      _publish(await useCases.save(userId, address, makeDefault: makeDefault));

  /// Elimina una dirección.
  Future<AddressResult> delete(String? userId, String id) async =>
      _publish(await useCases.delete(userId, id));

  /// Marca la dirección predeterminada.
  Future<AddressResult> setDefault(String? userId, String id) async =>
      _publish(await useCases.setDefault(userId, id));

  /// Publica el resultado de una acción.
  AddressResult _publish(AddressResult result) {
    if (!isClosed) {
      emit(
        state.copyWith(
          revision: state.revision + 1,
          outcome: AddressesOutcome(++_outcomeSeq, result),
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
