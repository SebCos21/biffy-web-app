import '../../entities/address.dart';
import '../../entities/catalog.dart';
import '../../repositories/address_repository.dart';

/// Lecturas síncronas de las direcciones. Sin sesión (`null`) todo es vacío.
class AddressQueries {
  /// Recibe el repositorio.
  const AddressQueries(this._repo);
  final AddressRepository _repo;

  /// Direcciones de la cuenta.
  List<Address> addressesOf(String? userId) =>
      userId == null ? const [] : _repo.addressesOf(userId);

  /// Dirección por id, o `null`.
  Address? byId(String? userId, String? id) {
    for (final a in addressesOf(userId)) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Dirección predeterminada (o la primera, si no hay marcada).
  Address? defaultOf(String? userId) {
    final list = addressesOf(userId);
    if (list.isEmpty) return null;
    return byId(userId, _repo.defaultIdOf(userId!)) ?? list.first;
  }

  /// `true` si la dirección [id] es la predeterminada.
  bool isDefault(String? userId, String id) => defaultOf(userId)?.id == id;
}

/// Guarda una dirección nueva o editada.
class SaveAddress {
  /// Recibe el repositorio.
  const SaveAddress(this._repo);
  final AddressRepository _repo;

  /// Exige sesión; la dirección guardada (con su id) llega en el resultado.
  Future<AddressResult> call(
    String? userId,
    Address address, {
    bool makeDefault = false,
  }) async {
    if (userId == null) return const AddressResult('not_logged_in');
    return _repo.save(userId, address, makeDefault: makeDefault);
  }
}

/// Elimina una dirección.
class DeleteAddress {
  /// Recibe el repositorio.
  const DeleteAddress(this._repo);
  final AddressRepository _repo;

  /// Exige sesión.
  Future<AddressResult> call(String? userId, String id) async {
    if (userId == null) return const AddressResult('not_logged_in');
    return _repo.delete(userId, id);
  }
}

/// Marca una dirección como predeterminada.
class SetDefaultAddress {
  /// Recibe el repositorio.
  const SetDefaultAddress(this._repo);
  final AddressRepository _repo;

  /// Exige sesión.
  Future<AddressResult> call(String? userId, String id) async {
    if (userId == null) return const AddressResult('not_logged_in');
    return _repo.setDefault(userId, id);
  }
}

/// Crea la dirección inicial de un comprador recién registrado en su punto
/// de entrega actual (modo demo).
class CreateInitialAddress {
  /// Recibe el repositorio.
  const CreateInitialAddress(this._repo);
  final AddressRepository _repo;

  /// Guarda «Punto de entrega» en [point] como predeterminada.
  Future<AddressResult> call(String userId, DeliveryPoint point) => _repo.save(
    userId,
    Address(
      id: '',
      label: 'Punto de entrega',
      line: point.name,
      details: point.detail,
      neighborhood: point.campusId == null ? 'Bogotá' : 'Campus',
      pointId: point.id,
    ),
    makeDefault: true,
  );
}

/// Trae las direcciones guardadas al iniciar sesión.
class LoadAddresses {
  /// Recibe el repositorio.
  const LoadAddresses(this._repo);
  final AddressRepository _repo;

  /// Carga las direcciones de [userId]; no hace nada en demo.
  Future<AddressResult> call(String userId) => _repo.load(userId);
}

/// Todos los casos de uso de direcciones, ya cableados.
class AddressUseCases {
  /// Ensambla los casos de uso sobre el repositorio.
  AddressUseCases({required this.repo})
    : queries = AddressQueries(repo),
      save = SaveAddress(repo),
      delete = DeleteAddress(repo),
      setDefault = SetDefaultAddress(repo),
      createInitial = CreateInitialAddress(repo),
      load = LoadAddresses(repo);

  /// Repositorio (en memoria o Supabase).
  final AddressRepository repo;

  /// Lecturas.
  final AddressQueries queries;

  /// Guardar una dirección.
  final SaveAddress save;

  /// Eliminar una dirección.
  final DeleteAddress delete;

  /// Marcar la predeterminada.
  final SetDefaultAddress setDefault;

  /// Dirección inicial al registrarse.
  final CreateInitialAddress createInitial;

  /// Cargar del servidor.
  final LoadAddresses load;
}
