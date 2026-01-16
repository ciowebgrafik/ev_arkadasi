import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ DOĞRU YOLLAR (AuthGate: lib/features/auth/auth_gate.dart varsayımıyla)
import '../../listings/home_page.dart';
import '../profile/profil_olustur_sayfasi.dart';
import 'auth_page.dart';
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

  // ✅ aynı anda 2 kere sayfa açılmasını engeller
  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    _sub = supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      // ✅ Password recovery linkinden geldiyse → şifre oluştur (eski akış)
      if (event == AuthChangeEvent.passwordRecovery && session != null) {
        if (!mounted) return;
        await _openPasswordCreateFlow(forceOpen: true);
        return;
      }

      await _checkProfile();
      await _maybeNavigate();
    });

    _checkProfile().then((_) => _maybeNavigate());
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

    // ✅ FIX: setState callback
    setState(() => _resetLocalState());
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

      // ✅ Oturum yoksa -> AuthPage
      if (user == null || session == null) {
        if (!mounted) return;

        // ✅ FIX: setState callback
        setState(() => _resetLocalState());
        return;
      }

      // ✅ profiles tablosu kontrol (id + has_password)
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

  // ✅ Şifre oluştur ekranını güvenli şekilde aç
  Future<void> _openPasswordCreateFlow({bool forceOpen = false}) async {
    if (!mounted) return;
    if (_navigating) return;

    final session = supabase.auth.currentSession;
    final user = supabase.auth.currentUser;
    if (!forceOpen && (session == null || user == null)) return;

    _navigating = true;
    try {
      final result = await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SifreOlusturPage()));

      // result true geldiyse (Navigator.pop(true)) → profili tekrar kontrol et
      if (!mounted) return;
      if (result == true) {
        await _checkProfile();
      }
    } finally {
      _navigating = false;
    }
  }

  // ✅ Profil yoksa / şifre yoksa otomatik doğru sayfaya git
  Future<void> _maybeNavigate() async {
    if (!mounted) return;
    if (_loading || _error != null) return;

    if (_hasProfile && !_hasPassword) {
      await _openPasswordCreateFlow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;
    final user = supabase.auth.currentUser;

    // ✅ 1) Oturum yok -> AuthPage
    if (session == null || user == null) {
      return const AuthPage();
    }

    // ✅ 2) Loading
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ✅ 3) Hata
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
                      onPressed: () async {
                        await _checkProfile();
                        await _maybeNavigate();
                      },
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

    // ✅ 4) Profil yok -> Profil oluştur (return ile)
    if (!_hasProfile) {
      return ProfilOlusturSayfasi(
        onProfileSaved: () async {
          await _checkProfile();
          await _maybeNavigate();
        },
      );
    }

    // ✅ 5) Profil var ama şifre yoksa → _maybeNavigate push yapar, burada beklet
    if (!_hasPassword) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ✅ 6) Her şey tamam -> Home
    return const HomePage();
  }
}
