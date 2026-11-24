import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/entities/address.dart';
import '../../domain/repositories/address_repository.dart';
import 'address_cache.dart';

/// Direcciones en Supabase (`addresses`, borrado lógico). Trabaja de forma
/// optimista: cambia la caché y luego escribe; si la escritura falla, la
/// próxima hidratación corrige el estado y el resultado es `network`.
class SupabaseAddressRepository implements AddressRepository {
  /// Usa el cliente de Supabase indicado o el global.
  SupabaseAddressRepository({sb.SupabaseClient? client})
    : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;
  final AddressCache _cache = AddressCache();

  /// Direcciones de la cuenta.
  @override
  List<Address> addressesOf(String userId) => _cache.addressesOf(userId);

  /// Id de la predeterminada.
  @override
  String? defaultIdOf(String userId) => _cache.defaultIdOf(userId);

  /// Emite cuando cambia la caché.
  @override
  Stream<void> get changes => _cache.changes;

  /// Las direcciones viven en el servidor.
  @override
  bool get isRemote => true;

  /// Guarda en la caché y luego crea (guarda su uuid) o actualiza la fila.
  @override
  Future<AddressResult> save(
    String userId,
    Address address, {
    required bool makeDefault,
  }) async {
    final saved = _cache.save(userId, address, makeDefault: makeDefault);
    final row = {
      'label': saved.label,
      'line': saved.line,
      'details': saved.details,
      'neighborhood': saved.neighborhood,
      'reference': saved.reference,
      'point_id': saved.pointId,
    };
    try {
      if (saved.dbId == null) {
        final inserted = await _client
            .from('addresses')
            .insert({
              'user_id': userId,
              ...row,
              'is_default': _cache.defaultIdOf(userId) == saved.id,
            })
            .select('id')
            .single();
        final dbId = inserted['id'] as String?;
        if (dbId != null) {
          saved.dbId = dbId;
          _cache.touch();
        }
      } else {
        await _client.from('addresses').update(row).eq('id', saved.dbId!);
      }
      return AddressResult.ok(saved);
    } on Object {
      return AddressResult('network', address: saved);
    }
  }

  /// Quita la dirección de la caché y marca `deleted_at` en la base.
  @override
  Future<AddressResult> delete(String userId, String id) async {
    final removed = _cache.delete(userId, id);
    if (removed == null) return const AddressResult('not_found');
    final dbId = removed.dbId;
    if (dbId == null) return AddressResult.ok(removed);
    try {
      await _client
          .from('addresses')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', dbId);
      return AddressResult.ok(removed);
    } on Object {
      return AddressResult('network', address: removed);
    }
  }

  /// Marca la predeterminada en la caché y en la base (desmarca las demás).
  @override
  Future<AddressResult> setDefault(String userId, String id) async {
    _cache.setDefault(userId, id);
    final a = _cache.byId(userId, id);
    final dbId = a?.dbId;
    if (dbId == null) return AddressResult.ok(a);
    try {
      await _client
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', userId);
      await _client
          .from('addresses')
          .update({'is_default': true})
          .eq('id', dbId);
      return AddressResult.ok(a);
    } on Object {
      return AddressResult('network', address: a);
    }
  }

  /// Lee las direcciones activas; si hay, reemplazan la caché y la primera
  /// (la predeterminada en la base) queda marcada.
  @override
  Future<AddressResult> load(String userId) async {
    try {
      final rows = await _client
          .from('addresses')
          .select('id, label, line, details, neighborhood, reference, point_id')
          .eq('user_id', userId)
          .filter('deleted_at', 'is', null)
          .order('is_default', ascending: false);
      final saved = [
        for (final row in rows)
          Address(
            id: row['id'] as String,
            label: (row['label'] as String?) ?? '',
            line: (row['line'] as String?) ?? '',
            details: (row['details'] as String?) ?? '',
            neighborhood: (row['neighborhood'] as String?) ?? '',
            reference: (row['reference'] as String?) ?? '',
            pointId: (row['point_id'] as String?) ?? 'icesi-biblioteca',
          )..dbId = row['id'] as String,
      ];
      if (saved.isEmpty) return const AddressResult.ok();
      _cache.replaceAll(userId, saved, defaultId: saved.first.id);
      return AddressResult.ok(saved.first);
    } on Object {
      return const AddressResult('network');
    }
  }

  /// Con servidor no hay datos de demostración; solo toca la caché.
  @override
  void insertSeed(
    String userId,
    List<Address> addresses, {
    String? defaultId,
  }) => _cache.replaceAll(userId, addresses, defaultId: defaultId);

  /// Cierra el stream de cambios.
  void dispose() => _cache.dispose();
}
