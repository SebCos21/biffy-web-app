import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/university/university_usecases.dart';

/// Estado inmutable de la verificación universitaria: [revision] sube con
/// cada cambio del repositorio para que las pantallas se vuelvan a pintar.
final class UniversityState {
  /// Crea el estado.
  const UniversityState({this.revision = 0});

  /// Contador de cambios.
  final int revision;

  /// Copia el estado con la revisión indicada.
  UniversityState copyWith({int? revision}) =>
      UniversityState(revision: revision ?? this.revision);
}

/// Cubit global de la verificación universitaria: las pantallas leen si la
/// cuenta es estudiante verificada y eligen su universidad. El flujo del
/// código vive en `UniversityVerificationCubit` (pantalla Campus).
class UniversityCubit extends Cubit<UniversityState> {
  /// Escucha los cambios del repositorio.
  UniversityCubit(this.useCases) : super(const UniversityState()) {
    _changes = useCases.repo.changes.listen((_) => _bump());
  }

  /// Casos de uso de la verificación ya cableados.
  final UniversityUseCases useCases;
  StreamSubscription<void>? _changes;

  /// `true` si la cuenta tiene una verificación activa y no vencida.
  bool isVerifiedStudent(String? userId) =>
      useCases.queries.isVerifiedStudent(userId);

  /// Universidad verificada vigente, o `null`.
  String? verifiedUniversityId(String? userId) =>
      useCases.queries.verifiedUniversityId(userId);

  /// Fecha en la que vence la verificación.
  DateTime? expiresAt(String? userId) => useCases.queries.expiresAt(userId);

  /// Correo institucional guardado.
  String? emailOf(String? userId) => useCases.queries.emailOf(userId);

  /// Universidad verificada o la elegida en preferencias.
  String? universityIdOf(String? userId) =>
      useCases.queries.universityIdOf(userId);

  /// Elige la universidad (en demo descarta una verificación de otra).
  void choose(String? userId, String? universityId) {
    useCases.choose(userId, universityId);
    _bump();
  }

  /// Sube la revisión cuando cambia el repositorio.
  void _bump() {
    if (!isClosed) emit(state.copyWith(revision: state.revision + 1));
  }

  /// Cancela la escucha del repositorio.
  @override
  Future<void> close() {
    _changes?.cancel();
    return super.close();
  }
}
