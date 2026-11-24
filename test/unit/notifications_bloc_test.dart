import 'package:biffy/core/constants/catalog_constants.dart';
import 'package:biffy/core/utils/clock.dart';
import 'package:biffy/data/mock/seed_users.dart';
import 'package:biffy/data/models/user.dart';
import 'package:biffy/data/repositories/in_memory_notification_repository.dart';
import 'package:biffy/domain/repositories/notification_repository.dart';
import 'package:biffy/domain/usecases/notifications/notification_usecases.dart';
import 'package:biffy/features/buyer/notifications/notifications_cubit.dart'
    as screen;
import 'package:biffy/features/notifications/bloc/notifications_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Repositorio en memoria cuyo `markRead` falla como si se cayera la red.
class _BrokenRepo extends InMemoryNotificationRepository {
  @override
  Future<NotificationResult> markRead(String id) =>
      Future.error(StateError('sin red'));
}

/// Deja que el Bloc procese los eventos pendientes.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

final _clock = Clock.fixed(DateTime(2026, 1, 1, 12));

/// Bloc nuevo sobre el repositorio indicado.
NotificationsBloc _bloc([NotificationRepository? repo]) => NotificationsBloc(
  NotificationUseCases(
    repo: repo ?? InMemoryNotificationRepository(),
    clock: _clock,
  ),
);

/// Pruebas con bloc_test del Bloc global de avisos y del cubit de pantalla.
void main() {
  group('NotificationsBloc', () {
    blocTest<NotificationsBloc, NotificationsState>(
      'publicar un aviso lo agrega a la lista con un resultado ok',
      build: _bloc,
      act: (b) async {
        b.add(
          const NotificationPushed(
            title: 'Hola',
            body: 'Mundo',
            audience: 'user:u1',
          ),
        );
        await _settle();
      },
      expect: () => contains(
        isA<NotificationsState>()
            .having((s) => s.outcome?.action, 'action', NotificationAction.push)
            .having((s) => s.outcome?.ok, 'ok', isTrue)
            .having((s) => s.items.single.title, 'título', 'Hola'),
      ),
      verify: (b) => expect(b.all.single.audience, 'user:u1'),
    );

    blocTest<NotificationsBloc, NotificationsState>(
      'marcar todos como leídos deja el contador en cero',
      build: _bloc,
      act: (b) async {
        b.add(const NotificationPushed(title: 'A', body: '', audience: 'all'));
        await _settle();
        b.add(const AllNotificationsRead(null, UserRole.buyer));
        await _settle();
      },
      expect: () => contains(
        isA<NotificationsState>()
            .having(
              (s) => s.outcome?.action,
              'action',
              NotificationAction.markAllRead,
            )
            .having((s) => s.outcome?.ok, 'ok', isTrue),
      ),
      verify: (b) => expect(b.unreadFor(null, UserRole.buyer), 0),
    );

    blocTest<NotificationsBloc, NotificationsState>(
      'abrir un aviso que no existe emite not_found con mensaje en español',
      build: _bloc,
      act: (b) => b.add(const NotificationOpened('no-existe')),
      expect: () => [
        isA<NotificationsState>()
            .having((s) => s.outcome?.action, 'action', NotificationAction.open)
            .having((s) => s.outcome?.result.code, 'code', 'not_found')
            .having(
              (s) => s.outcome?.result.message,
              'mensaje',
              'Ese aviso ya no está disponible.',
            ),
      ],
    );

    blocTest<NotificationsBloc, NotificationsState>(
      'una excepción del repositorio se convierte en server_error',
      build: () => _bloc(_BrokenRepo()),
      act: (b) => b.add(const NotificationOpened('n1')),
      expect: () => [
        isA<NotificationsState>()
            .having((s) => s.outcome?.result.code, 'code', 'server_error')
            .having(
              (s) => s.outcome?.result.isTransportError,
              'transporte',
              isTrue,
            ),
      ],
    );
  });

  group('NotificationsCubit (pantalla)', () {
    late TestServices s;

    setUp(() async {
      s = await makeServices();
      s.session.login(kDemoBuyerEmail, kDemoPassword);
    });

    blocTest<screen.NotificationsCubit, screen.NotificationsState>(
      'un aviso para el comprador aparece en su lista',
      build: () => screen.NotificationsCubit(
        notifications: s.notifications,
        session: s.session,
      ),
      act: (c) async {
        s.notifications.add(
          NotificationPushed(
            title: 'Mío',
            body: '',
            audience: 'user:${s.session.user!.id}',
          ),
        );
        await _settle();
      },
      expect: () => contains(
        isA<screen.NotificationsState>().having(
          (st) => st.items.first.title,
          'primero',
          'Mío',
        ),
      ),
    );

    blocTest<screen.NotificationsCubit, screen.NotificationsState>(
      'un aviso para otro usuario no cambia la lista del comprador',
      build: () => screen.NotificationsCubit(
        notifications: s.notifications,
        session: s.session,
      ),
      act: (c) async {
        s.notifications.add(
          const NotificationPushed(
            title: 'De otro',
            body: '',
            audience: 'user:otro',
          ),
        );
        await _settle();
      },
      verify: (c) =>
          expect(c.state.items.map((n) => n.title), isNot(contains('De otro'))),
    );
  });
}
