import 'package:biffy/core/constants/catalog_constants.dart';
import 'package:biffy/data/mock/seed_users.dart';
import 'package:biffy/features/buyer/notifications/notifications_cubit.dart';
import 'package:biffy/features/notifications/bloc/notifications_bloc.dart'
    hide NotificationsState;
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Deja que el Bloc procese los eventos pendientes (son asíncronos).
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late TestServices s;
  late NotificationsCubit c;

  setUp(() async {
    s = await makeServices();
    s.session.login(kDemoBuyerEmail, kDemoPassword);
    c = NotificationsCubit(notifications: s.notifications, session: s.session);
  });
  tearDown(() => c.close());

  /// Publica un aviso por el Bloc, como lo haría una pantalla.
  void push(String title, String audience) => s.notifications.add(
    NotificationPushed(title: title, body: '', audience: audience),
  );

  test('solo muestra los avisos del usuario y rol activos', () async {
    final id = s.session.user!.id;
    final before = c.state.items.length;
    push('Mío', 'user:$id');
    push('De otro', 'user:otro');
    push('Repartidores', 'couriers');
    await _settle();

    expect(c.state.items.length, before + 1);
    expect(c.state.items.first.title, 'Mío');
  });

  test('abrir uno y marcar todos baja el contador', () async {
    final id = s.session.user!.id;
    push('A', 'user:$id');
    push('B', 'user:$id');
    await _settle();
    final unread = c.state.unread;
    expect(unread, greaterThanOrEqualTo(2));

    c.open(c.state.items.first);
    await _settle();
    expect(c.state.unread, unread - 1);

    c.markAllRead();
    await _settle();
    expect(c.state.unread, 0);
  });

  test('un pedido entregado avisa al comprador en vivo', () async {
    final before = c.state.items.length;
    await deliverQbano(s);
    await _settle();
    expect(c.state.items.length, greaterThan(before));
    expect(c.state.items.map((n) => n.title), contains('Pedido entregado ✅'));
  });

  group('NotificationsCubit (bloc_test)', () {
    blocTest<NotificationsCubit, NotificationsState>(
      'un aviso para el usuario activo aparece primero',
      build: () => NotificationsCubit(
        notifications: s.notifications,
        session: s.session,
      ),
      act: (_) => push('Mío', 'user:${s.session.user!.id}'),
      expect: () => contains(
        isA<NotificationsState>().having(
          (st) => st.items.first.title,
          'primero',
          'Mío',
        ),
      ),
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'un aviso para otra cuenta no se muestra',
      build: () => NotificationsCubit(
        notifications: s.notifications,
        session: s.session,
      ),
      act: (_) => push('De otro', 'user:otro'),
      wait: Duration.zero,
      verify: (c) =>
          expect(c.state.items.map((n) => n.title), isNot(contains('De otro'))),
    );
  });
}
