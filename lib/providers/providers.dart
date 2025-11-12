import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../controllers/auth_controller.dart';
import '../services/auth_service.dart';
import '../services/local_service.dart';
import '../states/auth_state.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final localStorageProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthController(authService, ref);
});
