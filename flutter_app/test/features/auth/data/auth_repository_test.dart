import 'dart:convert';
import 'dart:typed_data';

import 'package:auth_lab/core/storage/secure_storage_service.dart';
import 'package:auth_lab/features/auth/data/auth_api_service.dart';
import 'package:auth_lab/features/auth/data/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTokenStorage implements TokenStorage {
  String? token;

  @override
  Future<void> deleteToken() async => token = null;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async => token = value;
}

class AuthFlowAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path == '/api/auth/login') {
      return _json({
        'success': true,
        'code': 200,
        'message': 'Signed in successfully.',
        'result': {
          'accessToken': 'application-token',
          'name': 'Demo User',
          'email': 'demo@test.com',
          'provider': 'password',
        },
      });
    }
    if (options.path == '/api/me') {
      return _json({
        'success': true,
        'code': 200,
        'message': 'Session restored.',
        'result': {
          'name': 'Demo User',
          'email': 'demo@test.com',
          'provider': 'password',
        },
      });
    }
    return _json({
      'success': false,
      'code': 404,
      'message': 'Not found.',
    }, statusCode: 404);
  }

  ResponseBody _json(Object body, {int statusCode = 200}) =>
      ResponseBody.fromString(
        jsonEncode(body),
        statusCode,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  test('login stores the app token and restoreSession reuses it', () async {
    final adapter = AuthFlowAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
    dio.httpClientAdapter = adapter;
    final storage = FakeTokenStorage();
    final repository = AuthRepository(AuthApiService(dio), storage);

    final login = await repository.login(
      email: 'demo@test.com',
      password: '123456',
    );
    final restored = await repository.restoreSession();

    expect(login.email, 'demo@test.com');
    expect(storage.token, 'application-token');
    expect(restored?.email, 'demo@test.com');
    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer application-token',
    );
  });

  test('logout removes the app token', () async {
    final adapter = AuthFlowAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
    dio.httpClientAdapter = adapter;
    final storage = FakeTokenStorage()..token = 'application-token';
    final repository = AuthRepository(AuthApiService(dio), storage);

    await repository.logout();

    expect(storage.token, isNull);
  });
}
