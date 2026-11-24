import '../../../core/utils/clock.dart';
import '../../entities/user.dart';
import '../../entities/wallet.dart';
import '../../repositories/wallet_repository.dart';

/// Lecturas síncronas de la billetera. Sin sesión (`null`) todo es vacío.
class WalletQueries {
  /// Recibe el repositorio.
  const WalletQueries(this._repo);
  final WalletRepository _repo;

  /// Saldo de Gotas de la cuenta.
  int balanceOf(String? userId) => userId == null ? 0 : _repo.balanceOf(userId);

  /// Movimientos de la cuenta.
  List<GotasEntry> historyOf(String? userId) =>
      userId == null ? const [] : _repo.historyOf(userId);

  /// Cupones de la cuenta.
  List<Coupon> couponsOf(String? userId) =>
      userId == null ? const [] : _repo.couponsOf(userId);

  /// Cupones que aún se pueden usar.
  List<Coupon> availableCoupons(String? userId) =>
      couponsOf(userId).where((c) => !c.used).toList();

  /// Cupón de la cuenta por id, o `null`.
  Coupon? couponById(String? userId, String? couponId) {
    for (final c in couponsOf(userId)) {
      if (c.id == couponId) return c;
    }
    return null;
  }
}

/// Acredita Gotas a una cuenta con la hora del reloj de la app.
class CreditGotas {
  /// Recibe el repositorio y el reloj.
  const CreditGotas(this._repo, this._clock);
  final WalletRepository _repo;
  final Clock _clock;

  /// Suma [amount] (si es positivo) y registra el motivo.
  WalletResult call(String userId, int amount, String reason) {
    if (amount <= 0) return const WalletResult.ok();
    return _repo.credit(userId, amount, reason, _clock.now());
  }
}

/// Descuenta Gotas si el saldo alcanza.
class SpendGotas {
  /// Recibe el repositorio y el reloj.
  const SpendGotas(this._repo, this._clock);
  final WalletRepository _repo;
  final Clock _clock;

  /// Devuelve `insufficient` si el saldo no alcanza (no descuenta nada).
  WalletResult call(String userId, int amount, String reason) {
    if (amount <= 0) return const WalletResult.ok();
    if (_repo.balanceOf(userId) < amount) {
      return const WalletResult('insufficient');
    }
    return _repo.credit(userId, -amount, reason, _clock.now());
  }
}

/// Marca un cupón como usado o lo libera (reembolsos).
class SetCouponUsed {
  /// Recibe el repositorio.
  const SetCouponUsed(this._repo);
  final WalletRepository _repo;

  /// Cambia el estado del cupón [couponId] de la cuenta.
  WalletResult call(String userId, String couponId, bool used) =>
      _repo.setCouponUsed(userId, couponId, used);
}

/// Canjea un beneficio de la demo por un cupón.
class RedeemBenefit {
  /// Recibe el repositorio y el pago con Gotas.
  const RedeemBenefit(this._repo, this._spend);
  final WalletRepository _repo;
  final SpendGotas _spend;

  /// Exige sesión y saldo; descuenta el costo y crea el cupón.
  WalletResult call(String? userId, Benefit benefit) {
    if (userId == null) return const WalletResult('not_logged_in');
    final paid = _spend(userId, benefit.cost, 'Canje: ${benefit.title}');
    if (!paid.ok) return paid;
    return _repo.addCoupon(
      userId,
      title: benefit.title,
      kind: benefit.kind,
      amount: benefit.amount,
    );
  }
}

/// Relee el saldo del servidor (lo mueve la base en compras y entregas).
class SyncWallet {
  /// Recibe el repositorio.
  const SyncWallet(this._repo);
  final WalletRepository _repo;

  /// Relee el saldo de [userId]; no hace nada en demo.
  Future<WalletResult> call(String userId) => _repo.syncBalance(userId);
}

/// Trae saldo y cupones al iniciar sesión.
class LoadWallet {
  /// Recibe el repositorio.
  const LoadWallet(this._repo);
  final WalletRepository _repo;

  /// Carga la billetera de [userId]; no hace nada en demo.
  Future<WalletResult> call(String userId) => _repo.load(userId);
}

/// Todos los casos de uso de la billetera, ya cableados. Lo reciben el
/// `WalletCubit`, la sesión y el adaptador de pedidos.
class WalletUseCases {
  /// Ensambla los casos de uso sobre el repositorio y el reloj.
  factory WalletUseCases({
    required WalletRepository repo,
    required Clock clock,
  }) {
    final spend = SpendGotas(repo, clock);
    return WalletUseCases._(repo, clock, spend);
  }

  WalletUseCases._(this.repo, Clock clock, this.spend)
    : queries = WalletQueries(repo),
      credit = CreditGotas(repo, clock),
      setCouponUsed = SetCouponUsed(repo),
      redeem = RedeemBenefit(repo, spend),
      sync = SyncWallet(repo),
      load = LoadWallet(repo);

  /// Repositorio de la billetera (en memoria o Supabase).
  final WalletRepository repo;

  /// Lecturas.
  final WalletQueries queries;

  /// Acreditar Gotas.
  final CreditGotas credit;

  /// Gastar Gotas.
  final SpendGotas spend;

  /// Usar o liberar un cupón.
  final SetCouponUsed setCouponUsed;

  /// Canjear un beneficio de la demo.
  final RedeemBenefit redeem;

  /// Releer el saldo.
  final SyncWallet sync;

  /// Cargar saldo y cupones.
  final LoadWallet load;
}
