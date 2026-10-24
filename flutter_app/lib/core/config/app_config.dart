import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._({
    required this.baseUrl,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.supabaseRedirectUrl,
  });

  static Future<AppConfig> load() async {
    await dotenv.load(fileName: '.env', isOptional: true);
    return AppConfig._(
      baseUrl: _read(
        const String.fromEnvironment('BASE_URL'),
        'BASE_URL',
        fallback: 'http://localhost:8080',
      ),
      supabaseUrl: _read(
        const String.fromEnvironment('SUPABASE_URL'),
        'SUPABASE_URL',
      ),
      supabasePublishableKey: _read(
        const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
        'SUPABASE_PUBLISHABLE_KEY',
        secondaryEnvironmentName: 'SUPABASE_ANON_KEY',
        secondaryCompileTimeValue: const String.fromEnvironment(
          'SUPABASE_ANON_KEY',
        ),
      ),
      supabaseRedirectUrl: _read(
        const String.fromEnvironment('SUPABASE_REDIRECT_URL'),
        'SUPABASE_REDIRECT_URL',
        fallback: 'authlab://login-callback',
      ),
    );
  }

  static String _read(
    String compileTimeValue,
    String environmentName, {
    String fallback = '',
    String? secondaryEnvironmentName,
    String secondaryCompileTimeValue = '',
  }) {
    if (compileTimeValue.isNotEmpty) return compileTimeValue;
    if (secondaryCompileTimeValue.isNotEmpty) {
      return secondaryCompileTimeValue;
    }
    final value = dotenv.env[environmentName];
    if (value != null && value.isNotEmpty) return value;
    if (secondaryEnvironmentName != null) {
      final secondaryValue = dotenv.env[secondaryEnvironmentName];
      if (secondaryValue != null && secondaryValue.isNotEmpty) {
        return secondaryValue;
      }
    }
    return fallback;
  }

  final String baseUrl;
  final String supabaseUrl;
  final String supabasePublishableKey;
  final String supabaseRedirectUrl;

  bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
