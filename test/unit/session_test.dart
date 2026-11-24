import 'package:biffy/app/di/injection.dart';
import 'package:biffy/core/constants/catalog_constants.dart';
import 'package:biffy/features/courier/bloc/courier_cubit.dart';
import 'package:biffy/domain/entities/wallet.dart';
import 'package:biffy/features/wallet/bloc/wallet_cubit.dart';
import 'package:biffy/domain/university_errors.dart';
import 'package:biffy/domain/usecases/university/university_usecases.dart';
import 'package:biffy/features/university/bloc/university_cubit.dart';
import 'package:biffy/domain/entities/preferences_status.dart';
import 'package:biffy/features/preferences/bloc/preferences_cubit.dart';
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

  // Adaptado: preferencias y favoritos viven en el PreferencesCubit; antes
  // eran s.savePreferences, s.prefs, prefsCompleted() y
  // s.toggleFavoriteDish (que devolvía false sin sesión).
  PreferencesCubit preferences() => getIt<PreferencesCubit>();
  int savePreferences(Preferences p) =>
      preferences().save(s.user?.id, p).awarded;
  Preferences currentPrefs() => preferences().prefsOf(s.user?.id);
  bool prefsCompleted() => preferences().completedOf(s.user?.id);
  // Adaptado: la verificación universitaria vive en UniversityUseCases;
  // antes eran s.verifyUniversity (síncrono en demo), s.sendUniversityCodeAsync,
  // s.confirmUniversityCodeAsync, s.pendingUniversityCode y los getters.
  UniversityUseCases university() => getIt<UniversityCubit>().useCases;

  Future<bool> toggleFavoriteDish(String id) async =>
      (await preferences().toggleFavorite(
        s.user?.id,
        FavoriteKind.dish,
        id,
      )).ok;

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
      savePreferences(prefs);
      expect(currentPrefs().likes, {'pizza'});
      expect(currentPrefs().allergies, {'maní'});
      expect(prefsCompleted(), isTrue);
    });

    test('300 Gotas la primera vez y nunca duplicadas', () {
      s.login(kDemoNewBuyerEmail, kDemoPassword);
      final before = gotas();
      expect(savePreferences(prefs), kSurveyGotas);
      expect(gotas(), before + kSurveyGotas);
      expect(savePreferences(prefs.copyWith(budget: 30000)), 0);
      expect(gotas(), before + kSurveyGotas);
    });

    test('sin sesión no se acreditan Gotas', () {
      expect(savePreferences(prefs), 0);
      expect(gotas(), 0);
      expect(prefsCompleted(), isTrue);
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

    test('verificación universitaria simulada por dominio', () async {
      s.login(kDemoNewBuyerEmail, kDemoPassword);
      expect(
        await university().verify(s.user?.id, 'icesi', 'a@gmail.com'),
        VerifyResult.domainMismatch,
      );
      expect(
        await university().verify(s.user?.id, 'icesi', 'a@icesi.edu.co'),
        VerifyResult.ok,
      );
      expect(university().queries.verifiedUniversityId(s.user?.id), 'icesi');
    });

    test('código institucional en modo demo', () async {
      s.login(kDemoNewBuyerEmail, kDemoPassword);

      expect(
        await university().sendCode(s.user?.id, 'icesi', 'a@icesi.edu.co'),
        VerifyResult.codeSent,
      );
      expect(university().queries.pendingCodeOf(s.user?.id), '123456');
      expect(
        await university().confirmCode(
          s.user?.id,
          universityId: 'icesi',
          email: 'a@icesi.edu.co',
          code: '000000',
        ),
        VerifyResult.invalidToken,
      );
      expect(
        await university().confirmCode(
          s.user?.id,
          universityId: 'icesi',
          email: 'a@icesi.edu.co',
          code: '123456',
        ),
        VerifyResult.ok,
      );
      expect(university().queries.isVerifiedStudent(s.user?.id), isTrue);
      expect(university().queries.expiresAt(s.user?.id), isNotNull);
    });

    test('favoritos requieren sesión', () async {
      expect(await toggleFavoriteDish('capuchino'), isFalse);
      s.login(kDemoNewBuyerEmail, kDemoPassword);
      expect(await toggleFavoriteDish('capuchino'), isTrue);
      expect(preferences().favoriteDishes(s.user?.id), contains('capuchino'));
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
