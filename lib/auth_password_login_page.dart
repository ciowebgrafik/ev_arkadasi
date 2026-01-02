import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_otp_request_page.dart';

class AuthPasswordLoginPage extends StatefulWidget {
  const AuthPasswordLoginPage({super.key});

  @override
  State<AuthPasswordLoginPage> createState() => _AuthPasswordLoginPageState();
}

class _AuthPasswordLoginPageState extends State<AuthPasswordLoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _showPass = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || !email.contains('@')) {
      _snack('Geçerli bir email gir.');
      return;
    }
    if (pass.isEmpty) {
      _snack('Şifre boş olamaz.');
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: pass,
      );
      // AuthGate zaten yakalayıp yönlendirecek
    } catch (e) {
      _snack('Giriş hatası: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _snack('Şifremi unuttum için email gir.');
      return;
    }

    setState(() => _loading = true);
    try {
      // ✅ Supabase reset link gönderir (kod değil)
      // Deep link sonra ayrıca ayarlanabilir; şimdilik link mailden açılır.
      await Supabase.instance.client.auth.resetPasswordForEmail(email);

      _snack('Şifre yenileme linki mailine gönderildi ✅');
    } catch (e) {
      _snack('Link gönderilemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goOtp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AuthOtpRequestPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giriş')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: !_showPass,
              decoration: InputDecoration(
                labelText: 'Şifre',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _showPass = !_showPass),
                  icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                TextButton(
                  onPressed: _loading ? null : _forgotPassword,
                  child: const Text('Şifremi unuttum'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _loading ? null : _goOtp,
                  child: const Text('Kod ile giriş'),
                ),
              ],
            ),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: Text(_loading ? 'Giriş yapılıyor...' : 'Giriş Yap'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}