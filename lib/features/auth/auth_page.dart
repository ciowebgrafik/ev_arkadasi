import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_otp_request_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  SupabaseClient get supabase => Supabase.instance.client;

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ✅ NORMAL ŞİFRE İLE GİRİŞ
  Future<void> _signInWithPassword() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      _msg('Email ve şifre boş olamaz');
      return;
    }

    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithPassword(email: email, password: pass);
      // AuthGate yönlendirecek
    } on AuthException catch (e) {
      _msg(e.message);
    } catch (e) {
      _msg('Hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ ŞİFREMİ UNUTTUM = KOD İLE GİRİŞ
  void _forgotPasswordAsCode() {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _msg('Şifremi unuttum için email gir.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthOtpRequestPage(
          initialEmail: email,
          isForgotPassword: true, // ✅ şifre sıfırlama akışı = OTP
        ),
      ),
    );
  }

  // ✅ KOD İLE GİRİŞ (normal login / kayıt)
  void _goCodeLogin() {
    final email = _emailCtrl.text.trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthOtpRequestPage(
          initialEmail: email.isNotEmpty ? email : null,
          isForgotPassword: false,
        ),
      ),
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
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Şifre',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ✅ Şifremi unuttum = OTP
            Row(
              children: [
                TextButton(
                  onPressed: _loading ? null : _forgotPasswordAsCode,
                  child: const Text('Şifremi unuttum'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _loading ? null : _goCodeLogin,
                  child: const Text('Kod ile giriş'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ✅ Giriş Yap
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _signInWithPassword,
                child: Text(_loading ? 'Bekle...' : 'Giriş Yap'),
              ),
            ),

            const SizedBox(height: 10),

            // ✅ Kayıt Ol = Kod ile giriş
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _loading ? null : _goCodeLogin,
                child: const Text('Kayıt Ol'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
