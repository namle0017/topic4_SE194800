// Question 1 - Mock Authentication (paste vào DartPad). Demo: demo@test.com / 123456
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: LoginPage()));

/// Giả lập backend: kiểm tra tài khoản demo, trả về mock token.
class AuthService {
  Future<String> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1)); // giả lập gọi API
    if (email == 'demo@test.com' && password == '123456') {
      return 'mock-token-${DateTime.now().millisecondsSinceEpoch}';
    }
    throw Exception('Sai email hoặc mật khẩu');
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _auth.login(_email.text.trim(), _pass.text);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(email: _email.text.trim(), token: token),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Login (Mock)')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _form,
        child: Column(
          children: [
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Email không được để trống';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                  return 'Email không hợp lệ';
                return null;
              },
            ),
            TextFormField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) {
                if (v == null || v.isEmpty)
                  return 'Password không được để trống';
                if (v.length < 6) return 'Password tối thiểu 6 ký tự';
                return null;
              },
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Login'),
                  ),
          ],
        ),
      ),
    ),
  );
}

/// Protected Home: chỉ vào được khi có token.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.email, required this.token});
  final String email, token;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Protected Home')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✅ Đã đăng nhập', style: TextStyle(fontSize: 22)),
          Text(email),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    ),
  );
}
