import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/models/order.dart';
import '../../../data/models/user.dart';
import '../../../domain/order_rules.dart';
import '../../catalog/bloc/catalog_bloc.dart';
import '../../notifications/bloc/notifications_bloc.dart';
import '../bloc/courier_cubit.dart';
import '../../../features/orders/bloc/orders_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../university/bloc/university_cubit.dart';
import '../offers/offer_widgets.dart';
import '../../../app/di/injection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Pantalla de inicio del repartidor con estado, ofertas y entrega en curso.
class CourierHomeScreen extends StatelessWidget {
  const CourierHomeScreen({super.key});

  /// Reúne ganancias, metas y ofertas disponibles del día.
  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthBloc>();
    final uniCubit = context.watch<UniversityCubit>();
    final verified = uniCubit.isVerifiedStudent(session.user?.id);
    final orders = context.watch<OrdersBloc>();
    final center = context.watch<NotificationsBloc>();
    final now = getIt<CatalogBloc>().now;
    final t = Theme.of(context).textTheme;
    final u = session.user!;
    final courier = context.watch<CourierCubit>();
    final st = courier.statusOf(u.id);
    final profile = st.profile!;
    final active = orders.activeForCourier(u.id);
    final today = orders
        .deliveredBy(u.id)
        .where((o) => o.deliveredAt != null && sameDay(o.deliveredAt!, now));
    final earnings = computeEarnings(today);
    final offers = orders.availableOffers(
      courierId: u.id,
      zone: st.zone,
      universityId: uniCubit.verifiedUniversityId(session.user?.id),
      vehicle: profile.vehicle,
    );
    final next = kCourierGoals.firstWhere(
      (g) => g.$1 > earnings.deliveries,
      orElse: () => kCourierGoals.last,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, ${profile.fullName.split(' ').first} 🛵',
                        style: t.headlineSmall,
                      ),
                      Text(
                        '${profile.vehicle.emoji} ${profile.vehicle.label}${profile.plate == null ? '' : ' · ${profile.plate}'}',
                        style: t.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Notificaciones',
                  icon: Badge(
                    isLabelVisible: center.unreadFor(u, UserRole.courier) > 0,
                    label: Text('${center.unreadFor(u, UserRole.courier)}'),
                    child: const Icon(Icons.notifications_none),
                  ),
                  onPressed: () => context.push('/notificaciones'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            BiffyCard(
              color: st.online
                  ? AppColors.success.withValues(alpha: 0.12)
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SwitchListTile(
                key: const Key('courier-online'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  st.online ? 'CONECTADO' : 'DESCONECTADO',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: st.online ? AppColors.success : null,
                  ),
                ),
                subtitle: Text(
                  st.online
                      ? 'Recibes ofertas de pedidos listos'
                      : 'Conéctate para ver ofertas',
                ),
                value: st.online,
                onChanged: (v) => courier.setOnline(v),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final z in CourierZone.values)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: z == CourierZone.general ? 8 : 0,
                      ),
                      child: SelectPill(
                        key: Key('zone-${z.name}'),
                        label: z == CourierZone.general
                            ? '🛵 General'
                            : '🎓 Campus${verified ? '' : ' 🔒'}',
                        selected: st.zone == z,
                        onTap: () {
                          final r = courier.setZone(z);
                          if (!r.ok) showSnack(context, r.message, error: true);
                        },
                      ),
                    ),
                  ),
              ],
            ),
            if (!verified)
              TextButton(
                onPressed: () => context.push('/campus'),
                child: const Text(
                  'Verificar universidad para desbloquear Campus',
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: BigNumber(
                    'Ganancias de hoy',
                    cop(earnings.net),
                    highlight: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BigNumber('Entregas de hoy', '${earnings.deliveries}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            BiffyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🏆 Meta del día: ${next.$1} entregas',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (earnings.deliveries / next.$1)
                        .clamp(0, 1)
                        .toDouble(),
                    color: AppColors.primary,
                    backgroundColor: context.palette.border,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${earnings.deliveries}/${next.$1} · bono de demostración ${cop(next.$2)} (no se liquida)',
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
            const SectionHeader('Demanda cerca de ti'),
            DemandMap(
              labels: st.zone == CourierZone.campus
                  ? const ['Plazoleta', 'Biblioteca', 'Edificio D']
                  : const ['Campus Icesi', 'Pance', 'Chapinero'],
            ),
            if (active != null) ...[
              const SectionHeader('Entrega en curso'),
              BiffyCard(
                key: const Key('active-delivery'),
                border: Border.all(color: AppColors.primary, width: 2),
                onTap: () => context.go(
                  active.status == OrderStatus.ready
                      ? '/repartidor/recogida/${active.id}'
                      : '/repartidor/entrega/${active.id}',
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${active.id} · ${active.restaurantName}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            active.status == OrderStatus.ready
                                ? 'Ve a recoger el pedido'
                                : 'Entrega a ${active.buyerName}',
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'Continuar',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ],
            SectionHeader(
              'Pedidos disponibles${st.online ? ' (${offers.length})' : ''}',
            ),
            if (!st.online)
              EmptyState(
                emoji: '😴',
                title: 'Estás desconectado',
                body: 'Conéctate para recibir ofertas.',
                actionLabel: 'Conectarme',
                onAction: () => courier.setOnline(true),
              )
            else if (active != null)
              Text(
                'Termina tu entrega actual para aceptar otra oferta.',
                style: t.bodySmall,
              )
            else if (offers.isEmpty)
              EmptyState(
                emoji: '📭',
                title: 'No hay ofertas en este momento',
                body:
                    'Las ofertas aparecen cuando un restaurante marca un pedido como listo.',
                actionLabel: st.zone == CourierZone.campus
                    ? 'Cambiar a General'
                    : 'Ver modo Campus',
                onAction: () {
                  final r = courier.setZone(
                    st.zone == CourierZone.campus
                        ? CourierZone.general
                        : CourierZone.campus,
                  );
                  if (!r.ok) showSnack(context, r.message, error: true);
                },
              )
            else
              for (final o in offers) OfferCard(order: o),
          ],
        ),
      ),
    );
  }
}
