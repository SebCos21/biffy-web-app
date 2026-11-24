import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/repositories/profile_repository.dart';
import '../models/user.dart';

/// Ajustes de la app del usuario en Supabase (`app_settings`). Preferencias,
/// favoritos, direcciones y verificación viven en sus propios repositorios.
///
/// La sesión trabaja de forma optimista (actualiza memoria y luego escribe):
/// si una escritura falla, la próxima hidratación corrige el estado.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({sb.SupabaseClient? client})
    : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;

  // ------------------------------------------------------------ Ajustes

  /// Lee los ajustes de la app del usuario.
  @override
  Future<AppSettings?> settings(String userId) async {
    final row = await _client
        .from('app_settings')
        .select(
          'notifications, promotions, email_summary, dark_mode, demo_lunch',
        )
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;
    return AppSettings(
      notifications: (row['notifications'] as bool?) ?? true,
      promotions: (row['promotions'] as bool?) ?? true,
      emailSummary: (row['email_summary'] as bool?) ?? false,
      darkMode: (row['dark_mode'] as bool?) ?? false,
      demoLunch: (row['demo_lunch'] as bool?) ?? false,
    );
  }

  /// Guarda los ajustes de la app.
  @override
  Future<void> saveSettings(String userId, AppSettings s) async {
    await _client.from('app_settings').upsert({
      'user_id': userId,
      'notifications': s.notifications,
      'promotions': s.promotions,
      'email_summary': s.emailSummary,
      'dark_mode': s.darkMode,
      'demo_lunch': s.demoLunch,
    });
  }
}
