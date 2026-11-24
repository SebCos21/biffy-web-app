import '../../domain/entities/user.dart';
import '../../domain/repositories/wallet_repository.dart';
import 'wallet_cache.dart';

/// Billetera del modo demo y de las pruebas: todo en memoria, sin red.
class InMemoryWalletRepository implements WalletRepository {
  final WalletCache _cache = WalletCache();

  /// Saldo de la cuenta.
  @override
  int balanceOf(String userId) => _cache.balanceOf(userId);

  /// Movimientos de la cuenta.
  @override
  List<GotasEntry> historyOf(String userId) => _cache.historyOf(userId);

  /// Cupones de la cuenta.
  @override
  List<Coupon> couponsOf(String userId) => _cache.couponsOf(userId);

  /// Emite cuando cambia la caché.
  @override
  Stream<void> get changes => _cache.changes;

  /// En demo no hay servidor.
  @override
  bool get isRemote => false;

  /// Mueve el saldo en memoria.
  @override
  WalletResult credit(String userId, int amount, String reason, DateTime at) =>
      _cache.credit(userId, amount, reason, at);

  /// Agrega el cupón en memoria.
  @override
  WalletResult addCoupon(
    String userId, {
    required String title,
    required CouponKind kind,
    int amount = 0,
  }) => _cache.addCoupon(userId, title: title, kind: kind, amount: amount);

  /// Cambia el estado del cupón en memoria.
  @override
  WalletResult setCouponUsed(String userId, String couponId, bool used) =>
      _cache.setCouponUsed(userId, couponId, used);

  /// En demo el saldo ya es local: no hay nada que releer.
  @override
  Future<WalletResult> syncBalance(String userId) async =>
      const WalletResult.ok();

  /// En demo no hay billetera remota que cargar.
  @override
  Future<WalletResult> load(String userId) async => const WalletResult.ok();

  /// Deja saldo e historial de demostración.
  @override
  void insertSeed(
    String userId, {
    int? gotas,
    List<GotasEntry> history = const [],
  }) => _cache.seed(userId, gotas: gotas, history: history);

  /// Cierra el stream de cambios.
  void dispose() => _cache.dispose();
}
