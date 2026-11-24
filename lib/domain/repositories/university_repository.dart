import '../entities/university_status.dart';

/// Respuesta de una llamada de verificación al servidor (RPC o función).
///
/// [code] usa el vocabulario del servidor (`ok`, `domain_mismatch`,
/// `invalid_token`, `rate_limited`, `network`…); los casos de uso lo
/// traducen a `VerifyResult` con su mensaje en español.
class UniversityResult {
  /// Crea el resultado con su código y, en demo, el código visible.
  const UniversityResult(this.code, {this.demoCode, this.record});

  /// Código devuelto por el servidor.
  final String code;

  /// Código de verificación visible en modo demo (sin proveedor de correo).
  final String? demoCode;

  /// Verificación guardada (solo al cargar).
  final UniversityRecord? record;

  /// `true` si terminó bien.
  bool get ok => code == 'ok';

  /// Representación corta para depurar.
  @override
  String toString() => 'UniversityResult($code)';
}

/// Contrato de la verificación universitaria por cuenta: caché síncrona del
/// estado, código pendiente y llamadas al servidor.
abstract interface class UniversityRepository {
  /// Estado de la cuenta (vacío si nunca verificó).
  UniversityStatus statusOf(String userId);

  /// Emite cada vez que cambia la caché.
  Stream<void> get changes;

  /// `true` si la verificación la decide un servidor.
  bool get isRemote;

  /// Reemplaza el estado de la cuenta en la caché.
  void setStatus(String userId, UniversityStatus status);

  /// Código de demostración pendiente de la cuenta, si hay.
  String? pendingCodeOf(String userId);

  /// Guarda o descarta el código de demostración pendiente.
  void setPendingCode(String userId, String? code);

  /// Verifica el correo con el RPC `verify_university` (demo: `ok` sin red).
  Future<UniversityResult> verify(String universityId, String email);

  /// Envía el código al correo institucional.
  Future<UniversityResult> sendCode({
    required String userId,
    required String universityId,
    required String email,
    bool renewal = false,
  });

  /// Confirma el código recibido.
  Future<UniversityResult> confirmCode({
    required String userId,
    required String email,
    required String code,
  });

  /// Lee la verificación guardada en el servidor (demo: sin registro).
  Future<UniversityResult> load(String userId);
}
