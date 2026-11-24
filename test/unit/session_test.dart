import 'package:biffy/app/di/injection.dart';
import 'package:biffy/core/constants/catalog_constants.dart';
import 'package:biffy/features/courier/bloc/courier_cubit.dart';
import 'package:biffy/domain/entities/wallet.dart';
import 'package:biffy/features/wallet/bloc/wallet_cubit.dart';
import 'package:biffy/data/mock/seed_users.dart';
import 'package:biffy/data/models/user.dart';
import 'package:biffy/data/repositories/auth_repository.dart';
import 'package:biffy/shared/state/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late SessionController s;
  setUp(() async => s = (await makeServices()).session);

  // Adaptado: el saldo y los canjes viven ahora en la billetera (WalletCubit);
  // antes eran s.gotas y s.redeem.
  int gotas() => getIt<WalletCubit>().balanceOf(s.user?.id);
  Coupon? redeem(Benefit b) =>
      getIt<WalletCubit>().redeemBenefit(s.user?.id, b).coupon;

  group('Autenticación simulada', () {
    test('login correcto y rol', () {
      final u = s.login(kDemoCourierEmail, kDemoPassword);
      expect(u.role, UserRole.courier);
      expect(s.activeRole, UserRole.courier);
    });

    test('contraseña incorrecta falla', () {
      expect(
        () => s.login(kDemoBuyerEmail, 'mal'),
        throwsA(isA<AuthException>()),
      );
    });

    test('registro duplicado falla', () {
      expect(
        () => s.register(
          name: 'X',
          email: kDemoBuyerEmail,
          password: '123456',
          role: UserRole.buyer,
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('bienvenida de 450 Gotas una sola vez', () {
      s.login(kDemoNewBuyerEmail, kDemoPassword);
      expect(gotas(), kWelcomeGotas);
      s.logout();
      s.login(kDemoNewBuyerEmail, kDemoPassword);
      expect(gotas(), kWelcomeGotas);
    });

    test('logout limpia la sesión', () {
      s.login(kDemoBuyerEmail, kDemoPassword);
      s.logout();
      expect(s.isLoggedIn, isFalse);
      expect(s.user, isNull);
    });
  });

  group('Preferencias y recompensas', () {
    const prefs = Preferences(
      likes: {'pizza'},
      allergies: {'maní'},
      budget: 20000,
    );

    test('guardar preferencias', () {
      s.login(kDemoNewBuyerEmail, kDemoPassword);
      s.savePreferences(prefs);
      expect(s.prefs.likes, {'pizza'});
      expect(s.prefs.allergies, {'maní'});
      expect(s.data.prefsCompleted, isTrue);
    });

    test('300 Gotas la primera vez y nunca duplicadas', () {
      s.login(kDemoNewBuyerEmail, kDemoPassword);
      final before = gotas();
      expect(s.savePreferences(prefs), kSurveyGotas);
      expect(gotas(), before + kSurveyGotas);
      expect(s.savePreferences(prefs.copyWith(budget: 30000)), 0);
      expect(gotas(), before + kSurveyGotas);
    });

    test('sin sesión no se acreditan Gotas', () {
      expect(s.savePreferences(prefs), 0);
      expect(gotas(), 0);
      expect(s.data.prefsCompleted, isTrue);
    });

    test('canje valida saldo suficiente', () {
      s.login(kDemoNewBuyerEmail, kDemoPassword); // 450 Gotas
      final expensive = kBenefits.firstWhere((b) => b.cost > 450);
      expect(redeem(expensive), isNull);
      expect(gotas(), 450);
      final cheap = kBenefits.firstWhere((b) => b.cost <= 450);
      expect(redeem(cheap), isNotNull);
      expect(gotas(), 450 - cheap.cost);
    });

    test('verificación universitaria simulada por dominio', () {
      s.login(kDemoNewBuyerEmail, kDemoPassword);
      expect(
        s.verifyUniversity('icesi', 'a@gmail.com'),
        VerifyResult.domainMismatch,
      );
      expect(s.verifyUniversity('icesi', 'a@icesi.edu.co'), VerifyResult.ok);
      expect(s.verifiedUniversityId, 'icesi');
    });

    test('código institucional en modo demo', () async {
      s.login(kDemoNewBuyerEmail, kDemoPassword);

      expect(
        await s.sendUniversityCodeAsync('icesi', 'a@icesi.edu.co'),
        VerifyResult.codeSent,
      );
      expect(s.pendingUniversityCode, '123456');
      expect(
        await s.confirmUniversityCodeAsync(
          universityId: 'icesi',
          email: 'a@icesi.edu.co',
          code: '000000',
        ),
        VerifyResult.invalidToken,
      );
      expect(
        await s.confirmUniversityCodeAsync(
          universityId: 'icesi',
          email: 'a@icesi.edu.co',
          code: '123456',
        ),
        VerifyResult.ok,
      );
      expect(s.isVerifiedStudent, isTrue);
      expect(s.verificationExpiresAt, isNotNull);
    });

    test('favoritos requieren sesión', () {
      expect(s.toggleFavoriteDish('capuchino'), isFalse);
      s.login(kDemoNewBuyerEmail, kDemoPassword);
      expect(s.toggleFavoriteDish('capuchino'), isTrue);
      expect(s.data.favoriteDishes, contains('capuchino'));
    });

    test('modo Campus del repartidor requiere verificación', () {
      s.login(kDemoCourier2Email, kDemoPassword);
      // La zona ahora la cambia el CourierCubit (antes s.setCourierZone).
      final courier = getIt<CourierCubit>();
      expect(courier.setZone(CourierZone.campus).ok, isFalse);
      expect(courier.setZone(CourierZone.general).ok, isTrue);
    });
  });
}
