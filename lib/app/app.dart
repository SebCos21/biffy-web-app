import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/orders/bloc/orders_bloc.dart';
import '../features/buyer/cart/bloc/cart_cubit.dart';
import '../features/addresses/bloc/addresses_cubit.dart';
import '../features/catalog/bloc/catalog_bloc.dart';
import '../features/courier/bloc/courier_cubit.dart';
import '../features/notifications/bloc/notifications_bloc.dart';
import '../features/preferences/bloc/preferences_cubit.dart';
import '../features/university/bloc/university_cubit.dart';
import '../features/wallet/bloc/wallet_cubit.dart';
import '../features/auth/bloc/auth_bloc.dart';
import 'auth_refresh.dart';
import 'di/injection.dart';
import 'router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

/// Raíz de la app: estado (desde GetIt), tema y router.
///
/// Requiere que `configureDependencies()` ya se haya ejecutado.
class BiffyApp extends StatefulWidget {
  const BiffyApp({super.key, this.initialLocation = '/splash'});

  final String initialLocation;

  /// Crea el estado raíz de la app.
  @override
  State<BiffyApp> createState() => _BiffyAppState();
}

/// Estado que crea el router una sola vez y escucha el modo oscuro.
class _BiffyAppState extends State<BiffyApp> {
  /// Avisa al router cada vez que cambia la sesión.
  late final StreamRefreshListenable _authRefresh = StreamRefreshListenable(
    getIt<AuthBloc>().stream,
  );
  late final GoRouter _router = buildRouter(
    getIt<AuthBloc>(),
    refresh: _authRefresh,
    initialLocation: widget.initialLocation,
  );
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<OrdersState>? _orderErrors;
  int _lastOutcome = 0;

  /// Acciones cuya pantalla no muestra el error por su cuenta.
  static const _globalErrorActions = {
    OrderAction.accept,
    OrderAction.reject,
    OrderAction.ready,
    OrderAction.declineOffer,
  };

  @override
  void initState() {
    super.initState();
    // Errores del servidor ya traducidos (aceptar, rechazar, marcar listo…):
    // los botones sin resultado propio los muestran por aquí.
    _orderErrors = getIt<OrdersBloc>().stream.listen((state) {
      final o = state.outcome;
      if (o == null || o.id <= _lastOutcome) return;
      _lastOutcome = o.id;
      if (!o.ok && _globalErrorActions.contains(o.action)) {
        _showOrderError(o.result.message);
      }
    });
  }

  void _showOrderError(String message) {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  /// Libera el router al cerrar la app.
  @override
  void dispose() {
    _orderErrors?.cancel();
    _router.dispose();
    _authRefresh.dispose();
    super.dispose();
  }

  /// Envuelve la app con el estado compartido, el tema y el router.
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: getIt<AuthBloc>()),
        BlocProvider<CatalogBloc>.value(value: getIt<CatalogBloc>()),
        BlocProvider<OrdersBloc>.value(value: getIt<OrdersBloc>()),
        BlocProvider<CartCubit>.value(value: getIt<CartCubit>()),
        BlocProvider<NotificationsBloc>.value(
          value: getIt<NotificationsBloc>(),
        ),
        BlocProvider<CourierCubit>.value(value: getIt<CourierCubit>()),
        BlocProvider<WalletCubit>.value(value: getIt<WalletCubit>()),
        BlocProvider<AddressesCubit>.value(value: getIt<AddressesCubit>()),
        BlocProvider<UniversityCubit>.value(value: getIt<UniversityCubit>()),
        BlocProvider<PreferencesCubit>.value(value: getIt<PreferencesCubit>()),
      ],
      // Reconstruye el tema solo cuando cambia el modo oscuro.
      child: BlocSelector<AuthBloc, AuthState, bool>(
        selector: (s) => s.session.settings.darkMode,
        builder: (context, dark) => MaterialApp.router(
          title: 'Biffy',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _messengerKey,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          locale: const Locale('es', 'CO'),
          supportedLocales: const [Locale('es', 'CO'), Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: _router,
        ),
      ),
    );
  }
}
