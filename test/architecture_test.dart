import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reglas de dependencia de la Clean Architecture del ciclo de pedidos.
///
///   features/orders (Bloc) ──▶ domain ◀── data (repositorios)
///
/// El dominio es Dart puro: no conoce la UI, Flutter, Supabase ni la capa de
/// datos. El Bloc solo conoce el dominio.
List<String> _violations(
  String dir,
  RegExp forbidden, {
  List<String> except = const [],
}) {
  final bad = <String>[];
  final files = Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) {
        final path = f.path.replaceAll(r'\', '/');
        return !except.any(path.contains);
      });
  for (final f in files) {
    for (final line in f.readAsLinesSync()) {
      final t = line.trimLeft();
      if (!(t.startsWith('import ') || t.startsWith('export '))) continue;
      if (forbidden.hasMatch(t)) bad.add('${f.path}: $t');
    }
  }
  return bad;
}

/// Código de la sesión (antes `lib/shared/state/session_controller.dart`):
/// Bloc, estado, evento, instantánea, repositorio y, salvo [stateOnly], sus
/// casos de uso.
String _sessionSources({bool stateOnly = false}) => [
  'lib/features/auth/bloc/auth_bloc.dart',
  'lib/features/auth/bloc/auth_event.dart',
  'lib/features/auth/bloc/auth_state.dart',
  'lib/domain/entities/session.dart',
  'lib/domain/repositories/session_repository.dart',
  'lib/data/repositories/in_memory_session_repository.dart',
  if (!stateOnly) 'lib/domain/usecases/auth/auth_usecases.dart',
].map((p) => File(p).readAsStringSync()).join('\n');

/// Patrón de una clase Bloc o Cubit.
final _blocClass = RegExp(r'class (\w+) extends (?:Bloc|Cubit)<');

/// Archivos de lib/features que declaran un Bloc o un Cubit.
List<File> _blocFiles() => [
  for (final f in Directory('lib/features').listSync(recursive: true))
    if (f is File &&
        f.path.endsWith('.dart') &&
        _blocClass.hasMatch(f.readAsStringSync()))
      f,
];

/// Nombres de todos los Bloc y Cubit de la app.
List<String> _blocNames() => [
  for (final f in _blocFiles())
    for (final m in _blocClass.allMatches(f.readAsStringSync())) m.group(1)!,
];

void main() {
  test('domain no depende de data, features, shared, app ni de frameworks', () {
    final bad = _violations(
      'lib/domain',
      RegExp(
        r"(\.\./)+(data|features|shared|app)/"
        r"|package:(flutter|flutter_bloc|supabase_flutter|provider|go_router|get_it)",
      ),
    );
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('el Bloc de pedidos solo conoce el dominio (no data ni Supabase)', () {
    final bad = _violations(
      'lib/features/orders',
      RegExp(r"(\.\./)+(data|shared)/|supabase"),
    );
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test(
    'el Bloc de avisos solo conoce el dominio (no data, shared ni Supabase)',
    () {
      final bad = _violations(
        'lib/features/notifications',
        RegExp(r"(\.\./)+(data|shared)/|supabase"),
      );
      expect(bad, isEmpty, reason: bad.join('\n'));
    },
  );

  test('los repositorios de avisos implementan la interfaz del dominio', () {
    for (final f in [
      'lib/data/repositories/in_memory_notification_repository.dart',
      'lib/data/repositories/supabase_notification_repository.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, contains('implements NotificationRepository'), reason: f);
      expect(
        src,
        contains('domain/repositories/notification_repository.dart'),
        reason: f,
      );
    }
  });

  test('el cubit del repartidor solo conoce el dominio', () {
    final bad = _violations(
      'lib/features/courier/bloc',
      RegExp(r"(\.\./)+(data|shared)/|supabase"),
    );
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test(
    'los repositorios del repartidor implementan la interfaz del dominio',
    () {
      for (final f in [
        'lib/data/repositories/in_memory_courier_repository.dart',
        'lib/data/repositories/supabase_courier_repository.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src, contains('implements CourierRepository'), reason: f);
        expect(
          src,
          contains('domain/repositories/courier_repository.dart'),
          reason: f,
        );
      }
    },
  );

  test('las pantallas del repartidor no cambian su estado en la sesión', () {
    // Disponibilidad, zona y registro pasan por el CourierCubit.
    final bad = <String>[];
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      for (final m in [
        'setCourierOnline',
        'setCourierZone',
        'saveCourierProfile',
        'courierProfile =',
      ]) {
        if (src.contains(m)) bad.add('${f.path}: $m');
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('el Bloc del catálogo y el carrito solo conocen el dominio', () {
    for (final dir in [
      'lib/features/catalog',
      'lib/features/buyer/cart/bloc',
    ]) {
      final bad = _violations(
        dir,
        RegExp(r"(\.\./)+data/|supabase"),
        // El checkout aún lee la sesión (puente hasta el módulo de Auth).
        except: ['checkout_cubit.dart'],
      );
      expect(bad, isEmpty, reason: bad.join('\n'));
    }
  });

  test('los repositorios del catálogo implementan la interfaz del dominio', () {
    for (final f in [
      'lib/data/repositories/in_memory_catalog_repository.dart',
      'lib/data/repositories/supabase_catalog_repository.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, contains('implements CatalogRepository'), reason: f);
      expect(
        src,
        contains('domain/repositories/catalog_repository.dart'),
        reason: f,
      );
    }
    expect(
      File('lib/data/repositories/catalog_repository.dart').existsSync(),
      isFalse,
      reason: 'la interfaz vive en lib/domain/repositories/',
    );
  });

  test('no queda CatalogController (lo reemplazó CatalogBloc)', () {
    expect(
      File('lib/shared/state/catalog_controller.dart').existsSync(),
      isFalse,
    );
    final bad = _violations('lib', RegExp(r'catalog_controller'));
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test(
    'las pantallas no escriben el catálogo sin pasar por el CatalogBloc',
    () {
      // Las escrituras son eventos (request/add); nadie llama al repositorio.
      final bad = _violations(
        'lib/features',
        RegExp(r'domain/repositories/catalog_repository\.dart'),
        except: ['lib/features/catalog/', 'lib/features/buyer/cart/bloc/'],
      );
      expect(bad, isEmpty, reason: bad.join('\n'));
    },
  );

  test('el cubit de la billetera solo conoce el dominio', () {
    final bad = _violations(
      'lib/features/wallet',
      RegExp(r"(\.\./)+(data|shared)/|supabase"),
    );
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('los repositorios de la billetera implementan la interfaz', () {
    for (final f in [
      'lib/data/repositories/in_memory_wallet_repository.dart',
      'lib/data/repositories/supabase_wallet_repository.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, contains('implements WalletRepository'), reason: f);
      expect(
        src,
        contains('domain/repositories/wallet_repository.dart'),
        reason: f,
      );
    }
  });

  test('Gotas y cupones no se mueven en la sesión', () {
    // Saldo, historial y cupones viven en la billetera (WalletRepository).
    final src = _sessionSources();
    for (final m in [
      'int get gotas',
      'spendGotas(',
      'creditGotas(',
      'Coupon? redeem(',
      'syncGotas(',
      'gotasHistory',
      '.coupons',
    ]) {
      expect(src.contains(m), isFalse, reason: 'sesión: $m');
    }
  });

  test('el cubit de preferencias solo conoce el dominio', () {
    final bad = _violations(
      'lib/features/preferences',
      RegExp(r"(\.\./)+(data|shared)/|supabase"),
    );
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('los repositorios de preferencias implementan la interfaz', () {
    for (final f in [
      'lib/data/repositories/in_memory_preferences_repository.dart',
      'lib/data/repositories/supabase_preferences_repository.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, contains('implements PreferencesRepository'), reason: f);
      expect(
        src,
        contains('domain/repositories/preferences_repository.dart'),
        reason: f,
      );
    }
  });

  test('preferencias y favoritos no viven en la sesión', () {
    final src = _sessionSources();
    for (final m in [
      'savePreferences(',
      'toggleFavoriteDish(',
      'toggleFavoriteRestaurant(',
      'favoriteDishes',
      'prefsCompleted',
      'Preferences get prefs',
    ]) {
      expect(src.contains(m), isFalse, reason: 'sesión: $m');
    }
  });

  test('el cubit de direcciones solo conoce el dominio', () {
    final bad = _violations(
      'lib/features/addresses',
      RegExp(r"(\.\./)+(data|shared)/|supabase"),
    );
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('los repositorios de direcciones implementan la interfaz', () {
    for (final f in [
      'lib/data/repositories/in_memory_address_repository.dart',
      'lib/data/repositories/supabase_address_repository.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, contains('implements AddressRepository'), reason: f);
      expect(
        src,
        contains('domain/repositories/address_repository.dart'),
        reason: f,
      );
    }
  });

  test('las direcciones no viven en la sesión', () {
    final src = _sessionSources();
    for (final m in [
      'saveAddress(',
      'deleteAddress(',
      'setDefaultAddress(',
      'addressById(',
      'defaultAddressId',
    ]) {
      expect(src.contains(m), isFalse, reason: 'sesión: $m');
    }
    // Adaptado: los casos de uso de la sesión delegan en AddressUseCases
    // (`_d.addresses.load`), así que la lista se busca solo en el estado.
    expect(
      _sessionSources(stateOnly: true).contains('.addresses'),
      isFalse,
      reason: 'sesión: .addresses',
    );
  });

  test('los cubits de verificación universitaria solo conocen el dominio', () {
    for (final dir in [
      'lib/features/university',
      'lib/features/auth/bloc/university_verification_cubit.dart',
    ]) {
      final bad = FileSystemEntity.isDirectorySync(dir)
          ? _violations(dir, RegExp(r"(\.\./)+(data|shared)/|supabase"))
          : [
              for (final line in File(dir).readAsLinesSync())
                if (line.trimLeft().startsWith('import ') &&
                    RegExp(r"(\.\./)+(data|shared)/|supabase").hasMatch(line))
                  '$dir: $line',
            ];
      expect(bad, isEmpty, reason: bad.join('\n'));
    }
  });

  test('los repositorios de verificación implementan la interfaz', () {
    for (final f in [
      'lib/data/repositories/in_memory_university_repository.dart',
      'lib/data/repositories/supabase_university_repository.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, contains('implements UniversityRepository'), reason: f);
      expect(
        src,
        contains('domain/repositories/university_repository.dart'),
        reason: f,
      );
    }
  });

  test('la verificación universitaria no vive en la sesión', () {
    final src = _sessionSources();
    for (final m in [
      'enum VerifyResult',
      'verifyUniversity',
      'sendUniversityCodeAsync',
      'confirmUniversityCodeAsync',
      'isVerifiedStudent',
      'verifiedUniversityId',
      'universityEmail',
      'void setUniversity(',
    ]) {
      expect(src.contains(m), isFalse, reason: 'sesión: $m');
    }
  });

  test('no queda NotificationCenter (lo reemplazó NotificationsBloc)', () {
    expect(
      File('lib/shared/state/notification_center.dart').existsSync(),
      isFalse,
    );
    final bad = _violations('lib', RegExp(r'notification_center'));
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('los cubits de autenticación no importan data ni Supabase', () {
    final bad = _violations(
      'lib/features/auth/bloc',
      RegExp(r"(\.\./)+data/|supabase"),
    );
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('el AuthBloc y los cubits de auth solo conocen el dominio', () {
    final bad = _violations(
      'lib/features/auth/bloc',
      RegExp(r"(\.\./)+(data|shared|app)/|supabase"),
    );
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test(
    'no queda SessionController ni ControllerScope (los reemplazó AuthBloc)',
    () {
      for (final f in [
        'lib/shared/state/session_controller.dart',
        'lib/shared/state/controller_scope.dart',
      ]) {
        expect(File(f).existsSync(), isFalse, reason: f);
      }
      final bad = _violations(
        'lib',
        RegExp(r'session_controller|controller_scope'),
      );
      expect(bad, isEmpty, reason: bad.join('\n'));
      final watch = [
        for (final f in Directory('lib').listSync(recursive: true))
          if (f is File &&
              f.path.endsWith('.dart') &&
              f.readAsStringSync().contains('watchController'))
            f.path,
      ];
      expect(watch, isEmpty, reason: watch.join('\n'));
    },
  );

  test('no hay ChangeNotifier ni ValueNotifier en lib/', () {
    final pattern = RegExp(
      r'(extends|with|implements)\s+ChangeNotifier|ValueNotifier<|ChangeNotifier\(',
    );
    final bad = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            pattern.hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('el router se refresca con el stream del AuthBloc', () {
    final router = File('lib/app/router.dart').readAsStringSync();
    expect(router, contains('refreshListenable: refresh'));
    expect(router, contains('AuthBloc'));
    final app = File('lib/app/app.dart').readAsStringSync();
    expect(
      app,
      matches(
        RegExp(r'StreamRefreshListenable\(\s*getIt<AuthBloc>\(\)\.stream'),
      ),
    );
  });

  test('todo Bloc/Cubit de lib/features solo conoce el dominio', () {
    // Incluye carrito, checkout, pagos, recompensas, cajas, ganancias y avisos:
    // nada de data/, shared/, app/, Supabase ni GetIt dentro de un Bloc.
    final forbidden = RegExp(
      r"(\.\./)+(data|shared|app)/|supabase|package:get_it",
    );
    final bad = <String>[];
    for (final f in _blocFiles()) {
      for (final line in f.readAsLinesSync()) {
        final t = line.trimLeft();
        if (t.startsWith('import ') && forbidden.hasMatch(t)) {
          bad.add('${f.path}: $t');
        }
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('cada Bloc/Cubit tiene blocTest de éxito y de error', () {
    final tests = [
      for (final f in Directory('test').listSync(recursive: true))
        if (f is File && f.path.endsWith('_test.dart')) f.readAsStringSync(),
    ].join('\n');
    final missing = <String>[];
    for (final name in _blocNames()) {
      final n = RegExp('blocTest<$name\\b').allMatches(tests).length;
      if (n < 2) missing.add('$name ($n blocTest)');
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('el checkout valida y delega el pedido en el OrdersBloc', () {
    final src = File(
      'lib/features/buyer/cart/bloc/checkout_cubit.dart',
    ).readAsStringSync();
    expect(src, contains('OrdersBloc'));
    expect(src, contains('OrderPlaced('));
    // No crea pedidos por su cuenta ni toca el repositorio o los casos de uso.
    expect(src, isNot(contains('order_repository')));
    expect(src, isNot(contains('placeOrder(')));
  });

  test(
    'cada repositorio del dominio tiene versión en memoria y de Supabase',
    () {
      // Excepciones documentadas en HANDOFF.md.
      const onlyLocal = {'SessionRepository'}; // estado del equipo, ambos modos
      const onlySupabase = {
        'RewardsRepository', // HU-4: cajas y canjes solo con servidor
        'MerchantBoxesRepository',
      };
      final data = [
        for (final f in Directory('lib/data').listSync(recursive: true))
          if (f is File && f.path.endsWith('.dart')) f.readAsStringSync(),
      ].join('\n');
      final interfaces = <String>{
        for (final f in Directory('lib/domain/repositories').listSync())
          if (f is File)
            for (final m in RegExp(
              r'(?:abstract (?:interface )?|interface )class (\w+Repository)',
            ).allMatches(f.readAsStringSync()))
              m.group(1)!,
      };
      final missing = <String>[];
      for (final i in interfaces) {
        bool has(String prefix) => RegExp(
          'class $prefix\\w*\\s+(?:extends \\w+\\s+)?implements[^{]*\\b$i\\b',
        ).hasMatch(data);
        if (!onlySupabase.contains(i) && !has('InMemory')) {
          missing.add('$i sin InMemory');
        }
        if (!onlyLocal.contains(i) && !has('Supabase')) {
          missing.add('$i sin Supabase');
        }
      }
      expect(interfaces, isNotEmpty);
      expect(missing, isEmpty, reason: missing.join('\n'));
    },
  );

  test('los repositorios de pedidos implementan la interfaz del dominio', () {
    for (final f in [
      'lib/data/repositories/in_memory_order_repository.dart',
      'lib/data/repositories/supabase_order_repository.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, contains('implements OrderRepository'), reason: f);
      expect(
        src,
        contains('domain/repositories/order_repository.dart'),
        reason: f,
      );
    }
  });

  test(
    'las pantallas no importan implementaciones de repositorios de pedidos',
    () {
      final bad = _violations(
        'lib/features',
        RegExp(r"data/repositories/\w*order"),
      );
      expect(bad, isEmpty, reason: bad.join('\n'));
    },
  );

  test('solo lib/app/di conoce las implementaciones concretas', () {
    // Ninguna pantalla, controlador ni caso de uso importa un repositorio en
    // memoria o de Supabase: los piden a GetIt por su interfaz.
    final bad = _violations(
      'lib',
      RegExp(
        r"(in_memory_\w+|supabase_\w*repository|review_repository_impl)\.dart",
      ),
      except: ['lib/app/di/', 'lib/data/'],
    );
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('Supabase solo lo conocen la capa de datos y el módulo de datos', () {
    final bad = _violations(
      'lib',
      RegExp(r"package:supabase_flutter"),
      except: ['lib/data/', 'lib/app/di/modules/data_module.dart'],
    );
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('no queda Provider ni AppServices: todo sale de GetIt', () {
    final bad = _violations('lib', RegExp(r"package:provider|app_services"));
    expect(bad, isEmpty, reason: bad.join('\n'));
    expect(
      File('lib/shared/state/app_services.dart').existsSync(),
      isFalse,
      reason: 'AppServices fue reemplazado por lib/app/di/injection.dart',
    );
  });

  test(
    'los módulos de GetIt separan núcleo, datos, dominio y presentación',
    () {
      for (final m in ['core', 'data', 'domain', 'presentation']) {
        expect(
          File('lib/app/di/modules/${m}_module.dart').existsSync(),
          isTrue,
          reason: 'falta el módulo $m',
        );
      }
      final injection = File('lib/app/di/injection.dart').readAsStringSync();
      expect(injection, contains('registerCoreModule'));
      expect(injection, contains('registerDataModule'));
      expect(injection, contains('registerDomainModule'));
      expect(injection, contains('registerPresentationModule'));
    },
  );

  test('la única decisión de entorno vive en el módulo de datos', () {
    final bad = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) {
          final path = f.path.replaceAll(r'\', '/');
          return !path.contains('lib/app/di/modules/data_module.dart') &&
              !path.contains('lib/core/config/');
        });
    for (final f in files) {
      for (final line in f.readAsLinesSync()) {
        final code = line.trimLeft();
        if (code.startsWith('//')) continue; // comentarios y /// no cuentan
        if (code.contains('AppConfig.hasSupabase')) bad.add('${f.path}: $code');
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
