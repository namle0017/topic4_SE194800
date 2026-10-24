import 'dart:convert';
import 'dart:typed_data';

import 'package:auth_lab/core/network/api_exception.dart';
import 'package:auth_lab/features/auth/data/auth_api_service.dart';
import 'package:auth_lab/features/auth/data/auth_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

typedef AdapterHandler = Future<ResponseBody> Function(RequestOptions options);

class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.handler);

  final AdapterHandler handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, {int statusCode = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

Dio buildDio(RecordingAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  test(
    'login sends credentials to the login endpoint and parses session',
    () async {
      final adapter = RecordingAdapter(
        (options) async => jsonResponse({
          'success': true,
          'code': 200,
          'message': 'Signed in successfully.',
          'result': {
            'accessToken': 'application-token',
            'name': 'Demo User',
            'email': 'demo@test.com',
            'provider': 'password',
          },
        }),
      );
      final service = AuthApiService(buildDio(adapter));

      final result = await service.login(
        const LoginRequest(email: 'demo@test.com', password: '123456'),
      );

      expect(result.accessToken, 'application-token');
      expect(result.session.email, 'demo@test.com');
      expect(adapter.requests.single.path, '/api/auth/login');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.data, {
        'email': 'demo@test.com',
        'password': '123456',
      });
    },
  );

  test(
    'restoreSession sends the application token as a bearer token',
    () async {
      final adapter = RecordingAdapter(
        (options) async => jsonResponse({
          'success': true,
          'code': 200,
          'message': 'Session restored.',
          'result': {
            'name': 'Demo User',
            'email': 'demo@test.com',
            'provider': 'password',
          },
        }),
      );
      final service = AuthApiService(buildDio(adapter));

      final session = await service.restoreSession('application-token');

      expect(session.email, 'demo@test.com');
      expect(adapter.requests.single.path, '/api/me');
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer application-token',
      );
    },
  );

  test('non-JSON response becomes a stable ApiException', () async {
    final adapter = RecordingAdapter(
      (options) async => ResponseBody.fromString(
        '<html>bad gateway</html>',
        502,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      ),
    );
    final service = AuthApiService(buildDio(adapter));

    expect(
      () => service.login(
        const LoginRequest(email: 'demo@test.com', password: '123456'),
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Server returned an invalid response.',
        ),
      ),
    );
  });

  test('timeout becomes a stable ApiException', () async {
    final adapter = RecordingAdapter((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      );
    });
    final service = AuthApiService(buildDio(adapter));

    expect(
      () => service.login(
        const LoginRequest(email: 'demo@test.com', password: '123456'),
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Request timed out. Please try again.',
        ),
      ),
    );
  });

  test('connection error becomes a stable ApiException', () async {
    final adapter = RecordingAdapter((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });
    final service = AuthApiService(buildDio(adapter));

    expect(
      () => service.login(
        const LoginRequest(email: 'demo@test.com', password: '123456'),
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Cannot connect to the server.',
        ),
      ),
    );
  });
}
