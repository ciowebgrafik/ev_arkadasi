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
      backgroundColor: const Color(0xFFF7F7F9),

      // ✅ FOTOĞRAFTAKİ GİBİ: GERİ OK + ORTADA PROFİL
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Profil',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        // hafif alt çizgi (foto gibi)
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.black12),
        ),
      ),

      body: SafeArea(
        top: false, // AppBar zaten safe area
        child: _loading
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
                child: LayoutBuilder(
                  builder: (context, c) {
                    const double maxW = 520;
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: maxW),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ✅ Üst kart (foto + isim + mail)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.black12.withOpacity(.06),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.grey.shade200,
                                        backgroundImage: avatarProvider,
                                        child: avatarProvider == null
                                            ? const Icon(
                                                Icons.person,
                                                size: 28,
                                                color: Colors.grey,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _fullName.isEmpty
                                                  ? 'İsimsiz'
                                                  : _fullName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _email.isEmpty ? '-' : _email,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.black.withOpacity(
                                                  .55,
                                                ),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
                                  maxLines: 3,
                                ),

                                const SizedBox(height: 14),

                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
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
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    int maxLines = 1,
  }) {
    final v = value.trim().isEmpty ? '-' : value.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12.withOpacity(.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade100,
            child: Icon(icon, size: 18, color: Colors.black87),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(.55),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  v,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
