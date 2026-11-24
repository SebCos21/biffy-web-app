import '../entities/app_notification.dart';
import '../notification_errors.dart' as errors;

/// Resultado de una operación de avisos, igual en modo demo y con servidor.
///
/// [code] es `ok`, `not_found`, `network` o `server_error`; [message] es el
/// texto en español listo para mostrar.
class NotificationResult {
  /// Crea el resultado con su código y, si aplica, el aviso afectado.
  const NotificationResult(this.code, {this.notification});

  /// Operación exitosa.
  const NotificationResult.ok([AppNotification? notification])
    : this('ok', notification: notification);

  /// Código de la operación (mismo vocabulario en demo y servidor).
  final String code;

  /// Aviso creado o actualizado, si aplica.
  final AppNotification? notification;

  /// `true` si la operación terminó bien.
  bool get ok => code == 'ok';

  /// Mensaje en español para mostrar; nunca expone el código crudo.
  String get message => errors.notificationErrorMessage(code);

  /// `true` si falló la conexión con el servidor.
  bool get isTransportError => errors.isNotificationTransportError(code);

  /// Representación corta para depurar.
  @override
  String toString() => 'NotificationResult($code)';
}

/// Datos de un aviso nuevo; el repositorio le asigna el id.
class NotificationDraft {
  /// Crea el borrador con su destinatario y hora de creación.
  const NotificationDraft({
    required this.title,
    required this.body,
    required this.audience,
    required this.createdAt,
    this.route,
  });

  /// Título corto del aviso.
  final String title;

  /// Texto del aviso.
  final String body;

  /// Destinatario: `all`, `user:<id>`, `business:<id>`, `couriers`…
  final String audience;

  /// Hora de creación según el reloj de la app.
  final DateTime createdAt;

  /// Ruta a la que lleva el aviso al tocarlo.
  final String? route;
}

/// Contrato de los avisos de la app. Guarda una caché en memoria que las
/// pantallas leen de forma síncrona y avisa por [changes] cuando cambia.
///
/// En demo todo vive en memoria; con Supabase los avisos personales se
/// guardan en la base y los que crea la base (0022) llegan por Realtime.
abstract interface class NotificationRepository {
  /// Todos los avisos conocidos, del más nuevo al más viejo (solo lectura).
  List<AppNotification> get all;

  /// Emite cada vez que cambia la caché.
  Stream<void> get changes;

  /// `true` si los avisos se guardan en un servidor.
  bool get isRemote;

  /// Agrega un aviso. La caché se actualiza antes de esperar a la red.
  Future<NotificationResult> push(NotificationDraft draft);

  /// Trae los avisos guardados del usuario y los une a la caché sin duplicar.
  Future<NotificationResult> load(String userId);

  /// Empieza a escuchar avisos nuevos o leídos del usuario (no-op en demo).
  /// Si ya escucha a ese usuario no hace nada; si escuchaba a otro, cambia.
  void watch(String userId);

  /// Deja de escuchar los avisos en vivo.
  void unwatch();

  /// Marca un aviso como leído (local y, si aplica, en el servidor).
  Future<NotificationResult> markRead(String id);
}
