import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profil_duzenle_sayfasi.dart';

class ProfilSayfasi extends StatefulWidget {
  const ProfilSayfasi({super.key});

  @override
  State<ProfilSayfasi> createState() => _ProfilSayfasiState();
}

class _ProfilSayfasiState extends State<ProfilSayfasi> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  String _error = '';

  String _fullName = '';
  String _phone = '';
  String _city = '';
  String _bio = '';
  String _email = '';
  String _avatarSignedUrl = '';
  String _avatarPath = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final data = await supabase
          .from('profiles')
          .select('full_name, phone, city, bio, avatar_path')
          .eq('id', user.id)
          .maybeSingle();

      final fullName = (data?['full_name'] ?? '').toString();
      final phone = (data?['phone'] ?? '').toString();
      final city = (data?['city'] ?? '').toString();
      final bio = (data?['bio'] ?? '').toString();
      final avatarPath = (data?['avatar_path'] ?? '').toString();

      String signed = '';
      if (avatarPath.isNotEmpty) {
        signed = await supabase.storage
            .from('avatars')
            .createSignedUrl(avatarPath, 60 * 60);

        final cb = DateTime.now().millisecondsSinceEpoch;
        signed = '$signed${signed.contains('?') ? '&' : '?'}cb=$cb';
      }

      if (!mounted) return;
      setState(() {
        _fullName = fullName;
        _phone = phone;
        _city = city;
        _bio = bio;
        _email = user.email ?? '';
        _avatarPath = avatarPath;
        _avatarSignedUrl = signed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Profil okunamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goEdit() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilDuzenleSayfasi()),
    );

    // ✅ Kaydettiyse direkt ana sayfaya dön
    if (updated == true) {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    // Kaydetmeden geri döndüyse sadece yenile
    await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider =
    _avatarSignedUrl.isNotEmpty ? NetworkImage(_avatarSignedUrl) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        actions: [
          IconButton(
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_error, textAlign: TextAlign.center),
      ))
          : RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: avatarProvider,
                  child: avatarProvider == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(_fullName.isEmpty ? 'İsimsiz' : _fullName),
                subtitle: Text(_email),
              ),
            ),
            const SizedBox(height: 12),

            _infoCard(
              icon: Icons.phone,
              label: 'Telefon',
              value: _phone,
            ),
            const SizedBox(height: 10),

            _infoCard(
              icon: Icons.location_city,
              label: 'Şehir',
              value: _city,
            ),
            const SizedBox(height: 10),

            _infoCard(
              icon: Icons.info_outline,
              label: 'Kısa bio',
              value: _bio,
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _goEdit,
                icon: const Icon(Icons.edit),
                label: const Text('Profili Düzenle'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aşağı çekerek yenileyebilirsin.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade100,
          child: Icon(icon),
        ),
        title: Text(label),
        subtitle: Text(value.isEmpty ? '-' : value),
      ),
    );
  }
}