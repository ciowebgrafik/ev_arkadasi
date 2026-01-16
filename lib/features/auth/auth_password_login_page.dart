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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ✅ NORMAL ŞİFRE İLE GİRİŞ
  Future<void> _loginWithPassword() async {
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
      if (!mounted) return;
      _snack('Giriş başarılı ✅');
      Navigator.popUntil(context, (r) => r.isFirst); // AuthGate devam eder
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Giriş hatası: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ KAYIT OL → KOD GÖNDER
  void _goRegisterWithCode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AuthOtpRequestPage(isForgotPassword: false),
      ),
    );
  }

  // ✅ KOD İLE NORMAL GİRİŞ
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

  // 🔥 ŞİFREMİ UNUTTUM → SADECE KOD → ŞİFRE OLUŞTUR
  void _forgotPasswordAsCode() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('Şifremi unuttum için email gir.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthOtpRequestPage(
          initialEmail: email,
          isForgotPassword: true, // 🔥 KRİTİK
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text('Giriş', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),

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
                    icon: Icon(
                      _showPass ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

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
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _loginWithPassword,
                  child: Text(_loading ? 'İşleniyor...' : 'Giriş Yap'),
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _loading ? null : _goRegisterWithCode,
                  child: const Text('Kayıt Ol'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
