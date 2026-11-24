import 'package:get_it/get_it.dart';

import '../../../core/utils/clock.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../domain/repositories/catalog_repository.dart';
import '../../../domain/repositories/merchant_boxes_repository.dart';
import '../../../domain/repositories/payment_repository.dart';
import '../../../domain/repositories/profile_repository.dart';
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
import '../../../features/buyer/cart/bloc/cart_cubit.dart';
import '../../../features/buyer/cart/bloc/checkout_cubit.dart';
import '../../../features/buyer/payment/bloc/payment_bloc.dart';
import '../../../features/buyer/notifications/notifications_cubit.dart';
import '../../../features/buyer/rewards/rewards_cubit.dart';
import '../../../features/buyer/tracking/rate_order_cubit.dart';
import '../../../features/addresses/bloc/addresses_cubit.dart';
import '../../../features/auth/bloc/login_cubit.dart';
import '../../../features/auth/bloc/register_cubit.dart';
import '../../../features/auth/bloc/university_verification_cubit.dart';
import '../../../features/catalog/bloc/catalog_bloc.dart';
import '../../../features/courier/bloc/courier_cubit.dart';
import '../../../features/courier/earnings/earnings_cubit.dart';
import '../../../features/notifications/bloc/notifications_bloc.dart';
import '../../../features/orders/bloc/orders_bloc.dart';
import '../../../features/preferences/bloc/preferences_cubit.dart';
import '../../../features/restaurant_owner/boxes/merchant_boxes_cubit.dart';
import '../../../features/university/bloc/university_cubit.dart';
import '../../../features/wallet/bloc/wallet_cubit.dart';
import '../../../shared/state/session_controller.dart';

/// Módulo de presentación: estado que consumen las pantallas.
///
/// - `SessionController` (`ChangeNotifier`, aún sin migrar), `CatalogBloc`,
///   `OrdersBloc`, `NotificationsBloc` y `CourierCubit`: un solo objeto para
///   toda la app (`LazySingleton`).
/// - Cubits de una pantalla: `Factory`, uno nuevo cada vez que se abre.
void registerPresentationModule(GetIt g) {
  _registerControllers(g);
  _registerBlocs(g);
}

/// Devuelve la dependencia si el módulo de datos la registró; si no, `null`.
T? _optional<T extends Object>(GetIt g) => g.isRegistered<T>() ? g<T>() : null;

/// Controladores compartidos por todas las pantallas.
void _registerControllers(GetIt g) {
  g.registerLazySingleton<SessionController>(
    () => SessionController(
      g<AuthRepository>(),
      g<NotificationUseCases>(),
      g<Clock>(),
      couriers: g<CourierQueries>(),
      loadCourier: g<LoadCourier>(),
      wallet: g<WalletUseCases>(),
      preferences: g<PreferencesUseCases>(),
      addresses: g<AddressUseCases>(),
      university: g<UniversityUseCases>(),
      profile: _optional<ProfileRepository>(g),
    ),
  );
  g.registerLazySingleton<CartCubit>(() => CartCubit(g<CatalogRepository>()));
}

/// Bloc de pedidos (global) y cubits de pantalla.
void _registerBlocs(GetIt g) {
  g.registerLazySingleton<CatalogBloc>(
    () => CatalogBloc(g<CatalogUseCases>()),
    dispose: (bloc) => bloc.close(),
  );
  g.registerLazySingleton<OrdersBloc>(
    () => OrdersBloc(g<OrderUseCases>()),
    dispose: (bloc) => bloc.close(),
  );
  g.registerLazySingleton<UniversityCubit>(
    () => UniversityCubit(g<UniversityUseCases>()),
    dispose: (cubit) => cubit.close(),
  );
  g.registerLazySingleton<AddressesCubit>(
    () => AddressesCubit(g<AddressUseCases>()),
    dispose: (cubit) => cubit.close(),
  );
  g.registerLazySingleton<PreferencesCubit>(
    () => PreferencesCubit(g<PreferencesUseCases>()),
    dispose: (cubit) => cubit.close(),
  );
  g.registerLazySingleton<WalletCubit>(
    () => WalletCubit(g<WalletUseCases>()),
    dispose: (cubit) => cubit.close(),
  );
  g.registerLazySingleton<CourierCubit>(
    () => CourierCubit(g<CourierUseCases>()),
    dispose: (cubit) => cubit.close(),
  );
  g.registerLazySingleton<NotificationsBloc>(
    () => NotificationsBloc(g<NotificationUseCases>()),
    dispose: (bloc) => bloc.close(),
  );
  g.registerFactory<NotificationsCubit>(
    () => NotificationsCubit(
      notifications: g<NotificationsBloc>(),
      session: g<SessionController>(),
    ),
  );
  g.registerFactory<RewardsCubit>(
    () => RewardsCubit(
      load: g<LoadRewards>(),
      redeem: g<RedeemReward>(),
      refreshBalance: g<SessionController>().refreshRemote,
    ),
  );
  g.registerFactoryParam<RateOrderCubit, RateOrderArgs, void>(
    (args, _) => RateOrderCubit(
      rateOrder: g<RateOrder>(),
      order: args.order,
      userId: args.userId,
      initialStars: args.initialStars,
    ),
  );
  g.registerFactoryParam<EarningsCubit, String, void>(
    (courierId, _) => EarningsCubit(
      orders: g<OrdersBloc>(),
      courierId: courierId,
      now: () => g<Clock>().now(),
      getEarnings: g<GetCourierEarnings>(),
    ),
  );
  g.registerFactory<MerchantBoxesCubit>(
    () => MerchantBoxesCubit(
      repo: g<MerchantBoxesRepository>(),
      load: g<LoadMerchantBoxes>(),
      add: g<AddDishToBox>(),
      claim: g<ClaimBoxPrize>(),
    ),
  );
  // Cubits de una sola pantalla (login, registro, campus y checkout).
  g.registerFactory<LoginCubit>(() => LoginCubit(g<SessionController>()));
  g.registerFactory<RegisterCubit>(() => RegisterCubit(g<SessionController>()));
  g.registerFactory<UniversityVerificationCubit>(
    () => UniversityVerificationCubit(
      g<UniversityUseCases>(),
      () => g<SessionController>().user?.id,
    ),
  );
  g.registerFactory<CheckoutCubit>(
    () => CheckoutCubit(
      orders: g<OrdersBloc>(),
      session: g<SessionController>(),
      cart: g<CartCubit>(),
      wallet: g<WalletCubit>(),
      addresses: g<AddressesCubit>(),
    ),
  );
  g.registerFactoryParam<PaymentBloc, String, void>(
    (orderId, _) => PaymentBloc(
      orderId: orderId,
      start: g<StartPayment>(),
      check: g<CheckPaymentStatus>(),
      retry: g<RetryPayment>(),
      watch: g<PaymentRepository>().watch,
    ),
  );
}
