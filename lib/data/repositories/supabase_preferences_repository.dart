import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/entities/preferences_status.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/preferences_repository.dart';
import 'preferences_cache.dart';

/// Preferencias (`preferences`, RPC `complete_survey`) y favoritos
/// (`favorite_dishes`, `favorite_branches`) en Supabase, con caché local.
class SupabasePreferencesRepository implements PreferencesRepository {
  /// Usa el cliente de Supabase indicado o el global.
  SupabasePreferencesRepository({sb.SupabaseClient? client})
    : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;
  final PreferencesCache _cache = PreferencesCache();

  /// Estado de la cuenta.
  @override
  PreferencesStatus statusOf(String account) => _cache.statusOf(account);

  /// Emite cuando cambia la caché.
  @override
  Stream<void> get changes => _cache.changes;

  /// Los datos viven en el servidor.
  @override
  bool get isRemote => true;

  /// Reemplaza el estado en la caché.
  @override
  void replace(String account, PreferencesStatus status) =>
      _cache.replace(account, status);

  /// Guarda las preferencias y, si corresponde, acredita la encuesta (la base
  /// lo hace una sola vez).
  @override
  Future<PreferencesResult> persistPreferences(
    String userId,
    Preferences prefs, {
    required bool completed,
    required bool completeSurvey,
  }) async {
    try {
      await _client.from('preferences').upsert({
        'user_id': userId,
        'likes': prefs.likes.toList(),
        'lifestyle': prefs.lifestyle.toList(),
        'allergies': prefs.allergies.toList(),
        'budget': prefs.budget,
        'completed': completed,
      });
      if (completeSurvey) await _completeSurvey();
      return const PreferencesResult.ok();
    } on Object {
      return const PreferencesResult('network');
    }
  }

  /// Acredita las 300 Gotas de la encuesta en el servidor (una sola vez).
  Future<int?> _completeSurvey() async {
    try {
      final res = await _client.rpc('complete_survey');
      final map = res is Map ? res : const {};
      if (map['result'] != 'ok') return null;
      return ((map['awarded'] as num?) ?? 0).toInt();
    } on Object {
      return null;
    }
  }

  /// Cambia el favorito en la caché y luego en la base; si la base falla,
  /// lo revierte para no dejar favoritos "fantasma".
  @override
  Future<PreferencesResult> setFavorite(
    String userId,
    FavoriteKind kind,
    String id,
    bool favorite,
  ) async {
    _cache.replace(
      userId,
      _cache.statusOf(userId).withFavorite(kind, id, favorite),
    );
    final table = kind == FavoriteKind.dish
        ? 'favorite_dishes'
        : 'favorite_branches';
    final column = kind == FavoriteKind.dish ? 'dish_id' : 'branch_id';
    try {
      if (favorite) {
        await _client.from(table).upsert({'user_id': userId, column: id});
      } else {
        await _client.from(table).delete().eq('user_id', userId).eq(column, id);
      }
      return const PreferencesResult.ok();
    } on Object {
      _cache.replace(
        userId,
        _cache.statusOf(userId).withFavorite(kind, id, !favorite),
      );
      return const PreferencesResult('network');
    }
  }

  /// Trae preferencias y favoritos; si falla la red conserva la caché.
  @override
  Future<PreferencesResult> load(String userId) async {
    try {
      final row = await _client
          .from('preferences')
          .select('likes, lifestyle, allergies, budget, completed, rewarded')
          .eq('user_id', userId)
          .maybeSingle();
      final dishes = await _client
          .from('favorite_dishes')
          .select('dish_id')
          .eq('user_id', userId);
      final branches = await _client
          .from('favorite_branches')
          .select('branch_id')
          .eq('user_id', userId);

      final current = _cache.statusOf(userId);
      _cache.replace(
        userId,
        current.copyWith(
          prefs: row == null
              ? null
              : Preferences(
                  likes: _set(row['likes']),
                  lifestyle: _set(row['lifestyle']),
                  allergies: _set(row['allergies']),
                  budget: ((row['budget'] as num?) ?? 25000).toInt(),
                ),
          completed: (row?['completed'] as bool?) ?? false,
          rewarded: (row?['rewarded'] as bool?) ?? false,
          favoriteDishes: Set.unmodifiable({
            for (final r in dishes) r['dish_id'] as String,
          }),
          favoriteBranches: Set.unmodifiable({
            for (final r in branches) r['branch_id'] as String,
          }),
        ),
      );
      return const PreferencesResult.ok();
    } on Object {
      return const PreferencesResult('network');
    }
  }

  /// Convierte el arreglo de Postgres en un conjunto de textos.
  static Set<String> _set(Object? value) =>
      (value as List?)?.map((e) => e.toString()).toSet() ?? {};

  /// Cierra el stream de cambios.
  void dispose() => _cache.dispose();
}
