import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_otp_verify_page.dart';

class AuthOtpRequestPage extends StatefulWidget {
  final String? initialEmail;
  final bool isForgotPassword;

  const AuthOtpRequestPage({
    super.key,
    this.initialEmail,
    this.isForgotPassword = false,
  });

  @override
  State<AuthOtpRequestPage> createState() => _AuthOtpRequestPageState();
}

class _AuthOtpRequestPageState extends State<AuthOtpRequestPage> {
  late final TextEditingController _emailCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _snack('Geçerli bir email gir.');
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        // ✅ Kayıt ise true, şifre unuttum / kodla giriş ise false
        shouldCreateUser: !widget.isForgotPassword,
      );

      if (!mounted) return;

      _snack('Kod mailine gönderildi ✅');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AuthOtpVerifyPage(
            email: email,
            isForgotPassword: widget.isForgotPassword,
          ),
        ),
      );
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Kod gönderilemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isForgotPassword ? 'Şifre Kurtarma' : 'Kod ile Giriş';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Emailini yaz, sana 6 haneli kod göndereceğiz.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _sendCode,
                child: Text(_loading ? 'Gönderiliyor...' : 'Kod Gönder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
