import 'package:biffy/app/di/injection.dart';
import 'package:biffy/core/constants/catalog_constants.dart';
import 'package:biffy/data/mock/seed_users.dart';
import 'package:biffy/data/repositories/catalog_repository.dart';
import 'package:biffy/features/buyer/cart/bloc/cart_cubit.dart';
import 'package:biffy/features/buyer/cart/bloc/checkout_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Pruebas con bloc_test del carrito y del checkout: un caso exitoso y uno de
/// error por cubit, verificando la secuencia exacta de estados emitidos.
void main() {
  late TestServices s;

  setUp(() async {
    s = await makeServices();
  });

  group('CartCubit', () {
    late AddResult result;

    blocTest<CartCubit, CartState>(
      'agregar un plato emite el carrito con su línea, restaurante y subtotal',
      build: () => CartCubit(getIt<CatalogRepository>()),
      act: (c) => result = c.add(s.catalog.dishById('qbano-pollo')!, qty: 2),
      expect: () => [
        isA<CartState>()
            .having((st) => st.count, 'count', 2)
            .having((st) => st.items, 'items', hasLength(1))
            .having((st) => st.restaurantId, 'restaurantId', 'qbano-icesi')
            .having((st) => st.subtotal, 'subtotal', 21900 * 2),
      ],
      verify: (_) => expect(result, AddResult.added),
    );

    blocTest<CartCubit, CartState>(
      'un plato agotado no cambia el estado y avisa que no está disponible',
      build: () => CartCubit(getIt<CatalogRepository>()),
      act: (c) =>
          result = c.add(s.catalog.dishById('capuchino')!..soldOut = true),
      expect: () => <CartState>[],
      verify: (c) {
        expect(result, AddResult.unavailable);
        expect(c.state.isEmpty, isTrue);
      },
    );

    blocTest<CartCubit, CartState>(
      'un plato de otro restaurante no se mezcla con el carrito actual',
      build: () => CartCubit(getIt<CatalogRepository>()),
      act: (c) {
        c.add(s.catalog.dishById('qbano-pollo')!);
        result = c.add(s.catalog.dishById('capuchino')!);
      },
      expect: () => [isA<CartState>().having((st) => st.count, 'count', 1)],
      verify: (c) {
        expect(result, AddResult.differentRestaurant);
        expect(c.state.restaurantId, 'qbano-icesi');
      },
    );
  });

  group('CheckoutCubit', () {
    blocTest<CheckoutCubit, CheckoutState>(
      'confirmar emite «enviando» y luego el pedido creado',
      setUp: () {
        s.session.login(kDemoBuyerEmail, kDemoPassword);
        s.cart.add(s.catalog.dishById('qbano-pollo')!);
      },
      build: () =>
          CheckoutCubit(orders: s.orders, session: s.session, cart: s.cart),
      act: (c) => c.submit(),
      expect: () => [
        isA<CheckoutState>()
            .having((st) => st.placing, 'placing', isTrue)
            .having((st) => st.error, 'error', isNull),
        isA<CheckoutState>()
            .having((st) => st.placing, 'placing', isFalse)
            .having((st) => st.orderId, 'orderId', isNotNull)
            .having((st) => st.message, 'message', contains('demostración'))
            .having((st) => st.error, 'error', isNull),
      ],
      verify: (_) => expect(s.cart.isEmpty, isTrue),
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'sin dirección emite el error en español y conserva el carrito',
      setUp: () {
        s.session.login(kDemoNewBuyerEmail, kDemoPassword);
        s.cart.add(s.catalog.dishById('qbano-pollo')!);
      },
      build: () =>
          CheckoutCubit(orders: s.orders, session: s.session, cart: s.cart),
      act: (c) => c.submit(),
      expect: () => [
        isA<CheckoutState>()
            .having((st) => st.placing, 'placing', isFalse)
            .having((st) => st.orderId, 'orderId', isNull)
            .having(
              (st) => st.error,
              'error',
              contains('Selecciona una dirección de entrega.'),
            ),
      ],
      verify: (_) => expect(s.cart.isEmpty, isFalse),
    );
  });
}
