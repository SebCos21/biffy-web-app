import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Archivos `.dart` dentro de [dir] (recursivo).
List<File> dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// Guardas estáticas de la HU-2: reglas que el código no debe romper.
void main() {
  group('Guardas HU-2', () {
    test('las pantallas no repiten la regla de cobertura', () {
      final forbidden = <String, RegExp>{
        '.radiusKm <': RegExp(r'\.radiusKm\s*<'),
        'distanceKm(': RegExp(r'\bdistanceKm\('),
        'couriersNearby == n': RegExp(
          r'couriersNearby\s*(==|!=|<=|>=|<|>)\s*\d',
        ),
      };
      final offenders = <String>[];
      for (final dir in ['lib/features', 'lib/core/widgets']) {
        for (final file in dartFiles(dir)) {
          final text = file.readAsStringSync();
          forbidden.forEach((label, pattern) {
            if (pattern.hasMatch(text)) offenders.add('${file.path}: $label');
          });
        }
      }
      expect(offenders, isEmpty, reason: 'Usar coverageGap/isReachable');
    });

    test('la app no contiene secretos de servidor', () {
      final offenders = [
        for (final file in dartFiles('lib'))
          if (file.readAsStringSync().contains(
            RegExp('service_role|sb_secret_'),
          ))
            file.path,
      ];
      expect(offenders, isEmpty);
    });

    test('el catálogo borra con deleted_at, nunca con DELETE', () {
      final text = File(
        'lib/data/repositories/supabase_catalog_repository.dart',
      ).readAsStringSync();
      final hardDelete = RegExp(
        r"from\(\s*'(dishes|branches|businesses)'\s*\)\s*\.delete\(",
      );
      expect(hardDelete.hasMatch(text), isFalse);
      expect(text, contains('deleted_at'));
    });
  });
}
