import 'dart:async';

import '../../domain/entities/user.dart';
import '../../domain/repositories/wallet_repository.dart';

/// Saldo, movimientos y cupones de una cuenta dentro de la caché.
class _Account {
  int gotas = 0;
  bool welcomeGranted = false;
  final List<GotasEntry> history = [];
  final List<Coupon> coupons = [];
}

/// Caché por cuenta de la billetera, compartida por los repositorios de demo
/// y de Supabase. Avisa por [changes] en cada cambio.
class WalletCache {
  final Map<String, _Account> _accounts = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _couponSeq = 0;

  /// Emite cuando cambia algún saldo o cupón.
  Stream<void> get changes => _changes.stream;

  /// Cuenta en la caché, creándola vacía si no existe.
  _Account _of(String userId) => _accounts.putIfAbsent(userId, _Account.new);

  /// Saldo de la cuenta.
  int balanceOf(String userId) => _of(userId).gotas;

  /// Movimientos de la cuenta (solo lectura).
  List<GotasEntry> historyOf(String userId) =>
      List.unmodifiable(_of(userId).history);

  /// Cupones de la cuenta (solo lectura).
  List<Coupon> couponsOf(String userId) =>
      List.unmodifiable(_of(userId).coupons);

  /// Suma [amount] y registra el movimiento al principio del historial.
  WalletResult credit(String userId, int amount, String reason, DateTime at) {
    final a = _of(userId);
    a.gotas += amount;
    a.history.insert(0, GotasEntry(reason, amount, at));
    _emit();
    return const WalletResult.ok();
  }

  /// Reemplaza el saldo (lectura del servidor, sin movimiento local).
  void setBalance(String userId, int gotas) {
    final a = _of(userId);
    if (a.gotas == gotas) return;
    a.gotas = gotas;
    _emit();
  }

  /// Reemplaza los cupones (lectura del servidor).
  void setCoupons(String userId, List<Coupon> coupons) {
    _of(userId).coupons
      ..clear()
      ..addAll(coupons);
    _emit();
  }

  /// Agrega un cupón con id local nuevo (`cup-1`, `cup-2`…).
  WalletResult addCoupon(
    String userId, {
    required String title,
    required CouponKind kind,
    int amount = 0,
  }) {
    final c = Coupon(
      id: 'cup-${++_couponSeq}',
      title: title,
      kind: kind,
      amount: amount,
    );
    _of(userId).coupons.add(c);
    _emit();
    return WalletResult.ok(coupon: c);
  }

  /// Marca el cupón como usado o disponible; `not_found` si no existe.
  WalletResult setCouponUsed(String userId, String couponId, bool used) {
    var found = false;
    for (final c in _of(userId).coupons) {
      if (c.id == couponId) {
        c.used = used;
        found = true;
      }
    }
    _emit();
    return found ? const WalletResult.ok() : const WalletResult('not_found');
  }

  /// `true` si la cuenta ya recibió la bienvenida.
  bool welcomeGrantedOf(String userId) => _of(userId).welcomeGranted;

  /// Marca la bienvenida como entregada.
  void markWelcomeGranted(String userId) => _of(userId).welcomeGranted = true;

  /// Deja saldo e historial de demostración.
  void seed(String userId, {int? gotas, List<GotasEntry> history = const []}) {
    final a = _of(userId);
    if (gotas != null) a.gotas = gotas;
    a.history.addAll(history);
    _emit();
  }

  /// Avisa a los oyentes si el stream sigue abierto.
  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Cierra el stream de cambios.
  void dispose() => _changes.close();
}
