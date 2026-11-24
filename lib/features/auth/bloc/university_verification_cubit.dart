import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/university_errors.dart';
import '../../../domain/usecases/university/university_usecases.dart';

/// Estado de la verificación del correo institucional.
class UniversityVerificationState {
  /// Crea el estado inicial; se sincroniza con la sesión al abrir Campus.
  const UniversityVerificationState({
    this.isVerified = false,
    this.expiresAt,
    this.codeSent = false,
    this.demoCode,
    this.sending = false,
    this.confirming = false,
    this.error,
  });

  /// `true` si la verificación está activa y no vencida.
  final bool isVerified;

  /// Fecha de vencimiento de la verificación.
  final DateTime? expiresAt;

  /// `true` cuando ya se envió un código y toca escribir el código.
  final bool codeSent;

  /// Código visible solo en modo demo.
  final String? demoCode;

  /// `true` mientras se envía el código.
  final bool sending;

  /// `true` mientras se confirma el código.
  final bool confirming;

  /// Último error para la pantalla.
  final String? error;

  /// Copia el estado cambiando solo lo indicado.
  UniversityVerificationState copyWith({
    bool? isVerified,
    DateTime? expiresAt,
    bool? codeSent,
    String? demoCode,
    bool? sending,
    bool? confirming,
    String? error,
  }) => UniversityVerificationState(
    isVerified: isVerified ?? this.isVerified,
    expiresAt: expiresAt ?? this.expiresAt,
    codeSent: codeSent ?? this.codeSent,
    demoCode: demoCode,
    sending: sending ?? this.sending,
    confirming: confirming ?? this.confirming,
    error: error,
  );
}

/// Cubit de Campus: envía el código, lo confirma y controla el vencimiento.
///
/// Las reglas (correo, dominio, códigos del servidor) viven en los casos de
/// uso de `domain/usecases/university`; este cubit solo expone el estado de
/// la pantalla y muestra el mensaje en español de cada resultado.
class UniversityVerificationCubit extends Cubit<UniversityVerificationState> {
  /// Sincroniza el estado inicial con la cuenta activa ([currentUserId]).
  UniversityVerificationCubit(this._useCases, this._currentUserId)
    : super(
        UniversityVerificationState(
          isVerified: _useCases.queries.isVerifiedStudent(_currentUserId()),
          expiresAt: _useCases.queries.expiresAt(_currentUserId()),
        ),
      );

  final UniversityUseCases _useCases;

  /// Id de la cuenta con sesión (o `null`).
  final String? Function() _currentUserId;

  /// Vuelve a leer el estado (por ejemplo al reabrir Campus).
  void refresh() {
    final id = _currentUserId();
    emit(
      state.copyWith(
        isVerified: _useCases.queries.isVerifiedStudent(id),
        expiresAt: _useCases.queries.expiresAt(id),
      ),
    );
  }

  /// Limpia el error al cambiar de campo.
  void clearError() {
    if (state.error != null) emit(state.copyWith(error: null));
  }

  /// Descarta el código pendiente al cambiar de universidad.
  void clearCode() =>
      emit(state.copyWith(codeSent: false, demoCode: null, error: null));

  /// Pide un código para el correo institucional.
  Future<void> sendCode({
    required String universityId,
    required String email,
    required bool renewal,
  }) async {
    if (state.sending) return;
    emit(state.copyWith(sending: true, error: null));
    final id = _currentUserId();
    final result = await _useCases.sendCode(
      id,
      universityId,
      email,
      renewal: renewal,
    );
    if (isClosed) return;

    if (result == VerifyResult.codeSent) {
      emit(
        state.copyWith(
          sending: false,
          codeSent: true,
          demoCode: _useCases.queries.pendingCodeOf(id),
        ),
      );
      return;
    }
    emit(state.copyWith(sending: false, error: verifyResultMessage(result)));
  }

  /// Confirma el código y activa Campus por 30 días.
  Future<void> confirmCode({
    required String universityId,
    required String email,
    required String code,
  }) async {
    if (state.confirming) return;
    emit(state.copyWith(confirming: true, error: null));
    final id = _currentUserId();
    final result = await _useCases.confirmCode(
      id,
      universityId: universityId,
      email: email,
      code: code,
    );
    if (isClosed) return;

    if (result == VerifyResult.ok) {
      emit(
        state.copyWith(
          confirming: false,
          codeSent: false,
          demoCode: null,
          isVerified: true,
          expiresAt: _useCases.queries.expiresAt(id),
        ),
      );
      return;
    }
    emit(state.copyWith(confirming: false, error: verifyResultMessage(result)));
  }
}
