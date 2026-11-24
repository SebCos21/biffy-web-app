import '../../domain/entities/university_status.dart';
import '../../domain/repositories/university_repository.dart';
import 'university_cache.dart';

/// Verificación universitaria del modo demo: el código siempre es 123456 y se
/// muestra en la app; nada sale a la red.
class InMemoryUniversityRepository implements UniversityRepository {
  final UniversityCache _cache = UniversityCache();
  final Map<String, String> _codes = {};

  /// Estado de la cuenta.
  @override
  UniversityStatus statusOf(String userId) => _cache.statusOf(userId);

  /// Emite cuando cambia la caché.
  @override
  Stream<void> get changes => _cache.changes;

  /// En demo no hay servidor.
  @override
  bool get isRemote => false;

  /// Reemplaza el estado en memoria.
  @override
  void setStatus(String userId, UniversityStatus status) =>
      _cache.setStatus(userId, status);

  /// Código pendiente.
  @override
  String? pendingCodeOf(String userId) => _cache.pendingCodeOf(userId);

  /// Guarda o descarta el código pendiente.
  @override
  void setPendingCode(String userId, String? code) =>
      _cache.setPendingCode(userId, code);

  /// En demo la verificación es local: no hay RPC.
  @override
  Future<UniversityResult> verify(String universityId, String email) async =>
      const UniversityResult('ok');

  /// En demo el código siempre es 123456 y se devuelve para mostrarlo.
  @override
  Future<UniversityResult> sendCode({
    required String userId,
    required String universityId,
    required String email,
    bool renewal = false,
  }) async {
    _codes[userId] = '123456';
    return const UniversityResult('ok', demoCode: '123456');
  }

  /// Valida el código de demostración.
  @override
  Future<UniversityResult> confirmCode({
    required String userId,
    required String email,
    required String code,
  }) async {
    if (_codes[userId] != code.trim()) {
      return const UniversityResult('invalid_token');
    }
    _codes.remove(userId);
    return const UniversityResult('ok');
  }

  /// En demo no hay verificación guardada que leer.
  @override
  Future<UniversityResult> load(String userId) async =>
      const UniversityResult('ok');

  /// Cierra el stream de cambios.
  void dispose() => _cache.dispose();
}
