import '../entities/user.dart';

/// Error de autenticación con mensaje para el usuario.
class AuthException implements Exception {
  /// Crea el error con un mensaje ya traducido a español.
  AuthException(this.message);

  /// Mensaje que ve el usuario.
  final String message;

  /// Muestra solo el mensaje, sin el tipo de excepción.
  @override
  String toString() => message;
}

/// Contrato de autenticación y datos de la cuenta.
///
/// La app depende de esta interfaz; las implementaciones (memoria y Supabase)
/// viven en `lib/data/repositories/`.
abstract class AuthRepository {
  /// Cuentas de demostración para el acceso rápido.
  List<AppUser> get demoAccounts;

  /// Inicia sesión de forma síncrona (solo modo demo).
  AppUser login(String email, String password);

  /// Registra una cuenta nueva y la devuelve (solo modo demo).
  AppUser register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String phone,
  });

  /// Usuario por id, si existe en la caché local.
  AppUser? byId(String id);

  /// Cuenta dueña del negocio indicado.
  AppUser? byBusiness(String businessId);

  /// `true` cuando la autenticación vive en un backend real.
  bool get isRemote;

  /// Inicia sesión contra el backend.
  Future<AppUser> signIn(String email, String password);

  /// Registra la cuenta y devuelve el usuario.
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String phone,
  });

  /// Cierra la sesión y limpia el estado guardado.
  Future<void> signOut();

  /// Recupera la sesión persistida (solo backend real).
  Future<AppUser?> restoreSession();

  /// Crea el negocio y sus sedes del usuario autenticado.
  Future<String?> registerBusiness(Map<String, dynamic> payload);

  /// Guarda nombre y teléfono del perfil en el backend.
  Future<void> saveProfile(String userId, {String? name, String? phone});
}
