import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/user.dart';
import '../../../domain/entities/wallet.dart';
import '../../../domain/repositories/wallet_repository.dart';
import '../../../domain/usecases/wallet/wallet_usecases.dart';

/// Resultado del último canje. [id] crece con cada resultado para que un
/// `BlocListener` reaccione una sola vez.
final class WalletOutcome {
  /// Crea el resultado numerado.
  const WalletOutcome(this.id, this.result);

  /// Número creciente del resultado.
  final int id;

  /// Resultado tipado con su mensaje en español.
  final WalletResult result;
}

/// Estado inmutable de la billetera: [revision] sube con cada cambio del
/// repositorio para que las pantallas se vuelvan a pintar.
final class WalletState {
  /// Crea el estado.
  const WalletState({this.revision = 0, this.outcome});

  /// Contador de cambios.
  final int revision;

  /// Resultado del último canje, si hubo.
  final WalletOutcome? outcome;

  /// Copia el estado cambiando solo lo indicado.
  WalletState copyWith({int? revision, WalletOutcome? outcome}) => WalletState(
    revision: revision ?? this.revision,
    outcome: outcome ?? this.outcome,
  );
}

/// Cubit global de Gotas y cupones. Las pantallas leen el saldo con
/// [balanceOf] y canjean beneficios de la demo con [redeemBenefit].
///
/// Es un Cubit porque el canje necesita el resultado en el mismo toque; las
/// reglas (saldo suficiente, costo) viven en `domain/usecases/wallet`.
class WalletCubit extends Cubit<WalletState> {
  /// Escucha los cambios del repositorio.
  WalletCubit(this.useCases) : super(const WalletState()) {
    _changes = useCases.repo.changes.listen((_) => _bump());
  }

  /// Casos de uso de la billetera ya cableados.
  final WalletUseCases useCases;
  StreamSubscription<void>? _changes;
  int _outcomeSeq = 0;

  /// Saldo de Gotas de la cuenta (0 sin sesión).
  int balanceOf(String? userId) => useCases.queries.balanceOf(userId);

  /// Movimientos de la cuenta.
  List<GotasEntry> historyOf(String? userId) =>
      useCases.queries.historyOf(userId);

  /// Cupones de la cuenta.
  List<Coupon> couponsOf(String? userId) => useCases.queries.couponsOf(userId);

  /// Cupones que aún se pueden usar.
  List<Coupon> availableCoupons(String? userId) =>
      useCases.queries.availableCoupons(userId);

  /// Cupón de la cuenta por id.
  Coupon? couponById(String? userId, String? couponId) =>
      useCases.queries.couponById(userId, couponId);

  /// Canjea un beneficio de la demo; `insufficient` si no alcanza el saldo.
  WalletResult redeemBenefit(String? userId, Benefit benefit) {
    final result = useCases.redeem(userId, benefit);
    if (!isClosed) {
      emit(
        state.copyWith(
          revision: state.revision + 1,
          outcome: WalletOutcome(++_outcomeSeq, result),
        ),
      );
    }
    return result;
  }

  /// Sube la revisión cuando cambia el repositorio.
  void _bump() {
    if (!isClosed) emit(state.copyWith(revision: state.revision + 1));
  }

  /// Cancela la escucha del repositorio.
  @override
  Future<void> close() {
    _changes?.cancel();
    return super.close();
  }
}
