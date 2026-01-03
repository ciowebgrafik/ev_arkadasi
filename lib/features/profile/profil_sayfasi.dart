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

  Future<String> _createSignedAvatarUrl(String path) async {
    if (path.trim().isEmpty) return '';
    try {
      var url = await supabase.storage
          .from('avatars')
          .createSignedUrl(path.trim(), 60 * 60);

      final cb = DateTime.now().millisecondsSinceEpoch;
      url = '$url${url.contains('?') ? '&' : '?'}cb=$cb';
      return url;
    } catch (_) {
      return '';
    }
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

      final fullName = (data?['full_name'] ?? '').toString().trim();
      final phone = (data?['phone'] ?? '').toString().trim();
      final city = (data?['city'] ?? '').toString().trim();
      final bio = (data?['bio'] ?? '').toString().trim();
      final avatarPath = (data?['avatar_path'] ?? '').toString().trim();

      final signed = await _createSignedAvatarUrl(avatarPath);

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
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProfilDuzenleSayfasi()),
    );

    // Kaydettiyse yenile
    if (updated == true) {
      await _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider = _avatarSignedUrl.isNotEmpty
        ? NetworkImage(_avatarSignedUrl)
        : null;

    return Scaffold(
      backgroundColor: Colors.white, // ✅ siyahlığı bitirir
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Profilim',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
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
          : (_error.isNotEmpty)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadProfile,
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                      title: Text(
                        _fullName.isEmpty ? 'İsimsiz' : _fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(_email.isEmpty ? '-' : _email),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _infoCard(icon: Icons.phone, label: 'Telefon', value: _phone),
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
                  const SizedBox(height: 10),

                  Text(
                    'Aşağı çekerek yenileyebilirsin.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),
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
          child: Icon(icon, color: Colors.black87),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(value.isEmpty ? '-' : value),
      ),
    );
  }
}
