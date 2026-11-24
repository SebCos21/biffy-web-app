import 'dart:async';
import 'dart:typed_data';

import '../catalog_errors.dart';
import '../entities/business.dart';
import '../entities/catalog.dart';

export '../catalog_errors.dart' show CatalogAction;

/// Error de una escritura del catálogo que la base rechazó (RLS dejó 0 filas).
///
/// Lo lanza internamente el repositorio de Supabase; hacia afuera se entrega
/// como un [CatalogResult] con código `forbidden`.
class CatalogWriteDenied implements Exception {
  /// Crea el error con la acción que se intentó.
  const CatalogWriteDenied(this.action);

  /// Acción que no se pudo hacer (p. ej. «editar el plato»).
  final String action;

  /// Mensaje legible del error.
  @override
  String toString() => 'Sin permiso para $action';
}

/// Resultado de una operación del catálogo, igual en demo y con servidor.
///
/// [code] es `ok`, `forbidden` (RLS no dejó escribir), `not_found` o
/// `network`; [message] es el texto en español para mostrar.
class CatalogResult {
  /// Crea el resultado de [action] con su código.
  const CatalogResult(this.code, this.action, {this.deniedAction, this.url});

  /// Operación exitosa (con la URL subida, si aplica).
  const CatalogResult.ok(this.action, {this.url})
    : code = 'ok',
      deniedAction = null;

  /// Escritura rechazada por la base (RLS).
  CatalogResult.denied(this.action, CatalogWriteDenied e)
    : code = 'forbidden',
      deniedAction = e.action,
      url = null;

  /// Código de la operación.
  final String code;

  /// Operación que se intentó.
  final CatalogAction action;

  /// Acción concreta que RLS rechazó (solo con `forbidden`).
  final String? deniedAction;

  /// URL pública de la foto subida (solo [CatalogAction.uploadPhoto]).
  final String? url;

  /// `true` si la operación terminó bien.
  bool get ok => code == 'ok';

  /// Mensaje en español para mostrar; nunca expone el código crudo.
  String get message =>
      catalogErrorMessage(code, action, deniedAction: deniedAction);

  /// `true` si falló la conexión con el servidor.
  bool get isTransportError => isCatalogTransportError(code);

  /// Representación corta para depurar.
  @override
  String toString() => 'CatalogResult(${action.name}: $code)';
}

/// Estado de sincronización de un catálogo remoto.
abstract interface class CatalogSyncStatus {
  /// `true` si la última lectura falló y se muestra la copia guardada.
  bool get offline;

  /// Momento de la última lectura correcta, o `null` si no hubo ninguna.
  DateTime? get lastSync;
}

/// Contrato del catálogo. Las pantallas lo leen de forma síncrona (caché) y
/// [changes] avisa cuando cambia. Las escrituras devuelven [CatalogResult].
///
/// La demo en memoria nunca está "sin conexión" ([offline] es `false`).
abstract interface class CatalogRepository implements CatalogSyncStatus {
  /// Negocios con sus datos legales y de contacto.
  List<Business> get businesses;

  /// Sedes visibles en el catálogo.
  List<Restaurant> get restaurants;

  /// Platos del catálogo.
  List<Dish> get dishes;

  /// Negocio por id, o `null` si no existe.
  Business? businessById(String id);

  /// Sede por id, o `null` si no existe.
  Restaurant? restaurantById(String id);

  /// Plato por id, o `null` si no existe.
  Dish? dishById(String id);

  /// Emite cuando cambia la caché (escrituras locales o Realtime).
  Stream<void> get changes;

  /// Vuelve a leer el catálogo del backend. Nunca lanza; en demo no hace nada.
  Future<void> refresh();

  /// Agrega un negocio con sus sedes a la caché.
  CatalogResult addBusiness(Business business, List<Restaurant> branches);

  /// Crea o actualiza un plato (remoto cuando hay backend).
  Future<CatalogResult> upsertDish(Dish dish);

  /// Elimina un plato del catálogo (borrado lógico con backend).
  Future<CatalogResult> deleteDish(String id);

  /// Suma unidades vendidas para controlar las porciones (solo caché).
  void recordSale(String dishId, int qty);

  /// Marca o desmarca un plato como agotado.
  Future<CatalogResult> setDishSoldOut(String dishId, bool soldOut);

  /// Pausa o reanuda una sede.
  Future<CatalogResult> setBranchPaused(String branchId, bool paused);

  /// Actualiza el promedio de reseñas de una sede en la caché (demo; con
  /// Supabase llega por Realtime desde `branches.rating`).
  void setBranchRating(String branchId, double rating);

  /// Sube la foto de un plato; con éxito trae la URL pública en
  /// [CatalogResult.url] (en demo no hay Storage y devuelve `network`).
  Future<CatalogResult> uploadDishPhoto({
    required String businessId,
    required Uint8List bytes,
  });
}
