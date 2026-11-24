import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/user.dart';
import 'auth_bloc.dart';

/// Etapa del inicio de sesión.
enum LoginStatus { idle, submitting, success, error }

/// Estado del formulario de login: envío, error, usuario y visibilidad.
class LoginState {
  /// Crea el estado inicial.
  const LoginState({
    this.status = LoginStatus.idle,
    this.error,
    this.user,
    this.obscure = true,
  });

  /// Etapa actual del envío.
  final LoginStatus status;

  /// Mensaje de error para la pantalla.
  final String? error;

  /// Usuario autenticado cuando el login termina bien.
  final AppUser? user;

  /// `true` si la contraseña se muestra oculta.
  final bool obscure;

  /// `true` mientras se espera la respuesta del backend.
  bool get isSubmitting => status == LoginStatus.submitting;

  /// Copia el estado cambiando solo lo indicado.
  LoginState copyWith({
    LoginStatus? status,
    String? error,
    AppUser? user,
    bool? obscure,
  }) => LoginState(
    status: status ?? this.status,
    error: error,
    user: user ?? this.user,
    obscure: obscure ?? this.obscure,
  );
}

/// Cubit del login: valida el formulario, llama a la sesión y publica el error.
///
/// Flujo: pantalla → [LoginCubit] → [AuthBloc] (`LoginRequested`) → caso de
/// uso `SignIn` → `AuthRepository` (memoria o Supabase).
class LoginCubit extends Cubit<LoginState> {
  /// Recibe el Bloc de la sesión que ejecuta el login real.
  LoginCubit(this._auth) : super(const LoginState());

  final AuthBloc _auth;

  /// Alterna la visibilidad de la contraseña.
  void toggleObscure() => emit(state.copyWith(obscure: !state.obscure));

  /// Limpia el error al volver a escribir.
  void clearError() {
    if (state.error != null) emit(state.copyWith(status: LoginStatus.idle));
  }

  /// Inicia sesión y devuelve el usuario, o `null` si falló.
  Future<AppUser?> submit(String email, String password) async {
    if (state.isSubmitting) return null;
    emit(state.copyWith(status: LoginStatus.submitting));
    final result = await _auth.request(LoginRequested(email, password));
    if (isClosed) return result.user;
    if (result.ok) {
      emit(state.copyWith(status: LoginStatus.success, user: result.user));
      return result.user;
    }
    emit(state.copyWith(status: LoginStatus.error, error: result.message));
    return null;
  }
}
