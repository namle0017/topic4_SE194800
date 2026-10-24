import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'auth_api_service.dart';
import 'auth_gateway.dart';
import 'auth_models.dart';

class AuthRepository implements AuthGateway {
  const AuthRepository(this._api, this._storage);

  final AuthApiService _api;
  final TokenStorage _storage;

  @override
  Future<UserSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.login(
      LoginRequest(email: email, password: password),
    );
    await _storage.writeToken(response.accessToken);
    return response.session;
  }

  @override
  Future<RegistrationResponse> register({
    required String name,
    required String email,
    required String password,
  }) => _api.register(
    RegisterRequest(name: name, email: email, password: password),
  );

  @override
  Future<void> verifyEmail({
    required String verificationId,
    required String otp,
  }) => _api.verifyEmail(
    VerifyEmailRequest(verificationId: verificationId, otp: otp),
  );

  @override
  Future<RegistrationResponse> resendEmailVerification({
    required String verificationId,
    required String email,
  }) => _api.resendEmailVerification(
    ResendEmailRequest(verificationId: verificationId, email: email),
  );

  @override
  Future<UserSession> loginWithGoogle(String accessToken) async {
    final response = await _api.loginWithGoogle(accessToken);
    await _storage.writeToken(response.accessToken);
    return response.session;
  }

  @override
  Future<UserSession?> restoreSession() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) return null;
    try {
      return await _api.restoreSession(token);
    } on ApiException catch (error) {
      if (error.statusCode != 401) rethrow;
      await _storage.deleteToken();
      return null;
    }
  }

  @override
  Future<void> logout() => _storage.deleteToken();
}
