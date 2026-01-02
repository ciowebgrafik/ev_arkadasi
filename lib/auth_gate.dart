import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_password_login_page.dart';
import 'home_page.dart';
import 'profil_olustur_sayfasi.dart';
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

  String? _lastCheckedUserId;

  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();

    // İlk açılışta kontrol
    _checkProfile();

    // Auth değişikliklerini dinle (login/logout/refresh)
    _sub = supabase.auth.onAuthStateChange.listen((event) {
      // Her auth eventinde yeniden kontrol et
      _checkProfile();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _resetLocalState() {
    _lastCheckedUserId = null;
    _hasProfile = false;
    _hasPassword = false;
    _loading = false;
    _error = null;
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

      // Oturum yoksa temizle
      if (user == null || session == null) {
        if (!mounted) return;
        setState(_resetLocalState);
        return;
      }

      // Aynı user ise bile DB kontrolünü yine yapıyoruz (daha sağlam)
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
        _lastCheckedUserId = user.id;
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

    // 1) Oturum yok -> Şifre giriş sayfası
    if (session == null || user == null) {
      return const AuthPasswordLoginPage();
    }

    // 2) Loading
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
                ElevatedButton(
                  onPressed: _checkProfile,
                  child: const Text('Tekrar dene'),
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