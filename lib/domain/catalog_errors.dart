/// Operaciones del catálogo que pueden fallar; cada una tiene su mensaje.
enum CatalogAction {
  /// Crear o editar un plato.
  saveDish,

  /// Publicar u ocultar un plato (interruptor «Disponible»).
  availability,

  /// Eliminar (borrado lógico) un plato.
  deleteDish,

  /// Marcar o desmarcar un plato como agotado.
  soldOut,

  /// Pausar o reanudar las sedes de un negocio.
  pauseBusiness,

  /// Mostrar u ocultar la información nutricional.
  nutrition,

  /// Registrar un negocio con sus sedes.
  registerBusiness,

  /// Subir la foto de un plato.
  uploadPhoto,

  /// Volver a leer el catálogo.
  refresh,
}

/// Traduce el código de una operación del catálogo a un mensaje en español.
///
/// `forbidden` usa [deniedAction] (la acción que RLS rechazó); `network` usa
/// el texto de cada [action]. Nunca devuelve el código crudo.
String catalogErrorMessage(
  String code,
  CatalogAction action, {
  String? deniedAction,
}) => switch (code) {
  'ok' => 'Listo.',
  'forbidden' =>
    'No tienes permiso para ${deniedAction ?? _what(action)}. '
        'Solo puedes cambiar el catálogo de tu propio negocio.',
  'not_found' => 'Ese producto ya no está en el catálogo.',
  'network' => switch (action) {
    CatalogAction.saveDish =>
      'No pudimos guardar el producto. Revisa tu conexión.',
    CatalogAction.availability => 'No pudimos guardar el cambio.',
    CatalogAction.deleteDish => 'No pudimos eliminar el producto.',
    CatalogAction.soldOut => 'No pudimos guardar el cambio.',
    CatalogAction.pauseBusiness => 'No pudimos cambiar el estado.',
    CatalogAction.nutrition => 'No pudimos guardar el cambio.',
    CatalogAction.registerBusiness => 'No pudimos registrar el negocio.',
    CatalogAction.uploadPhoto => 'No pudimos subir la foto.',
    CatalogAction.refresh =>
      'Sin conexión · mostrando el menú guardado. Puede estar desactualizado.',
  },
  _ => 'Algo salió mal con el catálogo. Intenta de nuevo.',
};

/// Qué se intentaba hacer, para el mensaje de permiso denegado.
String _what(CatalogAction action) => switch (action) {
  CatalogAction.saveDish => 'editar el plato',
  CatalogAction.availability => 'cambiar la disponibilidad del plato',
  CatalogAction.deleteDish => 'eliminar el plato',
  CatalogAction.soldOut => 'cambiar el estado de agotado',
  CatalogAction.pauseBusiness => 'pausar la sede',
  CatalogAction.nutrition => 'cambiar la información nutricional',
  CatalogAction.registerBusiness => 'registrar el negocio',
  CatalogAction.uploadPhoto => 'subir la foto',
  CatalogAction.refresh => 'leer el catálogo',
};

/// `true` si el fallo fue de conexión con el servidor.
bool isCatalogTransportError(String code) => code == 'network';
