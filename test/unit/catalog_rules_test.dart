import 'package:biffy/core/constants/catalog_constants.dart';
import 'package:biffy/data/mock/seed_catalog.dart';
import 'package:biffy/data/models/catalog.dart';
import 'package:biffy/domain/catalog_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final restaurants = {for (final r in seedRestaurants()) r.id: r};
  final dishes = seedDishes();
  final tuesdayNoon = DateTime(2026, 10, 20, 12);
  FilterContext ctx({Set<String> allergies = const {}, DateTime? now}) =>
      FilterContext(
        restaurantOf: (id) => restaurants[id],
        now: now ?? tuesdayNoon,
        allergies: allergies,
      );

  group('Cobertura', () {
    test('Qbano solo entrega dentro de Icesi', () {
      final q = restaurants['qbano-icesi']!;
      expect(isReachable(q, pointById('icesi-biblioteca')), isTrue);
      expect(isReachable(q, pointById('biblio')), isFalse);
    });

    test('sin repartidores cerca no es alcanzable', () {
      expect(
        isReachable(restaurants['dulce-panal']!, pointById('biblio')),
        isFalse,
      );
    });

    test('coverageGap explica por qué no llega (y en qué orden)', () {
      const point = DeliveryPoint(
        id: 'p',
        name: 'Punto',
        detail: '',
        lat: 3.34,
        lng: -76.53,
        campusId: 'icesi',
      );
      /// Sede de prueba junto al punto, ajustable por cada causa de cobertura.
      Restaurant sede({
        int couriers = 2,
        double lat = 3.34,
        bool campusOnly = false,
        String campus = 'icesi',
      }) => Restaurant(
        id: 'r',
        businessId: 'b',
        name: 'Sede',
        emoji: '🍽️',
        tagline: '',
        cuisine: 'almuerzo',
        address: '',
        rating: 4.5,
        prepMin: 10,
        lat: lat,
        lng: -76.53,
        radiusKm: 3,
        couriersNearby: couriers,
        openHour: 8,
        closeHour: 22,
        campusId: campus,
        campusDeliveryOnly: campusOnly,
      );

      expect(coverageGap(sede(), point), isNull);
      expect(coverageGap(sede(couriers: 0), point), CoverageGap.noCouriers);
      expect(coverageGap(sede(lat: 3.6), point), CoverageGap.tooFar);
      expect(
        coverageGap(sede(campusOnly: true, campus: 'unal'), point),
        CoverageGap.campusOnly,
      );
      // Solo campus va primero, luego repartidores y al final el radio.
      expect(
        coverageGap(
          sede(campusOnly: true, campus: 'unal', couriers: 0, lat: 3.6),
          point,
        ),
        CoverageGap.campusOnly,
      );
      expect(
        coverageGap(sede(couriers: 0, lat: 3.6), point),
        CoverageGap.noCouriers,
      );
    });

    test('isReachable equivale a coverageGap == null', () {
      for (final r in restaurants.values) {
        for (final p in kDeliveryPoints) {
          expect(
            isReachable(r, p),
            coverageGap(r, p) == null,
            reason: '${r.id} → ${p.id}',
          );
        }
      }
    });

    test('horario y días cerrados', () {
      final rosa = restaurants['dona-rosa']!;
      expect(isOpenAt(rosa, tuesdayNoon), isTrue);
      expect(isOpenAt(rosa, DateTime(2026, 10, 20, 17)), isFalse);
      expect(isOpenAt(rosa, DateTime(2026, 10, 25, 12)), isFalse); // domingo
    });
  });

  group('Filtros', () {
    test('precio máximo', () {
      final r = filterDishes(dishes, const DishFilters(maxPrice: 10000), ctx());
      expect(r, isNotEmpty);
      expect(r.every((d) => d.price <= 10000), isTrue);
    });

    test('precio inferior a \$15.000', () {
      final r = filterDishes(dishes, const DishFilters(cheapOnly: true), ctx());
      expect(r.every((d) => d.price < 15000), isTrue);
    });

    test('categoría', () {
      final r = filterDishes(
        dishes,
        const DishFilters(categories: {'pizza'}),
        ctx(),
      );
      expect(r, isNotEmpty);
      expect(r.every((d) => d.category == 'pizza'), isTrue);
    });

    test('tiempo menor a 15 minutos', () {
      final r = filterDishes(dishes, const DishFilters(fastOnly: true), ctx());
      expect(r.every((d) => d.prepMin < 15), isTrue);
      expect(r.any((d) => d.id == 'smash-combo'), isFalse);
    });

    test('búsqueda por restaurante, descripción e ingredientes', () {
      expect(
        filterDishes(
          dishes,
          const DishFilters(query: 'qbano'),
          ctx(),
        ).map((d) => d.restaurantId).toSet(),
        {'qbano-icesi'},
      );
      expect(
        filterDishes(
          dishes,
          const DishFilters(query: 'quinoa'),
          ctx(),
        ).map((d) => d.id),
        contains('bowl-proteico'),
      );
      expect(
        filterDishes(
          dishes,
          const DishFilters(query: 'sandwich vegetariano'),
          ctx(),
        ).map((d) => d.id),
        ['qbano-vegetariano'],
      );
    });

    test('excluye platos incompatibles con alergias', () {
      final r = filterDishes(
        dishes,
        const DishFilters(excludeAllergens: true),
        ctx(allergies: {'gluten'}),
      );
      expect(r, isNotEmpty);
      expect(r.any((d) => d.allergens.contains('gluten')), isFalse);
      expect(
        allergyConflicts(dishes.firstWhere((d) => d.id == 'qbano-especial'), {
          'gluten',
          'maní',
        }),
        ['gluten'],
      );
    });

    test('estilo de vida: vegetariano incluye vegano', () {
      final r = filterDishes(
        dishes,
        const DishFilters(lifestyle: {'vegetariano'}),
        ctx(),
      );
      expect(
        r.map((d) => d.id),
        containsAll(['verde-bowl', 'pizza-margarita']),
      );
    });

    test('valoración y abiertos', () {
      final top = filterDishes(
        dishes,
        const DishFilters(topRated: true),
        ctx(),
      );
      expect(top.every((d) => d.rating >= 4.7), isTrue);
      final night = filterDishes(
        dishes,
        const DishFilters(openOnly: true),
        ctx(now: DateTime(2026, 10, 20, 23, 30)),
      );
      expect(night, isEmpty);
    });

    test('limpiar filtros conserva la búsqueda', () {
      const f = DishFilters(
        query: 'pizza',
        cheapOnly: true,
        categories: {'pizza'},
      );
      expect(f.activeCount, 2);
      expect(f.cleared().activeCount, 0);
      expect(f.cleared().query, 'pizza');
    });
  });
}
