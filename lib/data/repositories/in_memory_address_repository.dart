import '../../domain/entities/address.dart';
import '../../domain/repositories/address_repository.dart';
import 'address_cache.dart';

/// Direcciones del modo demo y de las pruebas: solo en memoria, sin red.
class InMemoryAddressRepository implements AddressRepository {
  final AddressCache _cache = AddressCache();

  /// Direcciones de la cuenta.
  @override
  List<Address> addressesOf(String userId) => _cache.addressesOf(userId);

  /// Id de la predeterminada.
  @override
  String? defaultIdOf(String userId) => _cache.defaultIdOf(userId);

  /// Emite cuando cambia la caché.
  @override
  Stream<void> get changes => _cache.changes;

  /// En demo no hay servidor.
  @override
  bool get isRemote => false;

  /// Guarda la dirección en memoria.
  @override
  Future<AddressResult> save(
    String userId,
    Address address, {
    required bool makeDefault,
  }) async =>
      AddressResult.ok(_cache.save(userId, address, makeDefault: makeDefault));

  /// Elimina la dirección en memoria.
  @override
  Future<AddressResult> delete(String userId, String id) async {
    final removed = _cache.delete(userId, id);
    return removed == null
        ? const AddressResult('not_found')
        : AddressResult.ok(removed);
  }

  /// Marca la predeterminada en memoria.
  @override
  Future<AddressResult> setDefault(String userId, String id) async {
    _cache.setDefault(userId, id);
    return AddressResult.ok(_cache.byId(userId, id));
  }

  /// En demo no hay direcciones remotas que cargar.
  @override
  Future<AddressResult> load(String userId) async => const AddressResult.ok();

  /// Deja las direcciones de demostración.
  @override
  void insertSeed(
    String userId,
    List<Address> addresses, {
    String? defaultId,
  }) => _cache.replaceAll(userId, addresses, defaultId: defaultId);

  /// Cierra el stream de cambios.
  void dispose() => _cache.dispose();
}
