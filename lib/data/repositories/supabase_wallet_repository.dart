import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/entities/user.dart';
import '../../domain/repositories/wallet_repository.dart';
import 'wallet_cache.dart';

/// Billetera con Supabase: el saldo es `profiles.gotas` (suma del ledger, lo
/// mueve la base) y los cupones vienen de `user_coupons`. La app solo los lee
/// y mantiene una caché para las pantallas.
class SupabaseWalletRepository implements WalletRepository {
  /// Usa el cliente de Supabase indicado o el global.
  SupabaseWalletRepository({sb.SupabaseClient? client})
    : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;
  final WalletCache _cache = WalletCache();

  /// Saldo de la cuenta (última lectura del servidor).
  @override
  int balanceOf(String userId) => _cache.balanceOf(userId);

  /// Movimientos locales de la cuenta.
  @override
  List<GotasEntry> historyOf(String userId) => _cache.historyOf(userId);

  /// Cupones de la cuenta.
  @override
  List<Coupon> couponsOf(String userId) => _cache.couponsOf(userId);

  /// Emite cuando cambia la caché.
  @override
  Stream<void> get changes => _cache.changes;

  /// El saldo y los cupones viven en el servidor.
  @override
  bool get isRemote => true;

  /// Movimiento local (bienvenida o encuesta de la sesión); el saldo real lo
  /// fija la próxima lectura del servidor.
  @override
  WalletResult credit(String userId, int amount, String reason, DateTime at) =>
      _cache.credit(userId, amount, reason, at);

  /// Cupón local; los del servidor llegan con [load].
  @override
  WalletResult addCoupon(
    String userId, {
    required String title,
    required CouponKind kind,
    int amount = 0,
  }) => _cache.addCoupon(userId, title: title, kind: kind, amount: amount);

  /// Cambia el estado del cupón en la caché (la base lo marca al pedir).
  @override
  WalletResult setCouponUsed(String userId, String couponId, bool used) =>
      _cache.setCouponUsed(userId, couponId, used);

  /// Lee `profiles.gotas`; sin red conserva el último saldo y da `network`.
  @override
  Future<WalletResult> syncBalance(String userId) async {
    final balance = await _balance(userId);
    if (balance == null) return const WalletResult('network');
    _cache.setBalance(userId, balance);
    return const WalletResult.ok();
  }

  /// Trae saldo y cupones; si alguna lectura falla conserva la caché.
  @override
  Future<WalletResult> load(String userId) async {
    final balanceF = _balance(userId);
    final couponsF = _coupons(userId);
    final balance = await balanceF;
    final coupons = await couponsF;
    if (balance != null) _cache.setBalance(userId, balance);
    if (coupons != null) _cache.setCoupons(userId, coupons);
    return balance == null || coupons == null
        ? const WalletResult('network')
        : const WalletResult.ok();
  }

  /// Con servidor no hay datos de demostración; solo toca la caché.
  @override
  void insertSeed(
    String userId, {
    int? gotas,
    List<GotasEntry> history = const [],
  }) => _cache.seed(userId, gotas: gotas, history: history);

  /// Saldo en `profiles.gotas`, o `null` si falla la red.
  Future<int?> _balance(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select('gotas')
          .eq('id', userId)
          .maybeSingle();
      return (row?['gotas'] as num?)?.toInt();
    } on Object {
      return null;
    }
  }

  /// Cupones vigentes del usuario (premios de caja ya convertidos en cupón),
  /// o `null` si falla la red.
  Future<List<Coupon>?> _coupons(String userId) async {
    try {
      final rows = await _client
          .from('user_coupons')
          .select(
            'used_at, coupon:coupons(id,title,kind,amount,active,valid_until)',
          )
          .eq('user_id', userId);

      final out = <Coupon>[];
      for (final row in rows) {
        final c = row['coupon'];
        if (c is! Map) continue;
        if (c['active'] == false) continue;

        final until = DateTime.tryParse((c['valid_until'] as String?) ?? '');
        if (until != null && until.isBefore(DateTime.now())) continue;

        out.add(
          Coupon(
            id: c['id'] as String,
            title: (c['title'] as String?) ?? 'Cupón',
            kind: c['kind'] == 'free_delivery'
                ? CouponKind.freeDelivery
                : CouponKind.fixed,
            amount: ((c['amount'] as num?) ?? 0).toInt(),
          )..used = row['used_at'] != null,
        );
      }
      return out;
    } on Object {
      return null;
    }
  }

  /// Cierra el stream de cambios.
  void dispose() => _cache.dispose();
}
