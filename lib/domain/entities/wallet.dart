import 'user.dart';

/// Beneficio canjeable con Gotas (valores de demostración).
class Benefit {
  /// Crea un beneficio canjeable con sus datos de cupón.
  const Benefit(
    this.id,
    this.title,
    this.description,
    this.cost,
    this.kind, [
    this.amount = 0,
  ]);

  /// Identificador del beneficio.
  final String id;

  /// Nombre visible.
  final String title;

  /// Descripción corta.
  final String description;

  /// Costo en Gotas.
  final int cost;

  /// Tipo de cupón que entrega.
  final CouponKind kind;

  /// Valor del cupón en pesos (0 para envío gratis).
  final int amount;
}

/// Beneficios canjeables en modo demo (con Supabase se usan las cajas).
const kBenefits = [
  Benefit(
    'free-delivery',
    'Envío gratis',
    'Cupón para un pedido sin tarifa de entrega.',
    300,
    CouponKind.freeDelivery,
  ),
  Benefit(
    'off-5000',
    r'$5.000 de descuento',
    'Cupón aplicable a tu próximo pedido.',
    500,
    CouponKind.fixed,
    5000,
  ),
  Benefit(
    'off-10000',
    r'$10.000 de descuento',
    'Cupón aplicable a tu próximo pedido.',
    950,
    CouponKind.fixed,
    10000,
  ),
];
