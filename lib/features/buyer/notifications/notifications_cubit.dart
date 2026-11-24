import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/app_notification.dart';
import '../../notifications/bloc/notifications_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';

/// Lo que muestra la pantalla de notificaciones del rol activo.
class NotificationsState {
  /// Crea el estado con los avisos y si están activados.
  const NotificationsState({required this.items, required this.enabled});

  /// Avisos visibles para el usuario y rol, del más nuevo al más viejo.
  final List<AppNotification> items;

  /// `false` si el usuario apagó las notificaciones en Ajustes.
  final bool enabled;

  /// Cuántos avisos faltan por leer.
  int get unread => items.where((n) => !n.read).length;
}

/// Cubit de la pantalla de notificaciones: filtra los avisos del rol activo y
/// despacha al [NotificationsBloc] las acciones de leer.
///
/// Flujo: [NotificationsBloc] (avisos compartidos) + sesión (quién soy) →
/// [NotificationsCubit] → pantalla.
class NotificationsCubit extends Cubit<NotificationsState> {
  /// Escucha el Bloc de avisos y la sesión para mantenerse al día.
  NotificationsCubit({
    required NotificationsBloc notifications,
    required AuthBloc session,
  }) : _bloc = notifications,
       _session = session,
       super(_read(notifications, session)) {
    _subs = [
      _bloc.stream.listen((_) => _refresh()),
      _session.stream.listen((_) => _refresh()),
    ];
  }

  final NotificationsBloc _bloc;
  final AuthBloc _session;
  List<StreamSubscription<Object?>> _subs = const [];

  /// Lee los avisos visibles para el usuario y rol actuales.
  static NotificationsState _read(
    NotificationsBloc bloc,
    AuthBloc session,
  ) => NotificationsState(
    items: bloc.visibleFor(session.user, session.activeRole),
    enabled: session.settings.notifications,
  );

  /// Vuelve a leer los avisos cuando algo cambia.
  void _refresh() {
    if (!isClosed) emit(_read(_bloc, _session));
  }

  /// Marca un aviso como leído (y en la base si viene de Supabase).
  void open(AppNotification n) {
    if (!n.read) _bloc.add(NotificationOpened(n.id));
  }

  /// Marca como leídos todos los avisos visibles.
  void markAllRead() =>
      _bloc.add(AllNotificationsRead(_session.user, _session.activeRole));

  /// Deja de escuchar al cerrar la pantalla.
  @override
  Future<void> close() {
    for (final s in _subs) {
      s.cancel();
    }
    return super.close();
  }
}
