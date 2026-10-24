import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import 'auth_models.dart';

class AuthApiService {
  const AuthApiService(this._dio);

  final Dio _dio;

  Future<RegistrationResponse> register(RegisterRequest request) async {
    final response = await _send(
      'POST',
      '/api/auth/register',
      data: request.toJson(),
    );
    return ApiResult<RegistrationResponse>.fromJson(
      response,
      RegistrationResponse.fromJson,
    ).data;
  }

  Future<void> verifyEmail(VerifyEmailRequest request) async {
    final response = await _send(
      'POST',
      '/api/auth/email-verification/verify',
      data: request.toJson(),
    );
    _validateSuccessEnvelope(response);
  }

  Future<RegistrationResponse> resendEmailVerification(
    ResendEmailRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/api/auth/email-verification/resend',
      data: request.toJson(),
    );
    return ApiResult<RegistrationResponse>.fromJson(
      response,
      RegistrationResponse.fromJson,
    ).data;
  }

  Future<LoginResponse> login(LoginRequest request) async {
    final response = await _send(
      'POST',
      '/api/auth/login',
      data: request.toJson(),
    );
    return ApiResult<LoginResponse>.fromJson(
      response,
      LoginResponse.fromJson,
    ).data;
  }

  Future<LoginResponse> loginWithGoogle(String accessToken) async {
    final response = await _send(
      'POST',
      '/api/auth/google',
      data: {'accessToken': accessToken},
    );
    return ApiResult<LoginResponse>.fromJson(
      response,
      LoginResponse.fromJson,
    ).data;
  }

  Future<UserSession> restoreSession(String accessToken) async {
    final response = await _send(
      'GET',
      '/api/me',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    return ApiResult<UserSession>.fromJson(response, UserSession.fromJson).data;
  }

  Future<JsonMap> _send(
    String method,
    String path, {
    Object? data,
    Map<String, Object?>? headers,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        path,
        data: data,
        options: Options(method: method, headers: headers),
      );
      return _asJsonMap(response.data);
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  JsonMap _asJsonMap(Object? value) {
    if (value is JsonMap) return value;
    throw const ApiException('Server returned an invalid response.');
  }

  ApiException _mapDioException(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const ApiException('Request timed out. Please try again.');
    }
    if (error.type == DioExceptionType.connectionError) {
      return const ApiException('Cannot connect to the server.');
    }

    final statusCode = error.response?.statusCode;
    final body = error.response?.data;
    if (body is JsonMap && body['message'] is String) {
      return ApiException(body['message'] as String, statusCode: statusCode);
    }
    if (error.response != null) {
      return ApiException(
        'Server returned an invalid response.',
        statusCode: statusCode,
      );
    }
    return const ApiException('Unexpected network error.');
  }

  void _validateSuccessEnvelope(Object? value) {
    if (value is! JsonMap ||
        value['success'] != true ||
        value['code'] is! int ||
        value['message'] is! String) {
      throw const ApiException('Invalid API response.');
    }
  }
}
