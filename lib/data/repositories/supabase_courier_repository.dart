import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/entities/courier.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/courier_repository.dart';
import 'courier_cache.dart';

/// Perfil de repartidor en Supabase (`courier_profiles`). La disponibilidad
/// y la zona son locales, igual que en demo (límite conocido).
class SupabaseCourierRepository implements CourierRepository {
  /// Usa el cliente de Supabase indicado o el global.
  SupabaseCourierRepository({sb.SupabaseClient? client})
    : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;
  final CourierCache _cache = CourierCache();

  /// Estado de la cuenta.
  @override
  CourierStatus statusOf(String userId) => _cache.statusOf(userId);

  /// Emite cuando cambia la caché.
  @override
  Stream<void> get changes => _cache.changes;

  /// El perfil vive en el servidor.
  @override
  bool get isRemote => true;

  /// Guarda el perfil en la caché y luego lo sube con `upsert`.
  @override
  Future<CourierResult> saveProfile(
    String userId,
    CourierProfile profile,
  ) async {
    final status = _cache.setProfile(userId, profile);
    try {
      await _client.from('courier_profiles').upsert({
        'user_id': userId,
        'full_name': profile.fullName,
        'doc_type': profile.docType,
        'doc_number': profile.docNumber,
        'phone': profile.phone,
        'vehicle': _vehicleValue(profile.vehicle),
        'plate': profile.plate,
        'university_id': profile.universityId,
      });
      return CourierResult.ok(status);
    } on Object {
      return CourierResult('save_failed', status: status);
    }
  }

  /// Lee el perfil guardado; si existe, la cuenta queda conectada y en zona
  /// Campus cuando el perfil tiene universidad. Sin red devuelve `network`.
  @override
  Future<CourierResult> load(String userId, {String contactEmail = ''}) async {
    try {
      final row = await _client
          .from('courier_profiles')
          .select(
            'full_name, doc_type, doc_number, phone, vehicle, plate, university_id',
          )
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return CourierResult.ok(_cache.statusOf(userId));
      final profile = CourierProfile(
        fullName: (row['full_name'] as String?) ?? '',
        docType: (row['doc_type'] as String?) ?? 'CC',
        docNumber: (row['doc_number'] as String?) ?? '',
        phone: (row['phone'] as String?) ?? '',
        vehicle: _vehicle(row['vehicle'] as String?),
        plate: row['plate'] as String?,
        universityId: row['university_id'] as String?,
        contactEmail: contactEmail,
      );
      return CourierResult.ok(
        _cache.replace(
          userId,
          CourierStatus(
            profile: profile,
            online: true,
            zone: profile.universityId == null
                ? CourierZone.general
                : CourierZone.campus,
          ),
        ),
      );
    } on Object {
      return CourierResult('network', status: _cache.statusOf(userId));
    }
  }

  /// Cambia la disponibilidad (solo local).
  @override
  CourierResult setOnline(String userId, bool online) =>
      CourierResult.ok(_cache.setOnline(userId, online));

  /// Cambia la zona (solo local).
  @override
  CourierResult setZone(String userId, CourierZone zone) =>
      CourierResult.ok(_cache.setZone(userId, zone));

  /// Solo para demo (con servidor la semilla vive en la base); si se llama,
  /// solo deja el perfil en la caché local, sin subirlo.
  @override
  void insertSeed(String userId, CourierProfile profile) =>
      _cache.setProfile(userId, profile);

  /// Traduce el vehículo guardado a su enum.
  static Vehicle _vehicle(String? value) => switch (value) {
    'bicycle' => Vehicle.bicycle,
    'scooter' => Vehicle.scooter,
    'walking' => Vehicle.walking,
    _ => Vehicle.moto,
  };

  /// Traduce el vehículo del perfil al valor de la base.
  static String _vehicleValue(Vehicle value) => switch (value) {
    Vehicle.bicycle => 'bicycle',
    Vehicle.scooter => 'scooter',
    Vehicle.walking => 'walking',
    Vehicle.moto => 'moto',
  };

  /// Cierra el stream de cambios.
  void dispose() => _cache.dispose();
}
