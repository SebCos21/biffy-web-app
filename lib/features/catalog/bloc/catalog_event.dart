part of 'catalog_bloc.dart';

/// Eventos del catálogo: la UI solo despacha estos.
///
/// Cada evento lleva su propio resultado: [CatalogBloc.request] lo despacha y
/// espera a que el manejador lo complete.
sealed class CatalogEvent {
  /// Crea el evento con su resultado pendiente.
  CatalogEvent();

  final Completer<CatalogResult> _done = Completer<CatalogResult>();

  /// Resultado de la operación (lo completa el Bloc).
  Future<CatalogResult> get result => _done.future;

  /// Completa el resultado una sola vez.
  void _complete(CatalogResult r) {
    if (!_done.isCompleted) _done.complete(r);
  }
}

/// Interno: cambió el repositorio o el punto de entrega.
final class CatalogChanged extends CatalogEvent {
  /// Crea el evento de refresco.
  CatalogChanged();
}

/// Volver a leer el catálogo (botón «Reintentar» sin conexión).
final class CatalogRefreshRequested extends CatalogEvent {
  /// Crea el evento.
  CatalogRefreshRequested();
}

/// Crear o editar un plato.
final class DishSaved extends CatalogEvent {
  /// Crea el evento con el plato a guardar.
  DishSaved(this.dish);

  /// Plato a guardar.
  final Dish dish;
}

/// Publicar u ocultar un plato (se revierte si la base no lo guarda).
final class DishAvailabilityChanged extends CatalogEvent {
  /// Crea el evento con el plato y el nuevo estado.
  DishAvailabilityChanged(this.dish, this.active);

  /// Plato afectado.
  final Dish dish;

  /// `true` para publicarlo.
  final bool active;
}

/// Eliminar un plato.
final class DishDeleted extends CatalogEvent {
  /// Crea el evento con el id del plato.
  DishDeleted(this.dishId);

  /// Id del plato a eliminar.
  final String dishId;
}

/// Marcar o desmarcar un plato como agotado.
final class DishSoldOutChanged extends CatalogEvent {
  /// Crea el evento con el plato y el nuevo estado.
  DishSoldOutChanged(this.dish, this.soldOut);

  /// Plato afectado.
  final Dish dish;

  /// `true` para marcarlo agotado.
  final bool soldOut;
}

/// Pausar o reanudar todas las sedes de un negocio.
final class BusinessPauseChanged extends CatalogEvent {
  /// Crea el evento con el negocio y el nuevo estado.
  BusinessPauseChanged(this.businessId, this.paused);

  /// Negocio afectado.
  final String businessId;

  /// `true` para pausar.
  final bool paused;
}

/// Mostrar u ocultar la información nutricional de un negocio.
final class NutritionInfoChanged extends CatalogEvent {
  /// Crea el evento con el negocio y el valor.
  NutritionInfoChanged(this.businessId, this.value);

  /// Negocio afectado.
  final String businessId;

  /// `true` para mostrarla.
  final bool value;
}

/// Registrar un negocio con sus sedes.
final class BusinessRegistered extends CatalogEvent {
  /// Crea el evento con el negocio y sus sedes.
  BusinessRegistered(this.business, this.branches);

  /// Negocio nuevo.
  final Business business;

  /// Sedes del negocio.
  final List<Restaurant> branches;
}

/// Subir la foto de un plato (la URL llega en el resultado).
final class DishPhotoUploaded extends CatalogEvent {
  /// Crea el evento con el negocio y los bytes de la foto.
  DishPhotoUploaded({required this.businessId, required this.bytes});

  /// Negocio dueño de la carpeta.
  final String businessId;

  /// Imagen a subir.
  final Uint8List bytes;
}
