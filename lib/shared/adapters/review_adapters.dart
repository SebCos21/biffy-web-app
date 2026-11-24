import '../../domain/entities/order.dart';
import '../../domain/ports/review_ports.dart';
import '../../domain/usecases/catalog/catalog_usecases.dart';
import '../../domain/usecases/notifications/notification_usecases.dart';

/// Conecta el puerto de promedio de sede con los casos de uso del catálogo.
class CatalogRatingAdapter implements BranchRatingPort {
  /// Recibe los casos de uso del catálogo.
  CatalogRatingAdapter(this._catalog);
  final CatalogUseCases _catalog;

  /// Guarda el promedio en la sede del catálogo.
  @override
  void setRestaurantRating(String restaurantId, double rating) =>
      _catalog.setRestaurantRating(restaurantId, rating);
}

/// Avisa al restaurante de una calificación (solo en modo demo).
class LocalReviewNotifier implements ReviewNotifier {
  /// Recibe el caso de uso de avisos y el catálogo para saber el negocio.
  LocalReviewNotifier(this._push, this._catalog);
  final PushNotification _push;
  final CatalogQueries _catalog;

  /// Crea el aviso «Nueva calificación» para el negocio del pedido.
  @override
  void rated(Order order, int stars) {
    final business = _catalog.restaurantById(order.restaurantId)?.businessId;
    _push(
      title: 'Nueva calificación ⭐',
      body: '${order.buyerName} calificó ${order.id} con $stars de 5.',
      audience: 'business:$business',
      route: '/negocio/pedidos',
    );
  }
}

/// Con Supabase el aviso lo crea la base (trigger de 0022): aquí no se hace nada.
class ServerReviewNotifier implements ReviewNotifier {
  /// No necesita dependencias.
  const ServerReviewNotifier();

  /// La base ya avisó al restaurante.
  @override
  void rated(Order order, int stars) {}
}
