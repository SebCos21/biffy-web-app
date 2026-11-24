/// Verificación universitaria de una cuenta. Es inmutable.
///
/// [verifiedUniversityId] es `null` si no hay verificación (o se revocó);
/// [email] y [expiresAt] se conservan aun vencida, para poder revalidar.
class UniversityStatus {
  /// Crea el estado; por defecto sin verificación.
  const UniversityStatus({
    this.verifiedUniversityId,
    this.email,
    this.expiresAt,
  });

  /// Universidad verificada (sin mirar el vencimiento).
  final String? verifiedUniversityId;

  /// Correo institucional usado para verificar.
  final String? email;

  /// Fecha en la que vence la verificación.
  final DateTime? expiresAt;

  /// `true` si la verificación está activa en el instante [now].
  bool isActiveAt(DateTime now) {
    if (verifiedUniversityId == null) return false;
    final until = expiresAt;
    return until == null || until.isAfter(now);
  }

  /// Copia el estado cambiando solo lo indicado ([clearVerified] quita la
  /// universidad verificada).
  UniversityStatus copyWith({
    String? verifiedUniversityId,
    String? email,
    DateTime? expiresAt,
    bool clearVerified = false,
  }) => UniversityStatus(
    verifiedUniversityId: clearVerified
        ? null
        : (verifiedUniversityId ?? this.verifiedUniversityId),
    email: email ?? this.email,
    expiresAt: expiresAt ?? this.expiresAt,
  );
}

/// Verificación guardada en el perfil del servidor.
class UniversityRecord {
  /// Crea el registro leído de `profiles`.
  const UniversityRecord({
    required this.verified,
    this.universityId,
    this.email,
    this.status,
    this.expiresAt,
  });

  /// `true` si el servidor la marca como verificada.
  final bool verified;

  /// Universidad elegida o verificada.
  final String? universityId;

  /// Correo institucional.
  final String? email;

  /// Estado en el servidor (`active`, `revoked`…).
  final String? status;

  /// Vencimiento.
  final DateTime? expiresAt;
}
