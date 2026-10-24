import 'auth_models.dart';

abstract interface class AuthGateway {
  Future<UserSession> login({required String email, required String password});

  Future<RegistrationResponse> register({
    required String name,
    required String email,
    required String password,
  });

  Future<void> verifyEmail({
    required String verificationId,
    required String otp,
  });

  Future<RegistrationResponse> resendEmailVerification({
    required String verificationId,
    required String email,
  });

  Future<UserSession> loginWithGoogle(String accessToken);
  Future<UserSession?> restoreSession();
  Future<void> logout();
}
