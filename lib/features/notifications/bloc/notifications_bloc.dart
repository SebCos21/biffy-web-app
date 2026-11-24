import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/app_notification.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/notification_repository.dart';
import '../../../domain/usecases/notifications/notification_usecases.dart';

part 'notifications_event.dart';
part 'notifications_state.dart';

/// Bloc global de avisos (comprador, restaurante y repartidor).
///
/// Traduce eventos en casos de uso y publica el resultado en
/// [NotificationsState.outcome]. Escucha los cambios del repositorio (avisos
/// que crean otros casos de uso o que llegan por Realtime). No tiene reglas:
/// la visibilidad por rol vive en `domain/notification_rules.dart`.
class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  /// Se suscribe a la caché del repositorio.
  NotificationsBloc(this.useCases)
    : super(NotificationsState(items: useCases.queries.all)) {
    on<NotificationsChanged>(_onChanged);
    on<NotificationPushed>(
      (e, emit) => _run(
        emit,
        NotificationAction.push,
        () => useCases.push(
          title: e.title,
          body: e.body,
          audience: e.audience,
          route: e.route,
        ),
      ),
    );
    on<NotificationOpened>(
      (e, emit) =>
          _run(emit, NotificationAction.open, () => useCases.markRead(e.id)),
    );
    on<AllNotificationsRead>(
      (e, emit) => _run(
        emit,
        NotificationAction.markAllRead,
        () => useCases.markAllRead(e.user, e.role),
      ),
    );
    _changes = useCases.repo.changes.listen(
      (_) => add(const NotificationsChanged()),
    );
  }

  /// Casos de uso de avisos ya cableados.
  final NotificationUseCases useCases;
  StreamSubscription<void>? _changes;
  int _outcomeSeq = 0;

  // ------------------------------------------------------------- Lecturas
  // Atajos síncronos: leen la caché del repositorio (fuente de verdad).

  /// Todos los avisos.
  List<AppNotification> get all => useCases.queries.all;

  /// Avisos visibles para el usuario y rol.
  List<AppNotification> visibleFor(AppUser? user, UserRole role) =>
      useCases.queries.visibleFor(user, role);

  /// Avisos visibles sin leer.
  int unreadFor(AppUser? user, UserRole role) =>
      useCases.queries.unreadFor(user, role);

  /// Publica la lista nueva cuando cambia la caché.
  void _onChanged(
    NotificationsChanged event,
    Emitter<NotificationsState> emit,
  ) => emit(state.copyWith(items: all, revision: state.revision + 1));

  /// Ejecuta un caso de uso y publica su resultado; una excepción se
  /// convierte en `server_error` en vez de llegar a la pantalla.
  Future<void> _run(
    Emitter<NotificationsState> emit,
    NotificationAction action,
    Future<NotificationResult> Function() operation,
  ) async {
    NotificationResult result;
    try {
      result = await operation();
    } on Object {
      result = const NotificationResult('server_error');
    }
    emit(
      state.copyWith(
        items: all,
        revision: state.revision + 1,
        outcome: NotificationOutcome(++_outcomeSeq, action, result),
      ),
    );
  }

  /// Cancela la escucha del repositorio.
  @override
  Future<void> close() {
    _changes?.cancel();
    return super.close();
  }
}
