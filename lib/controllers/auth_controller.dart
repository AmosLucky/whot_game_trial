import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/user_model.dart';
import '../providers/providers.dart';
import '../services/auth_service.dart';
import '../states/auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  final AuthService _authService;
  final Ref _ref;

  AuthController(this._authService, this._ref) : super(const AuthState());

  Future<void> register({
    required String fullname,
    required String username,
    required String email,
    required String phone,
    required String password,
    required String avatarUrl,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _authService.registerWithEmail(
        fullname: fullname,
        username: username,
        email: email,
        phone: phone,
        password: password,
        avatarUrl: avatarUrl,
      );

      if (response.success) {
        state = state.copyWith(isLoading: false,
        isSuccess: true, 
        user: AppUser.fromDoc(response.userSnapshot!));

      } else {
        state = state.copyWith(
            isLoading: false, error: response.message ?? 'Registration failed');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _authService.signInWithEmail(email: email, password: password);

      if (response.success == true) {
        state = state.copyWith(isLoading: false,
        isSuccess: true, 
        user: AppUser.fromDoc(response.userSnapshot!));
      } else {
        state = state.copyWith(
            isLoading: false, isSuccess: false, error: response.message ?? 'Login failed');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }


  Future autoLogin()async{
    print("object------------");
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _authService.autoLogin();

      if (response.success) {
        state = state.copyWith(isLoading: false,
        isSuccess: true, 
        isFailure: false,
        user: AppUser.fromDoc(response.userSnapshot!));
      } else {
        state = state.copyWith(
            isLoading: false, isSuccess: false, isFailure:true, error: response.message ?? 'Login failed');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, isFailure:true, error: e.toString());
    }

  }

  void logout() {
    state = const AuthState();
  }

  void reset() {
    state = const AuthState();
  }
}