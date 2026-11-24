import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/catalog_rules.dart';
import '../../../domain/entities/business.dart';
import '../../../domain/entities/catalog.dart';
import '../../../domain/repositories/catalog_repository.dart';
import '../../../domain/usecases/catalog/catalog_usecases.dart';

part 'catalog_event.dart';
part 'catalog_state.dart';

/// Bloc global del catálogo (comprador y comercio).
///
/// Traduce eventos en casos de uso y publica el resultado en
/// [CatalogState.outcome]. Escucha el repositorio (escrituras, Realtime y la
/// copia sin conexión) y el punto de entrega de la sesión. No tiene reglas: la
/// visibilidad pasa por `isReachable` en `domain/catalog_rules.dart`.
class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  /// Se suscribe al repositorio y al contexto de la sesión.
  CatalogBloc(this.useCases)
    : super(CatalogState(offline: useCases.queries.offline)) {
    on<CatalogChanged>(
      (e, emit) =>
          emit(state.copyWith(revision: state.revision + 1, offline: offline)),
    );
    on<CatalogRefreshRequested>(
      (e, emit) => _run(e, emit, useCases.refresh.call),
    );
    on<DishSaved>((e, emit) => _run(e, emit, () => useCases.saveDish(e.dish)));
    on<DishAvailabilityChanged>(
      (e, emit) =>
          _run(e, emit, () => useCases.setAvailability(e.dish, e.active)),
    );
    on<DishDeleted>(
      (e, emit) => _run(e, emit, () => useCases.deleteDish(e.dishId)),
    );
    on<DishSoldOutChanged>(
      (e, emit) => _run(e, emit, () => useCases.setSoldOut(e.dish, e.soldOut)),
    );
    on<BusinessPauseChanged>(
      (e, emit) => _run(
        e,
        emit,
        () => useCases.setBusinessPaused(e.businessId, e.paused),
      ),
    );
    on<NutritionInfoChanged>(
      (e, emit) => _run(
        e,
        emit,
        () async => useCases.setNutritionInfo(e.businessId, e.value),
      ),
    );
    on<BusinessRegistered>(
      (e, emit) => _run(
        e,
        emit,
        () async => useCases.registerBusiness(e.business, e.branches),
      ),
    );
    on<DishPhotoUploaded>(
      (e, emit) => _run(
        e,
        emit,
        () =>
            useCases.uploadDishPhoto(businessId: e.businessId, bytes: e.bytes),
      ),
    );

    _subs = [
      useCases.repo.changes.listen((_) => add(CatalogChanged())),
      useCases.context.changes.listen((_) => add(CatalogChanged())),
    ];
  }

  /// Casos de uso del catálogo ya cableados.
  final CatalogUseCases useCases;
  late final List<StreamSubscription<void>> _subs;
  int _outcomeSeq = 0;
  int _dishSeq = 0;

  /// Despacha [event] y espera su resultado (para navegar o avisar en el
  /// mismo toque, p. ej. guardar un producto).
  Future<CatalogResult> request(CatalogEvent event) {
    add(event);
    return event.result;
  }

  /// Ejecuta un caso de uso, publica su resultado y completa el evento. Una
  /// excepción se convierte en `network` en vez de llegar a la pantalla.
  Future<void> _run(
    CatalogEvent event,
    Emitter<CatalogState> emit,
    Future<CatalogResult> Function() operation,
  ) async {
    CatalogResult result;
    try {
      result = await operation();
    } on Object {
      result = CatalogResult('network', _actionOf(event));
    }
    emit(
      state.copyWith(
        revision: state.revision + 1,
        offline: offline,
        outcome: CatalogOutcome(++_outcomeSeq, result),
      ),
    );
    event._complete(result);
  }

  /// Acción de un evento, para el mensaje cuando algo lanza.
  static CatalogAction _actionOf(CatalogEvent e) => switch (e) {
    DishSaved() => CatalogAction.saveDish,
    DishAvailabilityChanged() => CatalogAction.availability,
    DishDeleted() => CatalogAction.deleteDish,
    DishSoldOutChanged() => CatalogAction.soldOut,
    BusinessPauseChanged() => CatalogAction.pauseBusiness,
    NutritionInfoChanged() => CatalogAction.nutrition,
    BusinessRegistered() => CatalogAction.registerBusiness,
    DishPhotoUploaded() => CatalogAction.uploadPhoto,
    CatalogRefreshRequested() || CatalogChanged() => CatalogAction.refresh,
  };

  // ------------------------------------------------------------- Lecturas
  // Atajos síncronos: leen la caché del repositorio (fuente de verdad) con las
  // reglas puras del dominio.

  CatalogQueries get _q => useCases.queries;

  /// Punto de entrega activo.
  DeliveryPoint get point => _q.point;

  /// Hora actual según el reloj de la app.
  DateTime get now => _q.now;

  /// `true` si se muestra la copia guardada por falta de red.
  bool get offline => _q.offline;

  /// `true` si hay sedes en memoria para mostrar.
  bool get hasCatalog => _q.hasCatalog;

  /// Sede por id.
  Restaurant? restaurantById(String id) => _q.restaurantById(id);

  /// Plato por id.
  Dish? dishById(String id) => _q.dishById(id);

  /// Negocio por id.
  Business? businessById(String id) => _q.businessById(id);

  /// Sede del caso demo de Qbano.
  Restaurant? get qbanoIcesi => _q.qbanoIcesi;

  /// `true` si la sede llega al punto de entrega actual.
  bool reachable(Restaurant r) => _q.reachable(r);

  /// `true` si la sede está abierta ahora.
  bool isOpen(Restaurant r) => _q.isOpen(r);

  /// Sedes alcanzables con menú, ordenadas por distancia.
  List<Restaurant> get reachableRestaurants => _q.reachableRestaurants;

  /// Platos activos de las sedes alcanzables.
  List<Dish> get reachableDishes => _q.reachableDishes;

  /// Platos populares alcanzables.
  List<Dish> get popularDishes => _q.popularDishes;

  /// Sedes alcanzables por calificación.
  List<Restaurant> get topRatedRestaurants => _q.topRatedRestaurants;

  /// Restaurantes alcanzables de una universidad.
  List<Restaurant> campusRestaurants(String universityId) =>
      _q.campusRestaurants(universityId);

  /// Platos publicados de una sede.
  List<Dish> menuOf(String restaurantId) => _q.menuOf(restaurantId);

  /// Minutos estimados de entrega.
  int etaFor(Restaurant r) => _q.etaFor(r);

  /// Distancia en km al punto actual.
  double distanceFor(Restaurant r) => _q.distanceFor(r);

  /// Contexto de filtros para búsqueda.
  FilterContext filterContext({
    Set<String> allergies = const {},
    String? universityId,
  }) => _q.filterContext(allergies: allergies, universityId: universityId);

  /// Sedes de un negocio.
  List<Restaurant> branchesOf(String businessId) => _q.branchesOf(businessId);

  /// Productos de un negocio.
  List<Dish> productsOf(String businessId) => _q.productsOf(businessId);

  /// `true` si todas las sedes del negocio están pausadas.
  bool isBusinessPaused(String businessId) => _q.isBusinessPaused(businessId);

  /// Genera un id temporal para un plato nuevo (la base asigna el uuid).
  String newDishId() => 'dish-new-${++_dishSeq}';

  /// Cancela las suscripciones.
  @override
  Future<void> close() {
    for (final s in _subs) {
      s.cancel();
    }
    return super.close();
  }
}
