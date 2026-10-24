import 'package:auth_lab/core/network/api_exception.dart';
import 'package:auth_lab/features/auth/data/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiResult<LoginResponse>', () {
    test('parses a complete login envelope', () {
      final response = ApiResult<LoginResponse>.fromJson({
        'success': true,
        'code': 200,
        'message': 'Signed in successfully.',
        'result': {
          'accessToken': 'application-token',
          'name': 'Demo User',
          'email': 'demo@test.com',
          'provider': 'password',
        },
      }, LoginResponse.fromJson);

      expect(response.code, 200);
      expect(response.message, 'Signed in successfully.');
      expect(response.data.accessToken, 'application-token');
      expect(response.data.session.email, 'demo@test.com');
      expect(response.data.session.provider, 'password');
    });

    test('rejects an envelope without result data', () {
      expect(
        () => ApiResult<LoginResponse>.fromJson({
          'success': true,
          'code': 200,
          'message': 'ok',
        }, LoginResponse.fromJson),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Invalid API response: result is missing.',
          ),
        ),
      );
    });

    test('rejects login data without token or email', () {
      for (final invalid in [
        {'name': 'Demo', 'email': 'demo@test.com', 'provider': 'password'},
        {'accessToken': 'token', 'name': 'Demo', 'provider': 'password'},
      ]) {
        expect(
          () => LoginResponse.fromJson(invalid),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              'Invalid login response.',
            ),
          ),
        );
      }
    });

    test('rejects an envelope with invalid field types', () {
      expect(
        () => ApiResult<LoginResponse>.fromJson({
          'success': true,
          'code': '200',
          'message': 'ok',
          'result': <String, dynamic>{},
        }, LoginResponse.fromJson),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Invalid API response.',
          ),
        ),
      );
    });
  });

  test('parses registration verification details', () {
    final response = RegistrationResponse.fromJson({
      'verificationId': 'verification-1',
      'email': 'demo@test.com',
      'cooldownSeconds': 60,
    });

    expect(response.verificationId, 'verification-1');
    expect(response.email, 'demo@test.com');
    expect(response.cooldownSeconds, 60);
  });
}
