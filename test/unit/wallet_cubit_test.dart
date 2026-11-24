import 'package:biffy/core/utils/clock.dart';
import 'package:biffy/data/models/user.dart';
import 'package:biffy/data/repositories/in_memory_wallet_repository.dart';
import 'package:biffy/domain/entities/wallet.dart';
import 'package:biffy/domain/usecases/wallet/wallet_usecases.dart';
import 'package:biffy/features/wallet/bloc/wallet_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 10, 12);

/// Coincide con un estado cuyo último canje terminó con [code].
TypeMatcher<WalletState> _outcome(String code) =>
    isA<WalletState>().having((s) => s.outcome?.result.code, 'code', code);

/// Pruebas con bloc_test de la billetera: canjes, saldo y cupones.
void main() {
  late InMemoryWalletRepository repo;
  late WalletUseCases uc;

  setUp(() {
    repo = InMemoryWalletRepository();
    uc = WalletUseCases(repo: repo, clock: Clock.fixed(_now));
  });

  final cheap = kBenefits.firstWhere((b) => b.cost <= 450);
  final expensive = kBenefits.firstWhere((b) => b.cost > 450);

  group('WalletCubit', () {
    blocTest<WalletCubit, WalletState>(
      'canjear con saldo suficiente descuenta el costo y crea el cupón',
      setUp: () => repo.insertSeed('u1', gotas: 450),
      build: () => WalletCubit(uc),
      act: (c) => c.redeemBenefit('u1', cheap),
      expect: () => contains(
        _outcome(
          'ok',
        ).having((s) => s.outcome?.result.coupon?.title, 'cupón', cheap.title),
      ),
      verify: (c) {
        expect(c.balanceOf('u1'), 450 - cheap.cost);
        expect(c.availableCoupons('u1').single.title, cheap.title);
        expect(c.historyOf('u1').first.title, 'Canje: ${cheap.title}');
      },
    );

    blocTest<WalletCubit, WalletState>(
      'sin saldo suficiente emite «Saldo insuficiente» y no descuenta',
      setUp: () => repo.insertSeed('u1', gotas: 450),
      build: () => WalletCubit(uc),
      act: (c) => c.redeemBenefit('u1', expensive),
      expect: () => [
        _outcome('insufficient').having(
          (s) => s.outcome?.result.message,
          'mensaje',
          'Saldo insuficiente',
        ),
      ],
      verify: (c) {
        expect(c.balanceOf('u1'), 450);
        expect(c.couponsOf('u1'), isEmpty);
      },
    );

    blocTest<WalletCubit, WalletState>(
      'sin sesión no se canjea',
      build: () => WalletCubit(uc),
      act: (c) => c.redeemBenefit(null, cheap),
      expect: () => [_outcome('not_logged_in')],
      verify: (c) => expect(c.balanceOf(null), 0),
    );

    blocTest<WalletCubit, WalletState>(
      'un movimiento del repositorio repinta la billetera',
      build: () => WalletCubit(uc),
      act: (c) => uc.credit('u1', 300, 'Completaste tus preferencias'),
      expect: () => [
        isA<WalletState>().having((s) => s.revision, 'revision', 1),
      ],
      verify: (c) => expect(c.balanceOf('u1'), 300),
    );
  });

  group('Casos de uso que usa el ciclo del pedido', () {
    test('gastar más Gotas de las que hay no descuenta nada', () {
      repo.insertSeed('u1', gotas: 10);
      final r = uc.spend('u1', 50, 'Usadas en BF-1');
      expect(r.code, 'insufficient');
      expect(uc.queries.balanceOf('u1'), 10);
    });

    test('acreditar cero o negativo no registra movimiento', () {
      uc.credit('u1', 0, 'nada');
      expect(uc.queries.historyOf('u1'), isEmpty);
    });

    test('marcar y liberar un cupón (reembolso)', () {
      final c = repo
          .addCoupon('u1', title: 'Envío gratis', kind: CouponKind.freeDelivery)
          .coupon!;
      uc.setCouponUsed('u1', c.id, true);
      expect(uc.queries.availableCoupons('u1'), isEmpty);
      uc.setCouponUsed('u1', c.id, false);
      expect(uc.queries.couponById('u1', c.id)?.used, isFalse);
    });

    test('un cupón que no existe devuelve not_found en español', () {
      final r = uc.setCouponUsed('u1', 'no-existe', true);
      expect(r.code, 'not_found');
      expect(r.message, 'Ese cupón ya no está disponible.');
    });

    test('en demo releer el saldo no lo cambia', () async {
      repo.insertSeed('u1', gotas: 120);
      expect((await uc.sync('u1')).ok, isTrue);
      expect(uc.queries.balanceOf('u1'), 120);
    });
  });
}
