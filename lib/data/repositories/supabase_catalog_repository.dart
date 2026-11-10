import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/business.dart';
import '../models/catalog.dart';
import 'catalog_repository.dart';
import 'catalog_snapshot.dart';

/// Fuente de filas del catálogo (la red en producción, un doble en pruebas).
typedef CatalogRowsSource = Future<CatalogRows> Function();

/// Catálogo real: hidrata una caché en memoria al arrancar, la refresca con
/// Realtime y guarda una copia en disco para abrir el menú sin conexión. Así
/// las pantallas siguen leyendo de forma síncrona.
class SupabaseCatalogRepository
    implements CatalogRepository, CatalogSyncStatus {
  /// Constructor privado: usar [load] o [SupabaseCatalogRepository.forTest].
  SupabaseCatalogRepository._(this._client, this._cache, this._source);

  /// Carga la caché, se suscribe a Realtime y devuelve el repositorio.
  static Future<SupabaseCatalogRepository> load({
    sb.SupabaseClient? client,
    CatalogCache? cache,
  }) async {
    final repo = SupabaseCatalogRepository._(
      client ?? sb.Supabase.instance.client,
      cache ?? SharedPrefsCatalogCache(),
      null,
    );
    await repo.refresh();
    repo._subscribe();
    return repo;
  }

  /// Repositorio sin cliente ni Realtime que lee de [source] (para pruebas).
  @visibleForTesting
  factory SupabaseCatalogRepository.forTest({
    required CatalogRowsSource source,
    CatalogCache? cache,
  }) =>
      SupabaseCatalogRepository._(null, cache ?? MemoryCatalogCache(), source);

  final sb.SupabaseClient? _client;
  final CatalogCache _cache;
  final CatalogRowsSource? _source;
  final _changes = StreamController<void>.broadcast();

  final List<Business> _businesses = [];
  final List<Restaurant> _restaurants = [];
  final List<Dish> _dishes = [];

  bool _offline = false;
  DateTime? _lastSync;
  bool _triedDiskCopy = false;

  sb.RealtimeChannel? _channel;
  StreamSubscription<sb.AuthState>? _authSub;
  Timer? _reloadTimer;

  /// Espera para agrupar varios eventos de Realtime en una sola recarga.
  static const _debounce = Duration(milliseconds: 300);

  /// Cliente de Supabase; solo falta en el repositorio de pruebas.
  sb.SupabaseClient get _db =>
      _client ?? (throw StateError('Repositorio de pruebas sin Supabase'));

  /// Emite cuando Realtime trae cambios.
  @override
  Stream<void> get changes => _changes.stream;

  /// `true` si la última lectura falló y se muestra la copia guardada.
  @override
  bool get offline => _offline;

  /// Momento de la última lectura correcta del backend.
  @override
  DateTime? get lastSync => _lastSync;

  // ------------------------------------------------------------- Lectura

  /// Negocios en caché (solo lectura).
  @override
  List<Business> get businesses => List.unmodifiable(_businesses);

  /// Sedes en caché (solo lectura).
  @override
  List<Restaurant> get restaurants => List.unmodifiable(_restaurants);

  /// Platos en caché (solo lectura).
  @override
  List<Dish> get dishes => List.unmodifiable(_dishes);

  /// Negocio por id dentro de la caché.
  @override
  Business? businessById(String id) {
    for (final b in _businesses) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Sede por id dentro de la caché.
  @override
  Restaurant? restaurantById(String id) {
    for (final r in _restaurants) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Plato por id dentro de la caché.
  @override
  Dish? dishById(String id) {
    for (final d in _dishes) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Vuelve a leer el catálogo completo. Nunca lanza: si falla la red se
  /// conserva lo que ya estaba en memoria y, si no había nada, se intenta
  /// (una sola vez) la copia guardada en disco.
  @override
  Future<void> refresh() async {
    final CatalogRows rows;
    try {
      rows = await (_source ?? _fetchRows)();
      _apply(rows);
    } on Object {
      _offline = true;
      if (!_triedDiskCopy && _restaurants.isEmpty && _dishes.isEmpty) {
        _triedDiskCopy = true;
        await _loadCopy();
      }
      return;
    }
    _offline = false;
    _lastSync = DateTime.now();
    await _saveCopy(rows);
  }

  /// Lee en paralelo las tablas del catálogo. `businesses` es opcional: RLS
  /// solo deja ver la del dueño y el anónimo puede no tener permiso.
  Future<CatalogRows> _fetchRows() async {
    final db = _db;
    final results = await Future.wait<List<Map<String, dynamic>>>([
      db.from('businesses_public').select(),
      _optional(db.from('businesses').select()),
      db.from('branches').select(),
      db.from('dishes').select(),
      db.from('dish_options').select(),
    ]);
    return CatalogRows(
      publicBusinesses: results[0],
      ownBusinesses: results[1],
      branches: results[2],
      dishes: results[3],
      options: results[4],
    );
  }

  /// Devuelve las filas de [query] o una lista vacía si PostgREST la rechaza.
  static Future<List<Map<String, dynamic>>> _optional(
    Future<List<Map<String, dynamic>>> query,
  ) async {
    try {
      return await query;
    } on sb.PostgrestException {
      return const [];
    }
  }

  /// Reemplaza la caché en memoria. Descarta sedes y platos con borrado
  /// lógico (el dueño sí los recibe por RLS) y las opciones de esos platos.
  void _apply(CatalogRows rows) {
    final deletedBranches = <Object?>{
      for (final row in rows.branches)
        if (row['deleted_at'] != null) row['id'],
    };
    final dishRows = [
      for (final row in rows.dishes)
        if (row['deleted_at'] == null &&
            !deletedBranches.contains(row['branch_id']))
          row,
    ];
    final liveDishes = {for (final row in dishRows) row['id']};

    final optionsByDish = <String, Map<String, List<DishOption>>>{};
    for (final row in rows.options) {
      final dishId = row['dish_id'] as String?;
      final kind = row['kind'] as String?;
      if (dishId == null || kind == null || !liveDishes.contains(dishId)) {
        continue;
      }
      final option = DishOption(
        row['id'] as String,
        (row['label'] as String?) ?? '',
        ((row['price_delta'] as num?) ?? 0).toInt(),
      );
      optionsByDish
          .putIfAbsent(dishId, () => {'size': [], 'side': [], 'extra': []})
          .putIfAbsent(kind, () => <DishOption>[])
          .add(option);
    }

    // Se mapea todo antes de tocar la caché: una fila dañada no la deja a medias.
    final businesses = rows.businesses.map(_business).toList();
    final restaurants = [
      for (final row in rows.branches)
        if (row['deleted_at'] == null) _restaurant(row),
    ];
    final dishes = [for (final row in dishRows) _dish(row, optionsByDish)];

    _businesses
      ..clear()
      ..addAll(businesses);
    _restaurants
      ..clear()
      ..addAll(restaurants);
    _dishes
      ..clear()
      ..addAll(dishes);
  }

  /// Guarda la copia en disco (mejor esfuerzo: un fallo no afecta a la app).
  Future<void> _saveCopy(CatalogRows rows) async {
    try {
      await _cache.write(encodeCatalogRows(rows));
    } on Object {
      // Sin disco disponible: la próxima lectura correcta lo vuelve a intentar.
    }
  }

  /// Carga la copia del disco si existe y es válida.
  Future<void> _loadCopy() async {
    try {
      final rows = decodeCatalogRows(await _cache.read());
      if (rows != null && !rows.isEmpty) _apply(rows);
    } on Object {
      // Copia ilegible: se queda vacío y la pantalla avisa.
    }
  }

  // ------------------------------------------------------------ Realtime

  /// Abre el canal de Realtime y escucha los cambios de sesión.
  void _subscribe() {
    final db = _db;
    try {
      var channel = db.channel('biffy-catalog');
      for (final table in const [
        'dishes',
        'branches',
        'dish_options',
        'catalog_revision',
      ]) {
        channel = channel.onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (_) => _scheduleReload(),
        );
      }
      _channel = channel.subscribe((status, _) {
        // Al reconectar después de un fallo de red se pone al día.
        if (status == sb.RealtimeSubscribeStatus.subscribed && _offline) {
          _scheduleReload();
        }
      });
    } on Object {
      // Realtime es opcional: si no está habilitado seguimos con la caché.
    }

    // El catálogo se hidrata antes del login; al cambiar la sesión se recarga
    // con el JWT nuevo (p. ej. el comerciante pasa a ver su negocio por RLS).
    _authSub = db.auth.onAuthStateChange.listen((_) => _reload());
  }

  /// Agrupa los eventos de Realtime que llegan seguidos en una sola recarga.
  void _scheduleReload() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(_debounce, _reload);
  }

  /// Recarga la caché y avisa a los oyentes.
  Future<void> _reload() async {
    await refresh();
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Libera el canal de Realtime y el stream de cambios.
  Future<void> dispose() async {
    _reloadTimer?.cancel();
    await _authSub?.cancel();
    final channel = _channel;
    if (channel != null) {
      await _db.removeChannel(channel);
      _channel = null;
    }
    await _changes.close();
  }

  // ------------------------------------------------------------ Escrituras

  /// Agrega un negocio y sus sedes solo en la caché.
  @override
  void addBusiness(Business business, List<Restaurant> branches) {
    _businesses.add(business);
    _restaurants.addAll(branches);
  }

  /// Crea o actualiza el plato en la base y refresca la caché. Lanza
  /// [CatalogWriteDenied] si RLS no deja editarlo.
  @override
  Future<void> upsertDish(Dish dish) async {
    final row = <String, dynamic>{
      'branch_id': dish.restaurantId,
      'name': dish.name,
      'description': dish.description,
      'price': dish.price,
      'emoji': dish.emoji,
      'category_id': dish.category,
      'section': dish.section,
      'prep_min': dish.prepMin,
      'rating': dish.rating,
      'ingredients': dish.ingredients,
      'allergens': dish.allergens,
      'tags': dish.tags,
      'nutrition': dish.nutrition == null
          ? null
          : {
              'kcal': dish.nutrition!.kcal,
              'protein': dish.nutrition!.protein,
              'carbs': dish.nutrition!.carbs,
              'fat': dish.nutrition!.fat,
            },
      'popular': dish.popular,
      'featured': dish.featured,
      'active': dish.active,
      'sold_out': dish.soldOut,
      'portion_limit': dish.portionLimit,
      'sold_today': dish.soldToday,
      'image_url': dish.imageAsset,
    };

    // Los ids `dish-new-*` son temporales: la base asigna el uuid.
    String dishId;
    if (dish.id.startsWith('dish-new-')) {
      final inserted = await _db
          .from('dishes')
          .insert(row)
          .select('id')
          .single();
      dishId = inserted['id'] as String;
    } else {
      final updated = await _db
          .from('dishes')
          .update(row)
          .eq('id', dish.id)
          .select('id');
      if (updated.isEmpty) throw const CatalogWriteDenied('editar el plato');
      dishId = dish.id;
    }

    await _syncOptions(dishId, dish);

    await refresh();
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Reemplaza los tamaños, acompañantes y extras del plato en `dish_options`.
  Future<void> _syncOptions(String dishId, Dish dish) async {
    await _db.from('dish_options').delete().eq('dish_id', dishId);

    final options = <Map<String, dynamic>>[
      for (var i = 0; i < dish.sizes.length; i++)
        {
          'dish_id': dishId,
          'kind': 'size',
          'label': dish.sizes[i].label,
          'price_delta': dish.sizes[i].price,
          'sort': i,
        },
      for (var i = 0; i < dish.sides.length; i++)
        {
          'dish_id': dishId,
          'kind': 'side',
          'label': dish.sides[i].label,
          'price_delta': dish.sides[i].price,
          'sort': i,
        },
      for (var i = 0; i < dish.extras.length; i++)
        {
          'dish_id': dishId,
          'kind': 'extra',
          'label': dish.extras[i].label,
          'price_delta': dish.extras[i].price,
          'sort': i,
        },
    ];

    if (options.isNotEmpty) {
      await _db.from('dish_options').insert(options);
    }
  }

  /// Borrado lógico del plato (marca `deleted_at`): conserva el historial de
  /// pedidos. Lanza [CatalogWriteDenied] si RLS no deja borrarlo.
  @override
  Future<void> deleteDish(String id) async {
    final updated = await _db
        .from('dishes')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select('id');
    if (updated.isEmpty) throw const CatalogWriteDenied('eliminar el plato');
    await refresh();
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Suma las unidades vendidas de un plato.
  @override
  void recordSale(String dishId, int qty) {
    final dish = dishById(dishId);
    if (dish != null) dish.soldToday += qty;
  }

  /// Persiste el estado de agotado y refresca la caché. Lanza
  /// [CatalogWriteDenied] si RLS no deja cambiarlo.
  @override
  Future<void> setDishSoldOut(String dishId, bool soldOut) async {
    final updated = await _db
        .from('dishes')
        .update({'sold_out': soldOut})
        .eq('id', dishId)
        .select('id');
    if (updated.isEmpty) {
      throw const CatalogWriteDenied('cambiar el estado de agotado');
    }
    await refresh();
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Persiste la pausa de una sede y refresca la caché. Lanza
  /// [CatalogWriteDenied] si RLS no deja pausarla.
  @override
  Future<void> setBranchPaused(String branchId, bool paused) async {
    final updated = await _db
        .from('branches')
        .update({'paused': paused})
        .eq('id', branchId)
        .select('id');
    if (updated.isEmpty) throw const CatalogWriteDenied('pausar la sede');
    await refresh();
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Sube la foto del plato a `dish-images/<business_id>/` y devuelve la URL.
  @override
  Future<String?> uploadDishPhoto({
    required String businessId,
    required Uint8List bytes,
  }) async {
    try {
      final path = '$businessId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _db.storage
          .from('dish-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const sb.FileOptions(contentType: 'image/jpeg'),
          );
      return _db.storage.from('dish-images').getPublicUrl(path);
    } on Object {
      return null;
    }
  }

  // ------------------------------------------------------------ Mapeo

  /// Convierte una fila de `businesses` al modelo.
  static Business _business(Map<String, dynamic> row) => Business(
    id: row['id'] as String,
    brand: (row['brand'] as String?) ?? '',
    legalName: (row['legal_name'] as String?) ?? '',
    nit: (row['nit'] as String?) ?? '',
    cuisine: (row['cuisine'] as String?) ?? 'almuerzo',
    description: (row['description'] as String?) ?? '',
    ownerName: (row['owner_name'] as String?) ?? '',
    ownerDoc: (row['owner_doc'] as String?) ?? '',
    ownerPhone: (row['owner_phone'] as String?) ?? '',
    ownerEmail: (row['owner_email'] as String?) ?? '',
    bankName: (row['bank_name'] as String?) ?? 'Banco de demostración',
    accountType: (row['account_type'] as String?) ?? 'Ahorros',
    accountNumber: (row['account_number'] as String?) ?? '•••• 0000',
    nutritionInfo: (row['nutrition_info'] as bool?) ?? false,
    isDemo: (row['is_demo'] as bool?) ?? false,
  );

  /// Convierte una fila de `branches` al modelo.
  static Restaurant _restaurant(Map<String, dynamic> row) => Restaurant(
    id: row['id'] as String,
    businessId: row['business_id'] as String,
    name: (row['name'] as String?) ?? '',
    emoji: (row['emoji'] as String?) ?? '🍽️',
    tagline: (row['tagline'] as String?) ?? '',
    cuisine: (row['cuisine'] as String?) ?? 'almuerzo',
    address: (row['address'] as String?) ?? '',
    rating: ((row['rating'] as num?) ?? 4.5).toDouble(),
    prepMin: ((row['prep_min'] as num?) ?? 20).toInt(),
    lat: ((row['lat'] as num?) ?? 0).toDouble(),
    lng: ((row['lng'] as num?) ?? 0).toDouble(),
    radiusKm: ((row['radius_km'] as num?) ?? 3).toDouble(),
    couriersNearby: ((row['couriers_nearby'] as num?) ?? 0).toInt(),
    openHour: ((row['open_hour'] as num?) ?? 8).toInt(),
    closeHour: ((row['close_hour'] as num?) ?? 22).toInt(),
    closedWeekdays:
        (row['closed_weekdays'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        const [],
    campusId: row['campus_id'] as String?,
    studentDiscount: ((row['student_discount'] as num?) ?? 0).toDouble(),
    paused: (row['paused'] as bool?) ?? false,
    demo: (row['demo'] as bool?) ?? false,
    campusDeliveryOnly: (row['campus_delivery_only'] as bool?) ?? false,
    showsNutrition: (row['shows_nutrition'] as bool?) ?? false,
    imageAsset: row['image_url'] as String?,
    branchName: (row['branch_name'] as String?) ?? 'Sede principal',
  );

  /// Convierte una fila de `dishes` con sus opciones al modelo.
  static Dish _dish(
    Map<String, dynamic> row,
    Map<String, Map<String, List<DishOption>>> optionsByDish,
  ) {
    final id = row['id'] as String;
    final options = optionsByDish[id];
    final nutrition = row['nutrition'];

    return Dish(
      id: id,
      restaurantId: row['branch_id'] as String,
      name: (row['name'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      price: ((row['price'] as num?) ?? 0).toInt(),
      emoji: (row['emoji'] as String?) ?? '🍽️',
      category: (row['category_id'] as String?) ?? 'almuerzo',
      section: (row['section'] as String?) ?? 'Menú',
      prepMin: ((row['prep_min'] as num?) ?? 15).toInt(),
      rating: ((row['rating'] as num?) ?? 4.6).toDouble(),
      ingredients: _strings(row['ingredients']),
      allergens: _strings(row['allergens']),
      tags: _strings(row['tags']),
      nutrition: nutrition is Map
          ? Nutrition(
              kcal: ((nutrition['kcal'] as num?) ?? 0).toInt(),
              protein: ((nutrition['protein'] as num?) ?? 0).toInt(),
              carbs: ((nutrition['carbs'] as num?) ?? 0).toInt(),
              fat: ((nutrition['fat'] as num?) ?? 0).toInt(),
            )
          : null,
      sizes: options?['size'] ?? const [],
      sides: options?['side'] ?? const [],
      extras: options?['extra'] ?? const [],
      popular: (row['popular'] as bool?) ?? false,
      featured: (row['featured'] as bool?) ?? false,
      active: (row['active'] as bool?) ?? true,
      soldOut: (row['sold_out'] as bool?) ?? false,
      portionLimit: (row['portion_limit'] as num?)?.toInt(),
      soldToday: ((row['sold_today'] as num?) ?? 0).toInt(),
      imageAsset: row['image_url'] as String?,
    );
  }

  /// Convierte un arreglo JSON en lista de textos.
  static List<String> _strings(Object? value) =>
      (value as List?)?.map((e) => e.toString()).toList() ?? const [];
}
