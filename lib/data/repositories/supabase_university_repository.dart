import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/entities/university_status.dart';
import '../../domain/repositories/university_repository.dart';
import 'university_cache.dart';

/// Verificación universitaria con Supabase: RPC `verify_university` y
/// `confirm_university_verification`, Edge Function `send-university-code`
/// y lectura de `profiles`. La verificación la decide el servidor.
class SupabaseUniversityRepository implements UniversityRepository {
  /// Usa el cliente de Supabase indicado o el global.
  SupabaseUniversityRepository({sb.SupabaseClient? client})
    : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;
  final UniversityCache _cache = UniversityCache();

  /// Estado de la cuenta.
  @override
  UniversityStatus statusOf(String userId) => _cache.statusOf(userId);

  /// Emite cuando cambia la caché.
  @override
  Stream<void> get changes => _cache.changes;

  /// La verificación vive en el servidor.
  @override
  bool get isRemote => true;

  /// Reemplaza el estado en la caché.
  @override
  void setStatus(String userId, UniversityStatus status) =>
      _cache.setStatus(userId, status);

  /// Código pendiente (solo si no hay proveedor de correo).
  @override
  String? pendingCodeOf(String userId) => _cache.pendingCodeOf(userId);

  /// Guarda o descarta el código pendiente.
  @override
  void setPendingCode(String userId, String? code) =>
      _cache.setPendingCode(userId, code);

  /// Llama al RPC `verify_university`; sin red devuelve `network`.
  @override
  Future<UniversityResult> verify(String universityId, String email) async {
    try {
      final res = await _client.rpc(
        'verify_university',
        params: {
          'p_payload': {'university_id': universityId, 'email': email},
        },
      );
      final map = res is Map ? res : const {};
      return UniversityResult((map['result'] as String?) ?? 'rpc_error');
    } on Object {
      return const UniversityResult('network');
    }
  }

  /// Envía el código al correo institucional mediante la Edge Function.
  @override
  Future<UniversityResult> sendCode({
    required String userId,
    required String universityId,
    required String email,
    bool renewal = false,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'send-university-code',
        body: {
          'universityId': universityId,
          'email': email.trim().toLowerCase(),
          'mode': renewal ? 'renew' : 'initial',
        },
      );
      final map = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : const <String, dynamic>{};
      return UniversityResult(
        (map['result'] as String?) ?? 'rpc_error',
        demoCode: map['demoCode'] as String?,
      );
    } on Object {
      return const UniversityResult('rpc_error');
    }
  }

  /// Confirma el código del correo institucional con el RPC.
  @override
  Future<UniversityResult> confirmCode({
    required String userId,
    required String email,
    required String code,
  }) async {
    try {
      final res = await _client.rpc(
        'confirm_university_verification',
        params: {'p_email': email.trim().toLowerCase(), 'p_token': code.trim()},
      );
      final map = res is Map ? res : const {};
      return UniversityResult((map['result'] as String?) ?? 'rpc_error');
    } on Object {
      return const UniversityResult('rpc_error');
    }
  }

  /// Lee la verificación y su vencimiento de `profiles`.
  @override
  Future<UniversityResult> load(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select(
            'verified, university_id, university_email, '
            'university_status, university_expires_at',
          )
          .eq('id', userId)
          .maybeSingle();
      if (row == null) {
        return const UniversityResult(
          'ok',
          record: UniversityRecord(verified: false),
        );
      }
      return UniversityResult(
        'ok',
        record: UniversityRecord(
          verified: (row['verified'] as bool?) ?? false,
          universityId: row['university_id'] as String?,
          email: row['university_email'] as String?,
          status: row['university_status'] as String?,
          expiresAt: DateTime.tryParse(
            (row['university_expires_at'] as String?) ?? '',
          ),
        ),
      );
    } on Object {
      return const UniversityResult('network');
    }
  }

  /// Cierra el stream de cambios.
  void dispose() => _cache.dispose();
}
