
import '../models/user_model.dart';

class AuthState  {
  final bool isLoading;
  final bool isSuccess;
    final bool proceed;
    final bool isFailure;
  final String? error;
  final AppUser? user;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.user,
    this.isSuccess= false,
    this.proceed =false,
    this.isFailure = false
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    AppUser? user,
     bool? isSuccess,
     bool? proceed,
     bool? isFailure
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      user: user,
      isSuccess:isSuccess ?? this.isSuccess,
      proceed: proceed?? this.proceed,
      isFailure: isFailure?? this.isFailure
    );
  }

  @override
  List<Object?> get props => [isLoading, error, user,isSuccess,proceed,isFailure];
}
