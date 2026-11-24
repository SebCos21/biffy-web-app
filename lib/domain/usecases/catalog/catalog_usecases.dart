import 'dart:typed_data';

import '../../../core/utils/clock.dart';
import '../../catalog_rules.dart';
import '../../entities/business.dart';
import '../../entities/catalog.dart';
import '../../ports/catalog_ports.dart';
import '../../repositories/catalog_repository.dart';

/// Lecturas síncronas del catálogo según el punto de entrega actual. Toda la
/// visibilidad pasa por [isReachable] (fuente única de la regla de alcance).
class CatalogQueries {
  /// Recibe el repositorio, el contexto de sesión y el reloj.
  const CatalogQueries(this._repo, this._context, this._clock);
  final CatalogRepository _repo;
  final CatalogContextPort _context;
  final Clock _clock;

  /// Punto de entrega activo.
  DeliveryPoint get point => _context.point;

  /// Hora actual según el reloj de la app.
  DateTime get now => _clock.now();

  /// `true` si la última lectura remota falló (se muestra la copia guardada).
  bool get offline => _repo.offline;

  /// `true` si hay sedes en memoria para mostrar.
  bool get hasCatalog => _repo.restaurants.isNotEmpty;

  /// Sede por id.
  Restaurant? restaurantById(String id) => _repo.restaurantById(id);

  /// Plato por id.
  Dish? dishById(String id) => _repo.dishById(id);

  /// Negocio por id.
  Business? businessById(String id) => _repo.businessById(id);

  /// Sede del caso demo de Qbano: en memoria tiene id fijo; en Supabase es un
  /// uuid, así que se busca por nombre.
  Restaurant? get qbanoIcesi =>
      restaurantById('qbano-icesi') ??
      _repo.restaurants.where((r) => r.name == 'Qbano Icesi').firstOrNull;

  /// `true` si la sede llega al punto de entrega actual.
  bool reachable(Restaurant r) => isReachable(r, point);

  /// `true` si la sede está abierta ahora.
  bool isOpen(Restaurant r) => isOpenAt(r, now);

  /// `true` si la sede tiene al menos un plato publicado.
  bool _hasMenu(Restaurant r) =>
      _repo.dishes.any((d) => d.restaurantId == r.id && d.active);

  /// Sedes alcanzables con menú, ordenadas por distancia.
  List<Restaurant> get reachableRestaurants {
    final p = point;
    return _repo.restaurants
        .where((r) => isReachable(r, p) && _hasMenu(r))
        .toList()
      ..sort((a, b) => distanceTo(a, p).compareTo(distanceTo(b, p)));
  }

  /// Platos activos de las sedes alcanzables.
  List<Dish> get reachableDishes {
    final ids = reachableRestaurants.map((r) => r.id).toSet();
    return _repo.dishes
        .where((d) => d.active && ids.contains(d.restaurantId))
        .toList();
  }

  /// Platos populares alcanzables, mejor calificados primero.
  List<Dish> get popularDishes =>
      reachableDishes.where((d) => d.popular).toList()
        ..sort((a, b) => b.rating.compareTo(a.rating));

  /// Sedes alcanzables ordenadas por calificación.
  List<Restaurant> get topRatedRestaurants =>
      [...reachableRestaurants]..sort((a, b) => b.rating.compareTo(a.rating));

  /// Restaurantes de la universidad compatibles con la zona de entrega.
  List<Restaurant> campusRestaurants(String universityId) =>
      reachableRestaurants.where((r) => r.campusId == universityId).toList()
        ..sort((a, b) => b.rating.compareTo(a.rating));

  /// Platos publicados de una sede.
  List<Dish> menuOf(String restaurantId) => _repo.dishes
      .where((d) => d.restaurantId == restaurantId && d.active)
      .toList();

  /// Minutos estimados de entrega de una sede.
  int etaFor(Restaurant r) => etaMinutes(r, point);

  /// Distancia en km entre la sede y el punto actual.
  double distanceFor(Restaurant r) => distanceTo(r, point);

  /// Contexto de filtros para las pantallas de búsqueda.
  FilterContext filterContext({
    Set<String> allergies = const {},
    String? universityId,
  }) => FilterContext(
    restaurantOf: _repo.restaurantById,
    now: now,
    allergies: allergies,
    universityId: universityId,
  );

  /// Sedes de un negocio.
  List<Restaurant> branchesOf(String businessId) =>
      _repo.restaurants.where((r) => r.businessId == businessId).toList();

  /// Productos de todas las sedes de un negocio.
  List<Dish> productsOf(String businessId) {
    final ids = branchesOf(businessId).map((r) => r.id).toSet();
    return _repo.dishes.where((d) => ids.contains(d.restaurantId)).toList();
  }

  /// `true` si todas las sedes del negocio están pausadas.
  bool isBusinessPaused(String businessId) =>
      branchesOf(businessId).every((r) => r.paused);
}

/// Vuelve a leer el catálogo; si queda sin conexión lo informa (`network`).
class RefreshCatalog {
  /// Recibe el repositorio.
  const RefreshCatalog(this._repo);
  final CatalogRepository _repo;

  /// Recarga; nunca lanza (la copia guardada se conserva sin red).
  Future<CatalogResult> call() async {
    await _repo.refresh();
    return _repo.offline
        ? const CatalogResult('network', CatalogAction.refresh)
        : const CatalogResult.ok(CatalogAction.refresh);
  }
}

/// Crea o actualiza un plato en el catálogo compartido.
class SaveDish {
  /// Recibe el repositorio.
  const SaveDish(this._repo);
  final CatalogRepository _repo;

  /// Guarda el plato; `forbidden` si la base no deja editarlo.
  Future<CatalogResult> call(Dish dish) => _repo.upsertDish(dish);
}

/// Publica u oculta un plato; si la base no lo guarda, lo revierte.
class SetDishAvailability {
  /// Recibe el repositorio.
  const SetDishAvailability(this._repo);
  final CatalogRepository _repo;

  /// Cambia `active` al instante y lo guarda; con error vuelve al valor previo.
  Future<CatalogResult> call(Dish dish, bool active) async {
    dish.active = active;
    final saved = await _repo.upsertDish(dish);
    if (!saved.ok) dish.active = !active;
    return CatalogResult(
      saved.code,
      CatalogAction.availability,
      deniedAction: saved.deniedAction,
    );
  }
}

/// Elimina un plato (borrado lógico con servidor).
class DeleteDish {
  /// Recibe el repositorio.
  const DeleteDish(this._repo);
  final CatalogRepository _repo;

  /// Elimina el plato [id].
  Future<CatalogResult> call(String id) => _repo.deleteDish(id);
}

/// Marca o desmarca un plato como agotado.
class SetDishSoldOut {
  /// Recibe el repositorio.
  const SetDishSoldOut(this._repo);
  final CatalogRepository _repo;

  /// Lo persiste y, si salió bien, lo refleja en el plato.
  Future<CatalogResult> call(Dish dish, bool soldOut) async {
    final result = await _repo.setDishSoldOut(dish.id, soldOut);
    if (result.ok) dish.soldOut = soldOut;
    return result;
  }
}

/// Pausa o reanuda todas las sedes de un negocio.
class SetBusinessPaused {
  /// Recibe el repositorio y las lecturas (para hallar las sedes).
  const SetBusinessPaused(this._repo, this._queries);
  final CatalogRepository _repo;
  final CatalogQueries _queries;

  /// Pausa sede por sede; se detiene en el primer fallo y lo devuelve.
  Future<CatalogResult> call(String businessId, bool paused) async {
    for (final r in _queries.branchesOf(businessId)) {
      final result = await _repo.setBranchPaused(r.id, paused);
      if (!result.ok) return result;
      r.paused = paused;
    }
    return const CatalogResult.ok(CatalogAction.pauseBusiness);
  }
}

/// Muestra u oculta la información nutricional de un negocio (local).
class SetNutritionInfo {
  /// Recibe las lecturas (para hallar el negocio y sus sedes).
  const SetNutritionInfo(this._queries);
  final CatalogQueries _queries;

  /// Cambia la marca del negocio y de todas sus sedes.
  CatalogResult call(String businessId, bool value) {
    _queries.businessById(businessId)?.nutritionInfo = value;
    for (final r in _queries.branchesOf(businessId)) {
      r.showsNutrition = value;
    }
    return const CatalogResult.ok(CatalogAction.nutrition);
  }
}

/// Registra un negocio con sus sedes en el catálogo.
class RegisterBusiness {
  /// Recibe el repositorio.
  const RegisterBusiness(this._repo);
  final CatalogRepository _repo;

  /// Agrega el negocio y sus sedes.
  CatalogResult call(Business business, List<Restaurant> branches) =>
      _repo.addBusiness(business, branches);
}

/// Sube la foto de un plato (con servidor) y devuelve su URL en el resultado.
class UploadDishPhoto {
  /// Recibe el repositorio.
  const UploadDishPhoto(this._repo);
  final CatalogRepository _repo;

  /// Sube [bytes] a la carpeta del negocio.
  Future<CatalogResult> call({
    required String businessId,
    required Uint8List bytes,
  }) => _repo.uploadDishPhoto(businessId: businessId, bytes: bytes);
}

/// Suma unidades vendidas de un plato (control de porciones).
class RecordSale {
  /// Recibe el repositorio.
  const RecordSale(this._repo);
  final CatalogRepository _repo;

  /// Suma [qty] al plato [dishId].
  void call(String dishId, int qty) => _repo.recordSale(dishId, qty);
}

/// Guarda el promedio de reseñas de una sede (demo).
class SetRestaurantRating {
  /// Recibe el repositorio.
  const SetRestaurantRating(this._repo);
  final CatalogRepository _repo;

  /// Guarda [rating] en la sede [restaurantId].
  void call(String restaurantId, double rating) =>
      _repo.setBranchRating(restaurantId, rating);
}

/// Todos los casos de uso del catálogo, ya cableados. Lo recibe el
/// `CatalogBloc` y los adaptadores de pedidos y reseñas.
class CatalogUseCases {
  /// Ensambla los casos de uso sobre el repositorio, la sesión y el reloj.
  factory CatalogUseCases({
    required CatalogRepository repo,
    required CatalogContextPort context,
    required Clock clock,
  }) {
    final queries = CatalogQueries(repo, context, clock);
    return CatalogUseCases._(repo, context, queries);
  }

  CatalogUseCases._(this.repo, this.context, this.queries)
    : refresh = RefreshCatalog(repo),
      saveDish = SaveDish(repo),
      setAvailability = SetDishAvailability(repo),
      deleteDish = DeleteDish(repo),
      setSoldOut = SetDishSoldOut(repo),
      setBusinessPaused = SetBusinessPaused(repo, queries),
      setNutritionInfo = SetNutritionInfo(queries),
      registerBusiness = RegisterBusiness(repo),
      uploadDishPhoto = UploadDishPhoto(repo),
      recordSale = RecordSale(repo),
      setRestaurantRating = SetRestaurantRating(repo);

  /// Repositorio del catálogo (en memoria o Supabase).
  final CatalogRepository repo;

  /// Contexto de la sesión (punto de entrega).
  final CatalogContextPort context;

  /// Lecturas.
  final CatalogQueries queries;

  /// Recargar el catálogo.
  final RefreshCatalog refresh;

  /// Crear o editar un plato.
  final SaveDish saveDish;

  /// Publicar u ocultar un plato.
  final SetDishAvailability setAvailability;

  /// Eliminar un plato.
  final DeleteDish deleteDish;

  /// Marcar agotado.
  final SetDishSoldOut setSoldOut;

  /// Pausar o reanudar un negocio.
  final SetBusinessPaused setBusinessPaused;

  /// Mostrar u ocultar la información nutricional.
  final SetNutritionInfo setNutritionInfo;

  /// Registrar un negocio.
  final RegisterBusiness registerBusiness;

  /// Subir la foto de un plato.
  final UploadDishPhoto uploadDishPhoto;

  /// Sumar ventas.
  final RecordSale recordSale;

  /// Guardar el promedio de reseñas.
  final SetRestaurantRating setRestaurantRating;
}
