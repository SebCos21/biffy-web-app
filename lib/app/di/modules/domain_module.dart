import 'package:get_it/get_it.dart';

import '../../../core/utils/clock.dart';
import '../../../domain/ports/catalog_ports.dart';
import '../../../domain/ports/courier_ports.dart';
import '../../../domain/ports/order_ports.dart';
import '../../../domain/ports/review_ports.dart';
import '../../../domain/repositories/address_repository.dart';
import '../../../domain/repositories/catalog_repository.dart';
import '../../../domain/repositories/courier_repository.dart';
import '../../../domain/repositories/merchant_boxes_repository.dart';
import '../../../domain/repositories/notification_repository.dart';
import '../../../domain/repositories/order_repository.dart';
import '../../../domain/repositories/payment_repository.dart';
import '../../../domain/repositories/preferences_repository.dart';
import '../../../domain/repositories/review_repository.dart';
import '../../../domain/repositories/rewards_repository.dart';
import '../../../domain/repositories/university_repository.dart';
import '../../../domain/repositories/wallet_repository.dart';
import '../../../domain/usecases/addresses/address_usecases.dart';
import '../../../domain/usecases/catalog/catalog_usecases.dart';
import '../../../domain/usecases/courier/courier_usecases.dart';
import '../../../domain/usecases/get_courier_earnings.dart';
import '../../../domain/usecases/merchant_boxes_usecases.dart';
import '../../../domain/usecases/notifications/notification_usecases.dart';
import '../../../domain/usecases/orders/order_usecases.dart';
import '../../../domain/usecases/payments/check_payment_status.dart';
import '../../../domain/usecases/payments/retry_payment.dart';
import '../../../domain/usecases/payments/start_payment.dart';
import '../../../domain/usecases/preferences/preferences_usecases.dart';
import '../../../domain/usecases/rate_order.dart';
import '../../../domain/usecases/rewards_usecases.dart';
import '../../../domain/usecases/university/university_usecases.dart';
import '../../../domain/usecases/wallet/wallet_usecases.dart';
import '../../../shared/adapters/courier_adapters.dart';
import '../../../shared/adapters/order_adapters.dart';
import '../../../shared/adapters/review_adapters.dart';
import '../../../shared/adapters/server_order_notifier.dart';
import '../../../shared/adapters/catalog_adapters.dart';
import '../../../shared/state/session_controller.dart';

/// Módulo de dominio: puertos (con sus adaptadores) y casos de uso.
///
/// Los puertos son `LazySingleton` y se piden siempre por su interfaz; los
/// casos de uso son `Factory`: no guardan estado, cada petición crea uno nuevo.
void registerDomainModule(GetIt g) {
  _registerPorts(g);
  _registerUseCases(g);
}

/// Conecta los puertos del dominio con los controladores de la app.
void _registerPorts(GetIt g) {
  g.registerLazySingleton<OrderCatalogPort>(
    () => CatalogOrderAdapter(g<CatalogUseCases>()),
  );
  g.registerLazySingleton<OrderBuyerPort>(
    () => SessionOrderAdapter(
      g<SessionController>(),
      g<WalletUseCases>(),
      g<UniversityUseCases>().queries,
    ),
  );
  g.registerLazySingleton<OrderWalletPort>(
    () => SessionOrderAdapter(
      g<SessionController>(),
      g<WalletUseCases>(),
      g<UniversityUseCases>().queries,
    ),
  );
  // Con servidor los avisos los crea la base (0022); en demo, la app.
  g.registerLazySingleton<OrderNotifier>(
    () => g<OrderRepository>().isRemote
        ? const ServerOrderNotifier()
        : NotificationOrderAdapter(g<PushNotification>(), demo: true),
  );
  g.registerLazySingleton<CourierSessionPort>(
    () => SessionCourierAdapter(
      g<SessionController>(),
      g<UniversityUseCases>().queries,
    ),
  );
  g.registerLazySingleton<CatalogContextPort>(
    () => SessionCatalogAdapter(g<SessionController>()),
    dispose: (port) {
      if (port is SessionCatalogAdapter) port.dispose();
    },
  );
  g.registerLazySingleton<BranchRatingPort>(
    () => CatalogRatingAdapter(g<CatalogUseCases>()),
  );
  g.registerLazySingleton<ReviewNotifier>(
    () => g<OrderRepository>().isRemote
        ? const ServerReviewNotifier()
        : LocalReviewNotifier(
            g<PushNotification>(),
            g<CatalogUseCases>().queries,
          ),
  );
}

/// Un caso de uso nuevo por cada petición al contenedor.
void _registerUseCases(GetIt g) {
  g.registerFactory<OrderUseCases>(
    () => OrderUseCases(
      repo: g<OrderRepository>(),
      catalog: g<OrderCatalogPort>(),
      buyers: g<OrderBuyerPort>(),
      wallet: g<OrderWalletPort>(),
      notifier: g<OrderNotifier>(),
      clock: g<Clock>(),
    ),
  );
  g.registerFactory<RateOrder>(
    () => RateOrder(
      g<ReviewRepository>(),
      g<BranchRatingPort>(),
      g<ReviewNotifier>(),
    ),
  );
  g.registerFactory<GetCourierEarnings>(GetCourierEarnings.new);

  // Avisos: el paquete completo (para el Bloc y la sesión) y el de publicar
  // (para los notificadores de pedidos y reseñas del modo demo).
  g.registerFactory<NotificationUseCases>(
    () => NotificationUseCases(
      repo: g<NotificationRepository>(),
      clock: g<Clock>(),
    ),
  );
  g.registerFactory<PushNotification>(
    () => PushNotification(g<NotificationRepository>(), g<Clock>()),
  );

  // Billetera: Gotas y cupones (la sesión, el WalletCubit y pedidos).
  g.registerFactory<WalletUseCases>(
    () => WalletUseCases(repo: g<WalletRepository>(), clock: g<Clock>()),
  );

  // Direcciones de entrega (la sesión crea la inicial y las carga).
  g.registerFactory<AddressUseCases>(
    () => AddressUseCases(repo: g<AddressRepository>()),
  );

  // Preferencias y favoritos (la encuesta acredita Gotas y avisa).
  g.registerFactory<PreferencesUseCases>(
    () => PreferencesUseCases(
      repo: g<PreferencesRepository>(),
      credit: g<WalletUseCases>().credit,
      push: g<PushNotification>(),
    ),
  );

  // Verificación universitaria (usa preferencias y avisos).
  g.registerFactory<UniversityUseCases>(
    () => UniversityUseCases(
      repo: g<UniversityRepository>(),
      preferences: g<PreferencesUseCases>(),
      push: g<PushNotification>(),
      clock: g<Clock>(),
    ),
  );

  // Catálogo: lecturas con la regla de alcance y escrituras del comercio.
  g.registerFactory<CatalogUseCases>(
    () => CatalogUseCases(
      repo: g<CatalogRepository>(),
      context: g<CatalogContextPort>(),
      clock: g<Clock>(),
    ),
  );

  // Repartidor: el paquete completo (para el CourierCubit) y las dos piezas
  // que solo leen el repositorio (para la sesión, sin ciclo con el puerto).
  g.registerFactory<CourierUseCases>(
    () => CourierUseCases(
      repo: g<CourierRepository>(),
      session: g<CourierSessionPort>(),
    ),
  );
  g.registerFactory<CourierQueries>(
    () => CourierQueries(g<CourierRepository>()),
  );
  g.registerFactory<LoadCourier>(() => LoadCourier(g<CourierRepository>()));

  // Pagos: iniciar, consultar y reintentar (sin estado propio).
  g.registerFactory<StartPayment>(() => StartPayment(g<PaymentRepository>()));
  g.registerFactory<CheckPaymentStatus>(
    () => CheckPaymentStatus(g<PaymentRepository>()),
  );
  g.registerFactory<RetryPayment>(() => RetryPayment(g<PaymentRepository>()));

  // Recompensas y cajas: solo se piden cuando hay repositorio (Supabase).
  g.registerFactory<LoadRewards>(() => LoadRewards(g<RewardsRepository>()));
  g.registerFactory<RedeemReward>(() => RedeemReward(g<RewardsRepository>()));
  g.registerFactory<LoadMerchantBoxes>(
    () => LoadMerchantBoxes(g<MerchantBoxesRepository>()),
  );
  g.registerFactory<AddDishToBox>(
    () => AddDishToBox(g<MerchantBoxesRepository>()),
  );
  g.registerFactory<ClaimBoxPrize>(
    () => ClaimBoxPrize(g<MerchantBoxesRepository>()),
  );
}
