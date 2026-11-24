import 'package:biffy/core/constants/catalog_constants.dart';
import 'package:biffy/core/utils/clock.dart';
import 'package:biffy/data/models/user.dart';
import 'package:biffy/data/repositories/in_memory_notification_repository.dart';
import 'package:biffy/data/repositories/in_memory_preferences_repository.dart';
import 'package:biffy/data/repositories/in_memory_wallet_repository.dart';
import 'package:biffy/data/repositories/supabase_preferences_repository.dart';
import 'package:biffy/domain/entities/preferences_status.dart';
import 'package:biffy/domain/repositories/preferences_repository.dart';
import 'package:biffy/domain/usecases/notifications/notification_usecases.dart';
import 'package:biffy/domain/usecases/preferences/preferences_usecases.dart';
import 'package:biffy/domain/usecases/wallet/wallet_usecases.dart';
import 'package:biffy/features/preferences/bloc/preferences_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

final _clock = Clock.fixed(DateTime(2026, 11, 10, 12));

const _prefs = Preferences(likes: {'pizza'}, allergies: {'maní'});

/// Coincide con un estado cuyo último resultado terminó con [code].
TypeMatcher<PreferencesState> _outcome(String code) =>
    isA<PreferencesState>().having((s) => s.outcome?.result.code, 'code', code);

/// Pruebas con bloc_test de preferencias y favoritos.
void main() {
  late WalletUseCases wallet;
  late NotificationUseCases notifications;

  /// Casos de uso sobre [repo] con billetera y avisos en memoria.
  PreferencesUseCases useCases(PreferencesRepository repo) =>
      PreferencesUseCases(
        repo: repo,
        credit: wallet.credit,
        push: notifications.push,
      );

  setUp(() {
    wallet = WalletUseCases(repo: InMemoryWalletRepository(), clock: _clock);
    notifications = NotificationUseCases(
      repo: InMemoryNotificationRepository(),
      clock: _clock,
    );
  });

  group('PreferencesCubit', () {
    blocTest<PreferencesCubit, PreferencesState>(
      'guardar preferencias con sesión acredita la encuesta una sola vez',
      build: () => PreferencesCubit(useCases(InMemoryPreferencesRepository())),
      act: (c) {
        expect(c.save('u1', _prefs).awarded, kSurveyGotas);
        expect(c.save('u1', _prefs).awarded, 0);
      },
      expect: () => contains(_outcome('ok')),
      verify: (c) {
        expect(c.prefsOf('u1').likes, {'pizza'});
        expect(c.completedOf('u1'), isTrue);
        expect(wallet.queries.balanceOf('u1'), kSurveyGotas);
        expect(
          notifications.queries.all.first.title,
          '+$kSurveyGotas Gotas 💧',
        );
      },
    );

    blocTest<PreferencesCubit, PreferencesState>(
      'sin sesión guarda como invitado y no acredita Gotas',
      build: () => PreferencesCubit(useCases(InMemoryPreferencesRepository())),
      act: (c) => expect(c.save(null, _prefs).awarded, 0),
      verify: (c) {
        expect(c.prefsOf(null).allergies, {'maní'});
        expect(wallet.queries.balanceOf('u1'), 0);
      },
    );

    blocTest<PreferencesCubit, PreferencesState>(
      'marcar un favorito con sesión emite ok',
      build: () => PreferencesCubit(useCases(InMemoryPreferencesRepository())),
      act: (c) => c.toggleFavorite('u1', FavoriteKind.dish, 'capuchino'),
      expect: () => contains(_outcome('ok')),
      verify: (c) => expect(c.isFavoriteDish('u1', 'capuchino'), isTrue),
    );

    blocTest<PreferencesCubit, PreferencesState>(
      'sin sesión el favorito no se guarda y emite el error en español',
      build: () => PreferencesCubit(useCases(InMemoryPreferencesRepository())),
      act: (c) => c.toggleFavorite(null, FavoriteKind.branch, 'qbano-icesi'),
      expect: () => [
        _outcome('not_logged_in').having(
          (s) => s.outcome?.result.message,
          'mensaje',
          'Inicia sesión para guardar favoritos.',
        ),
      ],
      verify: (c) => expect(c.favoriteBranches(null), isEmpty),
    );

    blocTest<PreferencesCubit, PreferencesState>(
      'si el servidor falla el favorito se revierte (criterio 8 de HU-2)',
      build: () => PreferencesCubit(
        useCases(
          // Servidor inalcanzable: toda escritura falla por red.
          SupabasePreferencesRepository(
            client: sb.SupabaseClient('http://127.0.0.1:1', 'clave-falsa'),
          ),
        ),
      ),
      act: (c) async {
        final pending = c.toggleFavorite('u1', FavoriteKind.dish, 'capuchino');
        // La caché cambia al instante (la pantalla avisa sin esperar).
        expect(c.isFavoriteDish('u1', 'capuchino'), isTrue);
        await pending;
      },
      expect: () => contains(_outcome('network')),
      verify: (c) => expect(c.isFavoriteDish('u1', 'capuchino'), isFalse),
    );
  });

  test('al iniciar sesión la cuenta hereda las preferencias del invitado', () {
    final repo = InMemoryPreferencesRepository();
    final uc = useCases(repo);
    uc.save(null, _prefs);
    uc.adoptGuest('u1');
    expect(uc.queries.prefsOf('u1').likes, {'pizza'});
    expect(uc.queries.completedOf('u1'), isTrue);
  });

  test('la universidad elegida se guarda solo en local', () {
    final uc = useCases(InMemoryPreferencesRepository());
    uc.setUniversity('u1', 'icesi');
    expect(uc.queries.prefsOf('u1').universityId, 'icesi');
    uc.setUniversity('u1', null);
    expect(uc.queries.prefsOf('u1').universityId, isNull);
  });
}
