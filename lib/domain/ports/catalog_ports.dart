import '../entities/catalog.dart';

/// Lo que el catálogo necesita saber de la sesión: el punto de entrega (fija
/// la regla de alcance) y cuándo cambia junto con el horario de demostración.
abstract interface class CatalogContextPort {
  /// Punto de entrega activo.
  DeliveryPoint get point;

  /// Emite cuando cambian el punto de entrega o el horario de demostración.
  Stream<void> get changes;
}
