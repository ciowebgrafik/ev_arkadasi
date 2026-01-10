import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SifreOlusturPage extends StatefulWidget {
  final Future<void> Function()? onPasswordCreated;

  const SifreOlusturPage({super.key, this.onPasswordCreated});

  @override
  State<SifreOlusturPage> createState() => _SifreOlusturPageState();
}

class _SifreOlusturPageState extends State<SifreOlusturPage> {
  static const Color kTurkuaz = Color(0xFF00B8D4);

  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();

  bool _loading = false;
  bool _show1 = false;
  bool _show2 = false;

  @override
  void dispose() {
    _pass1.dispose();
    _pass2.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  bool _hasSpecial(String s) {
    final reg = RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\];'`~]''');
    return reg.hasMatch(s);
  }

  // ✅ güçlü şifre: 8+ / büyük / küçük / rakam / özel
  String? _validateStrongPassword(String p) {
    if (p.length < 8) return 'En az 8 karakter olmalı';
    if (!RegExp(r'[A-Z]').hasMatch(p)) return 'En az 1 BÜYÜK harf olmalı';
    if (!RegExp(r'[a-z]').hasMatch(p)) return 'En az 1 küçük harf olmalı';
    if (!RegExp(r'\d').hasMatch(p)) return 'En az 1 rakam olmalı';
    if (!_hasSpecial(p)) return 'En az 1 özel karakter olmalı';
    return null;
  }

  Future<void> _createPassword() async {
    final p1 = _pass1.text;
    final p2 = _pass2.text;

    final err = _validateStrongPassword(p1);
    if (err != null) {
      _snack(err);
      return;
    }
    if (p1 != p2) {
      _snack('Şifreler aynı değil');
      return;
    }

    setState(() => _loading = true);
    try {
      final sb = Supabase.instance.client;
      final user = sb.auth.currentUser;
      if (user == null) {
        _snack('Oturum bulunamadı. Lütfen tekrar giriş yap.');
        return;
      }

      // 1) Auth şifre set
      await sb.auth.updateUser(UserAttributes(password: p1));

      // 2) profiles.has_password = true
      await sb
          .from('profiles')
          .update({
            'has_password': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      if (!mounted) return;
      _snack('Şifre oluşturuldu ✅');

      await widget.onPasswordCreated?.call();

      // ✅ Nereden açarsan aç: geri dönmek istersen
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Şifre oluşturma hatası: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _ruleRow(bool ok, String text) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: ok ? Colors.green : Colors.black26,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _pass1.text;

    final has8 = p.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(p);
    final hasLower = RegExp(r'[a-z]').hasMatch(p);
    final hasDigit = RegExp(r'\d').hasMatch(p);
    final hasSpec = _hasSpecial(p);

    // ✅ EN GARANTİ: Scaffold + Material burada
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        title: const Text('Şifre Oluştur'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                const SizedBox(height: 4),
                const Text(
                  'Bundan sonra email + şifre ile gireceksin.\n'
                  'Şifreni unutursan “Şifremi unuttum” ile mailden sıfırlarsın.',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _pass1,
                  obscureText: !_show1,
                  enabled: !_loading,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Yeni şifre',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() => _show1 = !_show1),
                      icon: Icon(
                        _show1 ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _pass2,
                  obscureText: !_show2,
                  enabled: !_loading,
                  decoration: InputDecoration(
                    labelText: 'Yeni şifre (tekrar)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() => _show2 = !_show2),
                      icon: Icon(
                        _show2 ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ruleRow(has8, 'En az 8 karakter'),
                    _ruleRow(hasUpper, '1 büyük harf (A-Z)'),
                    _ruleRow(hasLower, '1 küçük harf (a-z)'),
                    _ruleRow(hasDigit, '1 rakam (0-9)'),
                    _ruleRow(hasSpec, '1 özel karakter (!@#...)'),
                  ],
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTurkuaz,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _loading ? null : _createPassword,
                    child: Text(
                      _loading ? 'Kaydediliyor...' : 'Şifreyi Kaydet',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),

            if (_loading)
              AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: Colors.black.withOpacity(0.12),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
