import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/app_page.dart';

class AuthOtpVerifyPage extends StatefulWidget {
  final String email;

  const AuthOtpVerifyPage({super.key, required this.email});

  @override
  State<AuthOtpVerifyPage> createState() => _AuthOtpVerifyPageState();
}

class _AuthOtpVerifyPageState extends State<AuthOtpVerifyPage> {
  static const int _otpLength = 6;

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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

    if (token.length != _otpLength) {
      _snack('$_otpLength haneli kodu gir.');
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

      _snack('Giriş başarılı ✅');
      // ✅ AuthGate session'ı yakalar ve yönlendirir
      Navigator.popUntil(context, (route) => route.isFirst);
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Kod doğrulanamadı: $e');
    } finally {
      if (mounted) setState(() => _loadingVerify = false);
    }
  }

  Future<void> _resendCode() async {
    if (_secondsLeft > 0) return;

    setState(() => _loadingResend = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: widget.email,
        shouldCreateUser: true,
      );

      if (!mounted) return;

      _snack('Yeni kod gönderildi ✅');
      _codeCtrl.clear();
      _startTimer();
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Kod tekrar gönderilemedi: $e');
    } finally {
      if (mounted) setState(() => _loadingResend = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resendEnabled = _secondsLeft == 0 && !_loadingResend;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            'Kodu Doğrula',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Kod şu maile gitti:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(widget.email, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),

          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '$_otpLength haneli kod',
              border: const OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _loadingVerify ? null : _verify,
              child: Text(
                _loadingVerify ? 'Doğrulanıyor...' : 'Doğrula ve Devam Et',
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Text(
                  _secondsLeft > 0
                      ? 'Tekrar kod için: $_secondsLeft sn'
                      : 'Kod gelmediyse tekrar gönderebilirsin.',
                ),
              ),
              TextButton(
                onPressed: resendEnabled ? _resendCode : null,
                child: Text(
                  _loadingResend ? 'Gönderiliyor...' : 'Tekrar Gönder',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
