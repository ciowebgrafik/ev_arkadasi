import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_gate.dart';

class AuthMagicLinkPage extends StatefulWidget {
  const AuthMagicLinkPage({super.key});

  @override
  State<AuthMagicLinkPage> createState() => _AuthMagicLinkPageState();
}

class _AuthMagicLinkPageState extends State<AuthMagicLinkPage> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _loading = false;
  bool _codeSent = false;

  final _sb = Supabase.instance.client;

  // ✅ Supabase panelindeki "Email OTP Length" sende 8 görünüyor
  // Panelde 6 yaparsan burayı da 6 yap.
  static const int _otpLength = 6;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _msg('Geçerli bir email gir');
      return;
    }

    setState(() => _loading = true);
    try {
      // ✅ OTP / Magic link gönderir + redirect ayarlı
      await _sb.auth.signInWithOtp(
        email: email,
          shouldCreateUser: true,
      );

      if (!mounted) return;
      setState(() => _codeSent = true);
      _msg('Kod / link gönderildi ✅ Mailini kontrol et.');
    } catch (e) {
      _msg('Hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailCtrl.text.trim();
    final token = _codeCtrl.text.trim();

    if (email.isEmpty) {
      _msg('Email boş olamaz');
      return;
    }
    if (token.length != _otpLength) {
      _msg('$_otpLength haneli kodu gir');
      return;
    }

    setState(() => _loading = true);
    try {
      // ✅ Doğru method: verifyOTP
      await _sb.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );

      if (!mounted) return;
      _msg('Giriş başarılı ✅');

      // ✅ AuthGate session'ı görüp yönlendirir
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    } catch (e) {
      _msg('Kod doğrulanamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giriş / Kayıt (Kod ile)')),
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

            if (_codeSent) ...[
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '$_otpLength haneli kod',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _loading
                    ? null
                    : (_codeSent ? _verifyCode : _sendCode),
                child: Text(
                  _loading
                      ? 'Bekle...'
                      : (_codeSent ? 'Kodu Doğrula' : 'Kod Gönder'),
                ),
              ),
            ),

            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading
                  ? null
                  : () {
                setState(() {
                  _codeSent = false;
                  _codeCtrl.clear();
                });
              },
              child: const Text('Kod gelmedi / tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}