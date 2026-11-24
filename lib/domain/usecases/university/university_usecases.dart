import '../../../core/constants/catalog_constants.dart';
import '../../../core/utils/clock.dart';
import '../../entities/university_status.dart';
import '../../repositories/university_repository.dart';
import '../../university_errors.dart';
import '../notifications/notification_usecases.dart';
import '../preferences/preferences_usecases.dart';

/// Correo con forma válida (algo@dominio.tld).
final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Normaliza el correo (sin espacios, en minúsculas).
String _normalize(String email) => email.trim().toLowerCase();

/// Lecturas síncronas de la verificación. Sin sesión (`null`) no hay nada.
class UniversityQueries {
  /// Recibe el repositorio, las preferencias y el reloj.
  const UniversityQueries(this._repo, this._prefs, this._clock);
  final UniversityRepository _repo;
  final PreferencesQueries _prefs;
  final Clock _clock;

  /// Estado de la cuenta.
  UniversityStatus statusOf(String? userId) =>
      userId == null ? const UniversityStatus() : _repo.statusOf(userId);

  /// `true` si la verificación está activa y no vencida.
  bool isVerifiedStudent(String? userId) =>
      statusOf(userId).isActiveAt(_clock.now());

  /// Universidad verificada, si la verificación sigue vigente.
  String? verifiedUniversityId(String? userId) =>
      isVerifiedStudent(userId) ? statusOf(userId).verifiedUniversityId : null;

  /// Fecha en la que vence la verificación.
  DateTime? expiresAt(String? userId) => statusOf(userId).expiresAt;

  /// Correo institucional guardado.
  String? emailOf(String? userId) => statusOf(userId).email;

  /// Universidad verificada o, si no, la elegida en preferencias.
  String? universityIdOf(String? userId) =>
      statusOf(userId).verifiedUniversityId ??
      _prefs.prefsOf(userId).universityId;

  /// Código de demostración pendiente (sin proveedor de correo).
  String? pendingCodeOf(String? userId) =>
      userId == null ? null : _repo.pendingCodeOf(userId);
}

/// Deja la cuenta verificada 30 días, fija la universidad en preferencias y
/// avisa al usuario.
class _MarkVerified {
  const _MarkVerified(this._repo, this._prefs, this._push, this._clock);
  final UniversityRepository _repo;
  final SetPreferredUniversity _prefs;
  final PushNotification _push;
  final Clock _clock;

  void call(
    String userId,
    String universityId,
    String email, {
    required bool simulated,
  }) {
    _repo.setStatus(
      userId,
      UniversityStatus(
        verifiedUniversityId: universityId,
        email: email,
        expiresAt: _clock.now().add(const Duration(days: 30)),
      ),
    );
    _prefs(userId, universityId);
    final name = universityById(universityId)?.name ?? 'tu universidad';
    _push(
      title: simulated
          ? 'Universidad verificada (simulación) 🎓'
          : 'Universidad verificada 🎓',
      body: 'Ya ves descuentos y secciones de $name.',
      audience: 'user:$userId',
      route: '/campus',
    );
  }
}

/// Verifica el correo universitario: en demo por dominio (simulado); con
/// servidor con el RPC `verify_university`.
class VerifyUniversity {
  const VerifyUniversity._(this._repo, this._mark);
  final UniversityRepository _repo;
  final _MarkVerified _mark;

  /// Devuelve el resultado; si es `ok` la cuenta queda verificada.
  Future<VerifyResult> call(
    String? userId,
    String universityId,
    String email,
  ) async {
    if (userId == null) return VerifyResult.notLoggedIn;
    final e = _normalize(email);
    if (!_emailPattern.hasMatch(e)) return VerifyResult.invalidEmail;

    if (!_repo.isRemote) {
      final uni = universityById(universityId);
      if (uni == null || !e.endsWith('@${uni.domain}')) {
        return VerifyResult.domainMismatch;
      }
      _mark(userId, uni.id, e, simulated: true);
      return VerifyResult.ok;
    }

    final result = await _repo.verify(universityId, e);
    switch (result.code) {
      case 'ok':
        _mark(userId, universityId, e, simulated: false);
        return VerifyResult.ok;
      case 'domain_mismatch':
        return VerifyResult.domainMismatch;
      case 'unknown_university':
        return VerifyResult.unknownUniversity;
      case 'not_authenticated':
        return VerifyResult.notAuthenticated;
      case 'token_required':
        return VerifyResult.tokenRequired;
      default:
        return VerifyResult.rpcError;
    }
  }
}

/// Envía el código al correo institucional.
class SendUniversityCode {
  /// Recibe el repositorio.
  const SendUniversityCode(this._repo);
  final UniversityRepository _repo;

  /// Valida correo y dominio y pide el código; en demo lo deja pendiente.
  Future<VerifyResult> call(
    String? userId,
    String universityId,
    String email, {
    bool renewal = false,
  }) async {
    if (userId == null) return VerifyResult.notLoggedIn;
    final e = _normalize(email);
    if (!_emailPattern.hasMatch(e)) return VerifyResult.invalidEmail;
    final uni = universityById(universityId);
    if (uni == null) return VerifyResult.unknownUniversity;
    if (!e.endsWith('@${uni.domain}')) return VerifyResult.domainMismatch;

    final res = await _repo.sendCode(
      userId: userId,
      universityId: universityId,
      email: e,
      renewal: renewal,
    );
    _repo.setPendingCode(userId, res.demoCode);
    return switch (res.code) {
      'ok' => VerifyResult.codeSent,
      'rate_limited' => VerifyResult.rateLimited,
      'domain_mismatch' => VerifyResult.domainMismatch,
      'unknown_university' => VerifyResult.unknownUniversity,
      'not_authenticated' => VerifyResult.notAuthenticated,
      _ => VerifyResult.rpcError,
    };
  }
}

/// Confirma el código recibido y activa Campus por 30 días.
class ConfirmUniversityCode {
  const ConfirmUniversityCode._(this._repo, this._mark);
  final UniversityRepository _repo;
  final _MarkVerified _mark;

  /// Devuelve `ok` si el código es correcto (o la verificación ya estaba).
  Future<VerifyResult> call(
    String? userId, {
    required String universityId,
    required String email,
    required String code,
  }) async {
    if (userId == null) return VerifyResult.notLoggedIn;
    final e = _normalize(email);
    if (!_emailPattern.hasMatch(e)) return VerifyResult.invalidEmail;

    final result = await _repo.confirmCode(
      userId: userId,
      email: e,
      code: code,
    );
    switch (result.code) {
      case 'ok':
      case 'already_active':
        _repo.setPendingCode(userId, null);
        _mark(userId, universityId, e, simulated: !_repo.isRemote);
        return VerifyResult.ok;
      case 'invalid_token':
        return VerifyResult.invalidToken;
      case 'expired_token':
        return VerifyResult.expiredToken;
      case 'too_many_attempts':
        return VerifyResult.tooManyAttempts;
      case 'not_found':
        return VerifyResult.notFound;
      case 'rate_limited':
        return VerifyResult.rateLimited;
      case 'not_authenticated':
        return VerifyResult.notAuthenticated;
      default:
        return VerifyResult.rpcError;
    }
  }
}

/// Elige la universidad en preferencias; en demo descarta una verificación de
/// otra universidad (con servidor la verificación es suya).
class ChooseUniversity {
  /// Recibe el repositorio y el cambio de preferencias.
  const ChooseUniversity(this._repo, this._prefs);
  final UniversityRepository _repo;
  final SetPreferredUniversity _prefs;

  /// Fija [universityId] (o la quita con `null`).
  void call(String? userId, String? universityId) {
    _prefs(userId, universityId);
    if (userId == null || _repo.isRemote) return;
    final s = _repo.statusOf(userId);
    if (s.verifiedUniversityId != null &&
        s.verifiedUniversityId != universityId) {
      _repo.setStatus(userId, s.copyWith(clearVerified: true));
    }
  }
}

/// Trae la verificación guardada al iniciar sesión. Vencida o revocada
/// conserva el correo para revalidar, pero Campus queda deshabilitado.
class LoadVerification {
  const LoadVerification._(this._repo, this._prefs, this._clock);
  final UniversityRepository _repo;
  final SetPreferredUniversity _prefs;
  final Clock _clock;

  /// Carga y aplica la verificación de [userId]; no hace nada en demo.
  Future<UniversityResult> call(String userId) async {
    final result = await _repo.load(userId);
    final v = result.record;
    if (!result.ok || v == null) return result;
    final expired = v.expiresAt != null && !v.expiresAt!.isAfter(_clock.now());
    if (v.verified && v.universityId != null && !expired) {
      _repo.setStatus(
        userId,
        UniversityStatus(
          verifiedUniversityId: v.universityId,
          email: v.email,
          expiresAt: v.expiresAt,
        ),
      );
      _prefs(userId, v.universityId);
    } else if (v.universityId != null) {
      _repo.setStatus(
        userId,
        UniversityStatus(email: v.email, expiresAt: v.expiresAt),
      );
      _prefs(userId, v.universityId);
    }
    return result;
  }
}

/// Todos los casos de uso de la verificación universitaria, ya cableados.
class UniversityUseCases {
  /// Ensambla los casos de uso sobre el repositorio, preferencias, avisos y
  /// reloj.
  factory UniversityUseCases({
    required UniversityRepository repo,
    required PreferencesUseCases preferences,
    required PushNotification push,
    required Clock clock,
  }) {
    final mark = _MarkVerified(repo, preferences.setUniversity, push, clock);
    return UniversityUseCases._(
      repo,
      UniversityQueries(repo, preferences.queries, clock),
      VerifyUniversity._(repo, mark),
      SendUniversityCode(repo),
      ConfirmUniversityCode._(repo, mark),
      ChooseUniversity(repo, preferences.setUniversity),
      LoadVerification._(repo, preferences.setUniversity, clock),
    );
  }

  UniversityUseCases._(
    this.repo,
    this.queries,
    this.verify,
    this.sendCode,
    this.confirmCode,
    this.choose,
    this.load,
  );

  /// Repositorio (en memoria o Supabase).
  final UniversityRepository repo;

  /// Lecturas.
  final UniversityQueries queries;

  /// Verificar por dominio o RPC.
  final VerifyUniversity verify;

  /// Enviar el código al correo.
  final SendUniversityCode sendCode;

  /// Confirmar el código.
  final ConfirmUniversityCode confirmCode;

  /// Elegir la universidad.
  final ChooseUniversity choose;

  /// Cargar del servidor.
  final LoadVerification load;
}
