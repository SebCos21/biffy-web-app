import 'package:biffy/core/utils/clock.dart';
import 'package:biffy/data/models/app_notification.dart';
import 'package:biffy/data/models/user.dart';
import 'package:biffy/data/repositories/in_memory_notification_repository.dart';
import 'package:biffy/data/repositories/notification_cache.dart';
import 'package:biffy/data/repositories/supabase_notification_repository.dart';
import 'package:biffy/domain/repositories/notification_repository.dart';
import 'package:biffy/domain/usecases/notifications/notification_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositorio en memoria que además registra qué ids se marcaron como
/// leídos (hace el papel del backend en estas pruebas).
class _RecordingRepo extends InMemoryNotificationRepository {
  final read = <String>[];

  @override
  Future<NotificationResult> markRead(String id) {
    read.add(id);
    return super.markRead(id);
  }
}

/// Pruebas de avisos: creación, carga sin duplicados, lectura y visibilidad.
///
/// Antes probaban `NotificationCenter` (ChangeNotifier); ahora prueban la
/// misma conducta en la caché, el repositorio en memoria y los casos de uso.
void main() {
  final clock = Clock.fixed(DateTime(2026, 1, 1, 12));

  /// Crea un usuario de prueba con el rol indicado.
  AppUser user(UserRole role, {String id = 'u1', String? businessId}) =>
      AppUser(
        id: id,
        name: 'Prueba',
        email: 'prueba@biffy.co',
        role: role,
        businessId: businessId,
      );

  /// Casos de uso sobre un repositorio nuevo.
  NotificationUseCases useCases([NotificationRepository? repo]) =>
      NotificationUseCases(
        repo: repo ?? InMemoryNotificationRepository(),
        clock: clock,
      );

  group('Avisos', () {
    test('push guarda el aviso con su audiencia y hora del reloj', () async {
      final uc = useCases();

      final r = await uc.push(
        title: 'Hola',
        body: 'Mundo',
        audience: 'user:u1',
      );

      expect(r.ok, isTrue);
      expect(uc.queries.all.single.title, 'Hola');
      expect(uc.queries.all.single.audience, 'user:u1');
      expect(uc.queries.all.single.createdAt, DateTime(2026, 1, 1, 12));
    });

    test('la caché queda actualizada antes del primer await', () {
      final uc = useCases();
      uc.push(title: 'Ya', body: '', audience: 'all');
      expect(uc.queries.all.single.title, 'Ya');
    });

    test('merge no duplica ids y ordena de más nueva a más vieja', () {
      final cache = NotificationCache()
        ..merge([
          AppNotification(
            id: 'b',
            title: 'Vieja',
            body: '',
            audience: 'all',
            createdAt: DateTime(2026, 1, 1),
          ),
          AppNotification(
            id: 'a',
            title: 'Nueva',
            body: '',
            audience: 'all',
            createdAt: DateTime(2026, 1, 2),
          ),
        ])
        ..merge([
          AppNotification(
            id: 'a',
            title: 'Duplicada',
            body: '',
            audience: 'all',
            createdAt: DateTime(2026, 1, 2),
          ),
        ]);

      expect(cache.all, hasLength(2));
      expect(cache.all.first.id, 'a');
      expect(cache.all.last.id, 'b');
    });

    test('markRead marca el aviso y avisa al backend con el id', () async {
      final repo = _RecordingRepo();
      final uc = useCases(repo);
      await uc.push(title: 't', body: 'b', audience: 'all');

      final id = uc.queries.all.single.id;
      final r = await uc.markRead(id);

      expect(r.ok, isTrue);
      expect(uc.queries.all.single.read, isTrue);
      expect(repo.read, [id]);
    });

    test(
      'markRead de un aviso inexistente devuelve not_found en español',
      () async {
        final r = await useCases().markRead('no-existe');
        expect(r.ok, isFalse);
        expect(r.code, 'not_found');
        expect(r.message, 'Ese aviso ya no está disponible.');
      },
    );

    test('visibleFor filtra por rol', () async {
      final uc = useCases();
      await uc.push(title: 'global', body: '', audience: 'all');
      await uc.push(title: 'mío', body: '', audience: 'user:u1');
      await uc.push(title: 'repartidores', body: '', audience: 'couriers');
      await uc.push(title: 'negocio', body: '', audience: 'business:b1');

      final buyer = user(UserRole.buyer);
      final courier = user(UserRole.courier, id: 'u2');
      final restaurant = user(UserRole.restaurant, id: 'u3', businessId: 'b1');

      expect(
        uc.queries.visibleFor(buyer, UserRole.buyer).map((n) => n.title),
        containsAll(['global', 'mío']),
      );
      expect(
        uc.queries.visibleFor(courier, UserRole.courier).map((n) => n.title),
        containsAll(['global', 'repartidores']),
      );
      expect(
        uc.queries
            .visibleFor(restaurant, UserRole.restaurant)
            .map((n) => n.title),
        containsAll(['global', 'negocio']),
      );
    });

    test('sin sesión solo ve las globales', () async {
      final uc = useCases();
      await uc.push(title: 'global', body: '', audience: 'all');
      await uc.push(title: 'mío', body: '', audience: 'user:u1');

      expect(
        uc.queries.visibleFor(null, UserRole.buyer).single.title,
        'global',
      );
    });

    test('unreadFor cuenta solo las visibles sin leer', () async {
      final uc = useCases();
      await uc.push(title: 'a', body: '', audience: 'all');
      await uc.push(title: 'b', body: '', audience: 'user:u1');
      await uc.push(title: 'c', body: '', audience: 'couriers');

      final buyer = user(UserRole.buyer);
      expect(uc.queries.unreadFor(buyer, UserRole.buyer), 2);

      await uc.markAllRead(buyer, UserRole.buyer);
      expect(uc.queries.unreadFor(buyer, UserRole.buyer), 0);
    });

    test('upsert agrega el aviso de Realtime una sola vez', () {
      final cache = NotificationCache();
      AppNotification aviso({bool read = false}) => AppNotification(
        id: '7d1c0e9a-0000-4000-8000-000000000001',
        title: 'Pedido en camino 🛵',
        body: 'Repa va en camino con tu pedido BF-2041.',
        audience: 'user:u1',
        createdAt: DateTime(2026, 1, 1, 12, 5),
        route: '/pedido/BF-2041',
        read: read,
      );

      cache.upsert(aviso());
      cache.upsert(aviso());
      expect(cache.all, hasLength(1));
      expect(cache.all.single.read, isFalse);

      cache.upsert(aviso(read: true));
      expect(cache.all.single.read, isTrue);
    });

    test('marcar todas como leídas avisa al backend de cada una', () async {
      final repo = _RecordingRepo();
      final uc = useCases(repo);
      final buyer = user(UserRole.buyer);
      await uc.push(title: 'A', body: '', audience: 'user:u1');
      await uc.push(title: 'B', body: '', audience: 'user:u1');
      await uc.push(title: 'Otro', body: '', audience: 'user:u2');

      await uc.markAllRead(buyer, UserRole.buyer);
      expect(repo.read, hasLength(2));
      await uc.markAllRead(buyer, UserRole.buyer);
      expect(repo.read, hasLength(2));
    });

    test('los avisos de la base quedan en hora local', () {
      final n = SupabaseNotificationRepository.notificationFromRow({
        'id': '7d1c0e9a-0000-4000-8000-000000000002',
        'title': 'Pedido entregado ✅',
        'audience': 'user:u1',
        'created_at': '2026-11-10T01:30:00+00:00',
        'read_at': null,
      });
      expect(n.createdAt.isUtc, isFalse);
      expect(n.createdAt, DateTime.utc(2026, 11, 10, 1, 30).toLocal());
      expect(n.read, isFalse);
    });
  });
}
