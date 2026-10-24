import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// Cấu hình qua --dart-define, KHÔNG hard-code secret:
//   flutter run --dart-define=BASE_URL=http://10.0.2.2:8080 \
//     --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=xxx
const _baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'http://localhost:8080',
);
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _redirect = 'authlab://login-callback';
bool get _supabaseOn => _supabaseUrl.isNotEmpty && _supabaseKey.isNotEmpty;

/// Người dùng hiện tại (từ API riêng hoặc Google).
class Session {
  Session(this.name, this.email, this.provider);
  final String name, email, provider;
}

/// Q2: gọi API thật + lưu token an toàn.
class AuthService {
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> body,
  ) async {
    final res = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400)
      throw Exception(data['message'] ?? 'Lỗi ${res.statusCode}');
    return data;
  }

  Future<void> register(String name, String email, String password) => _post(
    '/api/auth/register',
    {'name': name, 'email': email, 'password': password},
  );

  Future<Session> login(String email, String password) async {
    final d = await _post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    await _storage.write(key: 'token', value: d['accessToken']);
    return Session(d['name'], d['email'], 'API');
  }

  /// Khôi phục phiên khi mở lại app: gửi token lên /api/me.
  Future<Session?> restore() async {
    final t = await _storage.read(key: 'token');
    if (t == null) return null;
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/me'),
        headers: {'Authorization': 'Bearer $t'},
      );
      if (res.statusCode != 200) return null;
      final d = jsonDecode(res.body);
      return Session(d['name'], d['email'], 'API');
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'token');
    if (_supabaseOn) await Supabase.instance.client.auth.signOut();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_supabaseOn)
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
  runApp(const MaterialApp(home: Gate()));
}

/// Quyết định hiển thị Login hay Home dựa trên phiên hiện có.
class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  final auth = AuthService();
  Session? session;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    session = await auth.restore();
    if (_supabaseOn) {
      final u = Supabase.instance.client.auth.currentUser;
      if (session == null && u != null) session = _fromGoogle(u);
      // Q3: nhận session sau khi Google OAuth quay về qua deep link.
      Supabase.instance.client.auth.onAuthStateChange.listen((s) {
        final u = s.session?.user;
        if (u != null && mounted) setState(() => session = _fromGoogle(u));
      });
    }
    if (mounted) setState(() => ready = true);
  }

  Session _fromGoogle(User u) => Session(
    u.userMetadata?['full_name'] ?? u.userMetadata?['name'] ?? 'Google user',
    u.email ?? '',
    'Google',
  );

  @override
  Widget build(BuildContext context) {
    if (!ready)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (session == null)
      return LoginPage(auth: auth, onLogin: (s) => setState(() => session = s));
    return HomePage(
      session: session!,
      onLogout: () async {
        await auth.logout();
        setState(() => session = null);
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth, required this.onLogin});
  final AuthService auth;
  final void Function(Session) onLogin;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _pass = TextEditingController();
  bool _register = false, _loading = false;
  String? _error;

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await job();
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    _run(() async {
      final email = _email.text.trim();
      if (_register) {
        await widget.auth.register(_name.text.trim(), email, _pass.text);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng ký thành công, hãy đăng nhập')),
        );
        setState(() => _register = false);
      } else {
        widget.onLogin(await widget.auth.login(email, _pass.text));
      }
    });
  }

  void _google() => _run(() async {
    if (!_supabaseOn)
      throw Exception(
        'Chưa cấu hình SUPABASE_URL / SUPABASE_ANON_KEY (--dart-define)',
      );
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : _redirect,
      queryParams: {'prompt': 'select_account'},
    );
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_register ? 'Register' : 'Login')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _form,
        child: Column(
          children: [
            if (_register)
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nhập tên' : null,
              ),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Email không hợp lệ',
            ),
            TextFormField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Tối thiểu 6 ký tự' : null,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            if (_loading)
              const CircularProgressIndicator()
            else ...[
              ElevatedButton(
                onPressed: _submit,
                child: Text(_register ? 'Register' : 'Login'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _register = !_register;
                  _error = null;
                }),
                child: Text(
                  _register
                      ? 'Đã có tài khoản? Login'
                      : 'Chưa có tài khoản? Register',
                ),
              ),
              const Divider(),
              OutlinedButton.icon(
                onPressed: _google,
                icon: const Icon(Icons.g_mobiledata, size: 32),
                label: const Text('Continue with Google'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.session, required this.onLogout});
  final Session session;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Home')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✅ Authenticated', style: TextStyle(fontSize: 22)),
          Text(session.name),
          Text(session.email),
          Text('Provider: ${session.provider}'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onLogout, child: const Text('Logout')),
        ],
      ),
    ),
  );
}
