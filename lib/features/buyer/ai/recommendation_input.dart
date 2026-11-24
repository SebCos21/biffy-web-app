import 'package:flutter/widgets.dart';

import '../../../data/models/order.dart';
import '../../../domain/recommendation.dart';
import '../../catalog/bloc/catalog_bloc.dart';
import '../../../features/orders/bloc/orders_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../university/bloc/university_cubit.dart';
import '../../../app/di/injection.dart';
import '../../preferences/bloc/preferences_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Construye la entrada del motor de recomendaciones desde el estado actual.
RecommendationInput buildRecommendationInput(
  BuildContext context, {
  int seed = 0,
}) {
  final session = getIt<AuthBloc>();
  final uniCubit = getIt<UniversityCubit>();
  final catalog = getIt<CatalogBloc>();
  final prefs = getIt<PreferencesCubit>();
  final orders = context.read<OrdersBloc>();
  final user = session.user;
  final history = <String>[
    if (user != null)
      for (final o in orders.forBuyer(user.id))
        if (o.status == OrderStatus.delivered)
          for (final l in o.lines) l.dishId,
  ];
  return RecommendationInput(
    dishes: catalog.reachableDishes,
    restaurantOf: catalog.restaurantById,
    prefs: prefs.prefsOf(user?.id),
    point: session.point,
    historyDishIds: history,
    favoriteDishIds: prefs.favoriteDishes(user?.id),
    universityId: uniCubit.universityIdOf(session.user?.id),
    now: catalog.now,
    seed: seed,
  );
}
