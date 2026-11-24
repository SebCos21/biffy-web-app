import 'entities/app_notification.dart';
import 'entities/user.dart';

/// `true` si el aviso le corresponde al usuario con el rol indicado.
///
/// Audiencias: `all` (todos), `guest` (sin sesión), `user:<id>` (comprador),
/// `couriers` / `courier:<id>` (repartidores) y `business:<id>` (restaurante).
bool isNotificationFor(AppNotification n, AppUser? user, UserRole role) {
  if (n.audience == 'all') return true;
  if (user == null) return n.audience == 'guest';
  return switch (role) {
    UserRole.buyer => n.audience == 'user:${user.id}',
    UserRole.courier =>
      n.audience == 'couriers' || n.audience == 'courier:${user.id}',
    UserRole.restaurant =>
      user.businessId != null && n.audience == 'business:${user.businessId}',
  };
}

/// Avisos que puede ver el usuario según su rol, en el orden recibido.
List<AppNotification> visibleNotifications(
  Iterable<AppNotification> all,
  AppUser? user,
  UserRole role,
) => all.where((n) => isNotificationFor(n, user, role)).toList();

/// Cantidad de avisos visibles que siguen sin leer.
int unreadNotifications(
  Iterable<AppNotification> all,
  AppUser? user,
  UserRole role,
) => visibleNotifications(all, user, role).where((n) => !n.read).length;
