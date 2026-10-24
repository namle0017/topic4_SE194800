import '../../../core/network/api_exception.dart';

typedef JsonMap = Map<String, dynamic>;

class ApiResult<T> {
  const ApiResult({
    required this.code,
    required this.message,
    required this.data,
  });

  factory ApiResult.fromJson(Object? value, T Function(JsonMap) parseData) {
    if (value is! JsonMap ||
        value['success'] != true ||
        value['code'] is! int ||
        value['message'] is! String) {
      throw const ApiException('Invalid API response.');
    }
    final rawResult = value['result'];
    if (rawResult is! JsonMap) {
      throw const ApiException('Invalid API response: result is missing.');
    }
    return ApiResult<T>(
      code: value['code'] as int,
      message: value['message'] as String,
      data: parseData(rawResult),
    );
  }

  final int code;
  final String message;
  final T data;
}

class UserSession {
  const UserSession({
    required this.name,
    required this.email,
    required this.provider,
  });

  factory UserSession.fromJson(JsonMap json) {
    final name = json['name'];
    final email = json['email'];
    final provider = json['provider'];
    if (name is! String ||
        email is! String ||
        email.isEmpty ||
        provider is! String) {
      throw const ApiException('Invalid user session response.');
    }
    return UserSession(name: name, email: email, provider: provider);
  }

  final String name;
  final String email;
  final String provider;
}

class LoginResponse {
  const LoginResponse({required this.accessToken, required this.session});

  factory LoginResponse.fromJson(JsonMap json) {
    final accessToken = json['accessToken'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        json['email'] is! String) {
      throw const ApiException('Invalid login response.');
    }
    try {
      return LoginResponse(
        accessToken: accessToken,
        session: UserSession.fromJson(json),
      );
    } on ApiException {
      throw const ApiException('Invalid login response.');
    }
  }

  final String accessToken;
  final UserSession session;
}

class RegistrationResponse {
  const RegistrationResponse({
    required this.verificationId,
    required this.email,
    required this.cooldownSeconds,
  });

  factory RegistrationResponse.fromJson(JsonMap json) {
    final verificationId = json['verificationId'];
    final email = json['email'];
    final cooldownSeconds = json['cooldownSeconds'];
    if (verificationId is! String ||
        verificationId.isEmpty ||
        email is! String ||
        email.isEmpty ||
        cooldownSeconds is! int) {
      throw const ApiException('Invalid registration response.');
    }
    return RegistrationResponse(
      verificationId: verificationId,
      email: email,
      cooldownSeconds: cooldownSeconds,
    );
  }

  final String verificationId;
  final String email;
  final int cooldownSeconds;
}

class LoginRequest {
  const LoginRequest({required this.email, required this.password});
  final String email;
  final String password;
  JsonMap toJson() => {'email': email, 'password': password};
}

class RegisterRequest {
  const RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
  });
  final String name;
  final String email;
  final String password;
  JsonMap toJson() => {'name': name, 'email': email, 'password': password};
}

class VerifyEmailRequest {
  const VerifyEmailRequest({required this.verificationId, required this.otp});
  final String verificationId;
  final String otp;
  JsonMap toJson() => {'verificationId': verificationId, 'otp': otp};
}

class ResendEmailRequest {
  const ResendEmailRequest({required this.verificationId, required this.email});
  final String verificationId;
  final String email;
  JsonMap toJson() => {'verificationId': verificationId, 'email': email};
}
