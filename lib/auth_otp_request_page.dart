import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_otp_verify_page.dart';

class AuthOtpRequestPage extends StatefulWidget {
  const AuthOtpRequestPage({super.key});

  @override
  State<AuthOtpRequestPage> createState() => _AuthOtpRequestPageState();
}

class _AuthOtpRequestPageState extends State<AuthOtpRequestPage> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir email gir.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AuthOtpVerifyPage(email: email),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kod gönderilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giriş / Kayıt (Kod)')),
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
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendCode,
                child: Text(_loading ? 'Gönderiliyor...' : 'Kodu Gönder'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mailine 6 haneli kod gelecek. Kodla giriş yapacağız.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}