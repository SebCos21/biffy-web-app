import '../address_errors.dart';
import '../entities/address.dart';

/// Resultado de una operación de direcciones, igual en demo y con servidor.
/// [code] es `ok`, `not_logged_in`, `not_found` o `network`.
class AddressResult {
  /// Crea el resultado con su código y la dirección afectada, si aplica.
  const AddressResult(this.code, {this.address});

  /// Operación exitosa.
  const AddressResult.ok([this.address]) : code = 'ok';

  /// Código de la operación.
  final String code;

  /// Dirección guardada (con su id definitivo), si aplica.
  final Address? address;

  /// `true` si la operación terminó bien.
  bool get ok => code == 'ok';

  /// Mensaje en español para mostrar; nunca expone el código crudo.
  String get message => addressErrorMessage(code);

  /// `true` si falló la conexión con el servidor.
  bool get isTransportError => isAddressTransportError(code);

  /// Representación corta para depurar.
  @override
  String toString() => 'AddressResult($code)';
}

/// Contrato de las direcciones de entrega por cuenta. Guarda una caché que se
/// lee de forma síncrona y avisa por [changes] cuando cambia. Las escrituras
/// cambian la caché antes del primer `await` y luego sincronizan.
abstract interface class AddressRepository {
  /// Direcciones de la cuenta (solo lectura).
  List<Address> addressesOf(String userId);

  /// Id de la dirección predeterminada, o `null`.
  String? defaultIdOf(String userId);

  /// Emite cada vez que cambia la caché.
  Stream<void> get changes;

  /// `true` si las direcciones se guardan en un servidor.
  bool get isRemote;

  /// Crea (si [Address.id] está vacío) o reemplaza una dirección. Queda como
  /// predeterminada si [makeDefault] o si la cuenta no tenía ninguna.
  Future<AddressResult> save(
    String userId,
    Address address, {
    required bool makeDefault,
  });

  /// Elimina la dirección y, si era la predeterminada, elige la primera.
  Future<AddressResult> delete(String userId, String id);

  /// Marca una dirección como predeterminada.
  Future<AddressResult> setDefault(String userId, String id);

  /// Trae las direcciones guardadas; si hay, reemplazan la caché, la primera
  /// queda como predeterminada y llega en [AddressResult.address] (no-op en
  /// demo). Nunca lanza.
  Future<AddressResult> load(String userId);

  /// Solo para datos de demostración: deja las direcciones de una cuenta.
  void insertSeed(String userId, List<Address> addresses, {String? defaultId});
}
