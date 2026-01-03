import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_magic_link_page.dart';

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
      // AuthGate zaten yönlendirecek
    } on AuthException catch (e) {
      _msg(e.message);
    } catch (e) {
      _msg('Hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendResetPasswordEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _msg('Şifre sıfırlamak için email yazmalısın');
      return;
    }

    setState(() => _loading = true);
    try {
      // ✅ Supabase reset link gönderir
      await supabase.auth.resetPasswordForEmail(email);
      _msg('Şifre sıfırlama linki mailine gönderildi.');
    } on AuthException catch (e) {
      _msg(e.message);
    } catch (e) {
      _msg('Hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goMagicLink() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AuthMagicLinkPage()),
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

            // ✅ Şifremi unuttum / Kod ile giriş
            Row(
              children: [
                TextButton(
                  onPressed: _loading ? null : _sendResetPasswordEmail,
                  child: const Text('Şifremi unuttum'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _loading ? null : _goMagicLink,
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

            // ✅ Kayıt Ol = Kod ile giriş ekranı (OTP/Magic Link)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _loading ? null : _goMagicLink,
                child: const Text('Kayıt Ol'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
