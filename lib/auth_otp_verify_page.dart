import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthOtpVerifyPage extends StatefulWidget {
  final String email;
  const AuthOtpVerifyPage({super.key, required this.email});

  @override
  State<AuthOtpVerifyPage> createState() => _AuthOtpVerifyPageState();
}

class _AuthOtpVerifyPageState extends State<AuthOtpVerifyPage> {
  final _codeCtrl = TextEditingController();

  bool _loadingVerify = false;
  bool _loadingResend = false;

  Timer? _timer;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final token = _codeCtrl.text.trim();

    if (token.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('6 haneli kodu gir.')),
      );
      return;
    }

    setState(() => _loadingVerify = true);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: token,
        type: OtpType.email,
      );

      if (!mounted) return;

      // Giriş oldu. AuthGate yakalayıp yönlendirecek.
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kod doğrulanamadı: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingVerify = false);
    }
  }

  Future<void> _resendCode() async {
    if (_secondsLeft > 0) return;

    setState(() => _loadingResend = true);
    try {
      final sb = Supabase.instance.client;

      await sb.auth.signInWithOtp(
        email: widget.email,
        // istersen burada emailRedirectTo web için eklenebilir
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeni kod gönderildi ✅')),
      );

      _startTimer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kod tekrar gönderilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingResend = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resendEnabled = _secondsLeft == 0 && !_loadingResend;

    return Scaffold(
      appBar: AppBar(title: const Text('Kodu Doğrula')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Kod şu maile gitti:\n${widget.email}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '6 Haneli Kod',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loadingVerify ? null : _verify,
                child: Text(_loadingVerify ? 'Doğrulanıyor...' : 'Doğrula ve Giriş Yap'),
              ),
            ),

            const SizedBox(height: 12),

            // ⏳ Sayaç + Tekrar gönder
            Row(
              children: [
                Expanded(
                  child: Text(
                    _secondsLeft > 0
                        ? 'Tekrar kod göndermek için: $_secondsLeft sn'
                        : 'Kod gelmediyse tekrar gönderebilirsin.',
                  ),
                ),
                TextButton(
                  onPressed: resendEnabled ? _resendCode : null,
                  child: Text(_loadingResend ? 'Gönderiliyor...' : 'Tekrar Gönder'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}