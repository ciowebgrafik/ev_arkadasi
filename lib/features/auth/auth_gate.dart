import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home_page.dart';
import '../profile/profil_olustur_sayfasi.dart';
import 'auth_page.dart'; // giriş ekranın (şifreyle giriş + kod ile giriş + kayıt)
import 'sifre_olustur_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  bool _hasProfile = false;
  bool _hasPassword = false;
  String? _error;

  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();

    // ✅ 1) PASSWORD RECOVERY (Şifre sıfırlama linkinden gelen kullanıcıyı yakala)
    // Maildeki link açılıp app'e dönünce Supabase bu event'i yollar.
    _sub = supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      // ✅ Şifre sıfırlama linkinden geldiyse direkt şifre oluştur sayfasına git
      if (event == AuthChangeEvent.passwordRecovery && session != null) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => SifreOlusturPage(
              onPasswordCreated: () async {
                await _checkProfile();
              },
            ),
          ),
          (route) => false,
        );
        return;
      }

      // Diğer login/logout değişikliklerinde normal akış
      await _checkProfile();
    });

    // İlk açılışta da kontrol
    _checkProfile();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _resetLocalState() {
    _hasProfile = false;
    _hasPassword = false;
    _loading = false;
    _error = null;
  }

  Future<void> _forceSignOutAndGoAuth() async {
    try {
      await supabase.auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    setState(_resetLocalState);
  }

  Future<void> _checkProfile() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = supabase.auth.currentUser;
      final session = supabase.auth.currentSession;

      // Oturum yoksa -> AuthPage
      if (user == null || session == null) {
        if (!mounted) return;
        setState(_resetLocalState);
        return;
      }

      // Profil + has_password kontrolü
      final data = await supabase
          .from('profiles')
          .select('id, has_password')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _hasProfile = data != null;
        _hasPassword = (data?['has_password'] ?? false) == true;
        _loading = false;
      });
    } on AuthException catch (e) {
      // Supabase'de user silindiyse telefonda session kalabiliyor
      if (e.statusCode == 403 || e.code == 'user_not_found') {
        await _forceSignOutAndGoAuth();
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = 'Auth hatası: ${e.message}';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Profil kontrol hatası: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;
    final user = supabase.auth.currentUser;

    // 1) Oturum yok -> AuthPage
    if (session == null || user == null) {
      return const AuthPage();
    }

    // 2) Loading
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 3) Hata
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Auth Gate')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: _checkProfile,
                      child: const Text('Tekrar dene'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _forceSignOutAndGoAuth,
                      child: const Text('Çıkış yap'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 4) Profil yok -> Profil oluştur
    if (!_hasProfile) {
      return ProfilOlusturSayfasi(
        onProfileSaved: () async {
          await _checkProfile();
        },
      );
    }

    // 5) Profil var ama şifre yok -> Şifre oluştur
    if (!_hasPassword) {
      return SifreOlusturPage(
        onPasswordCreated: () async {
          await _checkProfile();
        },
      );
    }

    // 6) Her şey tamam -> Home
    return const HomePage();
  }
}
