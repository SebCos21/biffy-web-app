import '../entities/user.dart';
import '../wallet_errors.dart';

/// Resultado de una operación de la billetera, igual en demo y con servidor.
///
/// [code] es `ok`, `insufficient`, `not_logged_in`, `not_found` o `network`.
class WalletResult {
  /// Crea el resultado con su código y, si aplica, el cupón creado.
  const WalletResult(this.code, {this.coupon});

  /// Operación exitosa.
  const WalletResult.ok({this.coupon}) : code = 'ok';

  /// Código de la operación.
  final String code;

  /// Cupón creado por un canje, si aplica.
  final Coupon? coupon;

  /// `true` si la operación terminó bien.
  bool get ok => code == 'ok';

  /// Mensaje en español para mostrar; nunca expone el código crudo.
  String get message => walletErrorMessage(code);

  /// `true` si falló la conexión con el servidor.
  bool get isTransportError => isWalletTransportError(code);

  /// Representación corta para depurar.
  @override
  String toString() => 'WalletResult($code)';
}

/// Contrato de las Gotas y los cupones de cada cuenta. Guarda una caché por
/// usuario que se lee de forma síncrona y avisa por [changes] cuando cambia.
///
/// Con servidor, el saldo lo mueve la base (compras, reembolsos, entregas,
/// canjes) y la app solo lo relee; en demo todo se mueve en memoria.
abstract interface class WalletRepository {
  /// Saldo de Gotas de la cuenta (0 si no tiene movimientos).
  int balanceOf(String userId);

  /// Movimientos locales, del más nuevo al más viejo (solo lectura).
  List<GotasEntry> historyOf(String userId);

  /// Cupones de la cuenta (solo lectura).
  List<Coupon> couponsOf(String userId);

  /// Emite cada vez que cambia la caché.
  Stream<void> get changes;

  /// `true` si el saldo y los cupones viven en un servidor.
  bool get isRemote;

  /// Suma (o resta, si es negativo) Gotas y registra el movimiento.
  WalletResult credit(String userId, int amount, String reason, DateTime at);

  /// Agrega un cupón con id nuevo a la cuenta.
  WalletResult addCoupon(
    String userId, {
    required String title,
    required CouponKind kind,
    int amount = 0,
  });

  /// Marca un cupón como usado o disponible.
  WalletResult setCouponUsed(String userId, String couponId, bool used);

  /// Vuelve a leer el saldo del servidor (no-op en demo). Nunca lanza.
  Future<WalletResult> syncBalance(String userId);

  /// Trae saldo y cupones del servidor (no-op en demo). Nunca lanza.
  Future<WalletResult> load(String userId);

  /// Solo para datos de demostración: deja saldo e historial de una cuenta.
  void insertSeed(String userId, {int? gotas, List<GotasEntry> history});
}
