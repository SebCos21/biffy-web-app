import 'dart:async';
import 'dart:typed_data';

import '../../domain/entities/business.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../mock/seed_catalog.dart';

/// Catálogo de demostración guardado en memoria. Nunca está sin conexión y
/// avisa por [changes] después de cada escritura.
class InMemoryCatalogRepository implements CatalogRepository {
  /// Crea el catálogo con los datos semilla por defecto.
  InMemoryCatalogRepository({
    List<Business>? businesses,
    List<Restaurant>? restaurants,
    List<Dish>? dishes,
  }) : _businesses = businesses ?? seedBusinesses(),
       _restaurants = restaurants ?? seedRestaurants(),
       _dishes = dishes ?? seedDishes();

  final List<Business> _businesses;
  final List<Restaurant> _restaurants;
  final List<Dish> _dishes;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Emite después de cada escritura en memoria.
  @override
  Stream<void> get changes => _changes.stream;

  /// La demo nunca está sin conexión.
  @override
  bool get offline => false;

  /// La demo no tiene lecturas remotas.
  @override
  DateTime? get lastSync => null;

  /// En demo no hay nada que volver a leer.
  @override
  Future<void> refresh() async {}

  /// Negocios registrados (solo lectura).
  @override
  List<Business> get businesses => List.unmodifiable(_businesses);

  /// Sedes registradas (solo lectura).
  @override
  List<Restaurant> get restaurants => List.unmodifiable(_restaurants);

  /// Platos registrados (solo lectura).
  @override
  List<Dish> get dishes => List.unmodifiable(_dishes);

  /// Negocio por id dentro del catálogo.
  @override
  Business? businessById(String id) {
    for (final b in _businesses) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Sede por id dentro del catálogo.
  @override
  Restaurant? restaurantById(String id) {
    for (final r in _restaurants) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Plato por id dentro del catálogo.
  @override
  Dish? dishById(String id) {
    for (final d in _dishes) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Registra un negocio y sus sedes.
  @override
  CatalogResult addBusiness(Business business, List<Restaurant> branches) {
    _businesses.add(business);
    _restaurants.addAll(branches);
    _emit();
    return const CatalogResult.ok(CatalogAction.registerBusiness);
  }

  /// Inserta o reemplaza un plato.
  @override
  Future<CatalogResult> upsertDish(Dish dish) async {
    final i = _dishes.indexWhere((d) => d.id == dish.id);
    if (i >= 0) {
      _dishes[i] = dish;
    } else {
      _dishes.insert(0, dish);
    }
    _emit();
    return const CatalogResult.ok(CatalogAction.saveDish);
  }

  /// Quita un plato del catálogo.
  @override
  Future<CatalogResult> deleteDish(String id) async {
    _dishes.removeWhere((d) => d.id == id);
    _emit();
    return const CatalogResult.ok(CatalogAction.deleteDish);
  }

  /// Suma las unidades vendidas de un plato.
  @override
  void recordSale(String dishId, int qty) {
    final d = dishById(dishId);
    if (d == null) return;
    d.soldToday += qty;
    _emit();
  }

  /// Marca el plato como agotado (solo en memoria).
  @override
  Future<CatalogResult> setDishSoldOut(String dishId, bool soldOut) async {
    final d = dishById(dishId);
    if (d != null) d.soldOut = soldOut;
    _emit();
    return const CatalogResult.ok(CatalogAction.soldOut);
  }

  /// Pausa la sede (solo en memoria).
  @override
  Future<CatalogResult> setBranchPaused(String branchId, bool paused) async {
    final r = restaurantById(branchId);
    if (r != null) r.paused = paused;
    _emit();
    return const CatalogResult.ok(CatalogAction.pauseBusiness);
  }

  /// Guarda el promedio de reseñas de la sede.
  @override
  void setBranchRating(String branchId, double rating) {
    final r = restaurantById(branchId);
    if (r == null || r.rating == rating) return;
    r.rating = rating;
    _emit();
  }

  /// En demo no hay Storage: la foto no se sube.
  @override
  Future<CatalogResult> uploadDishPhoto({
    required String businessId,
    required Uint8List bytes,
  }) async => const CatalogResult('network', CatalogAction.uploadPhoto);

  /// Avisa a los oyentes si el stream sigue abierto.
  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Cierra el stream de cambios.
  void dispose() => _changes.close();
}
