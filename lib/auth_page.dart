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

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      _msg('Email ve şifre boş olamaz');
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: pass,
      );
    } on AuthException catch (e) {
      _msg(e.message);
    } catch (e) {
      _msg('Hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      _msg('Email ve şifre boş olamaz');
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: pass,
      );
      _msg('Kayıt tamam. Mail doğrulama gerekiyorsa mailini kontrol et.');
    } on AuthException catch (e) {
      _msg(e.message);
    } catch (e) {
      _msg('Hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giriş / Kayıt')),
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
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _signIn,
                child: Text(_loading ? 'Bekle...' : 'Giriş Yap'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _loading ? null : _signUp,
                child: const Text('Kayıt Ol'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _loading
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AuthMagicLinkPage(),
                        ),
                      );
                    },
              child: const Text('Magic Link ile giriş'),
            ),
          ],
        ),
      ),
    );
  }
}