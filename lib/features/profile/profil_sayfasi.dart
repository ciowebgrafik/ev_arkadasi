import 'package:ev_arkadasi/core/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profil_duzenle_sayfasi.dart';

class ProfilSayfasi extends StatefulWidget {
  const ProfilSayfasi({super.key});

  @override
  State<ProfilSayfasi> createState() => _ProfilSayfasiState();
}

class _ProfilSayfasiState extends State<ProfilSayfasi> {
  static const Color kTurkuaz = Color(0xFF00B8D4);

  final supabase = Supabase.instance.client;

  bool _loading = true;
  String _error = '';

  String _fullName = '';
  String _phone = '';
  String _city = '';
  String _district = '';
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

      // cache bust (foto güncellenince anında değişsin)
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

    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final data = await supabase
          .from('profiles')
          .select('full_name, phone, city, district, bio, avatar_path')
          .eq('id', user.id)
          .maybeSingle();

      final fullName = (data?['full_name'] ?? '').toString().trim();
      final phone = (data?['phone'] ?? '').toString().trim();
      final city = (data?['city'] ?? '').toString().trim();
      final district = (data?['district'] ?? '').toString().trim();
      final bio = (data?['bio'] ?? '').toString().trim();
      final avatarPath = (data?['avatar_path'] ?? '').toString().trim();

      final signed = await _createSignedAvatarUrl(avatarPath);

      if (!mounted) return;
      setState(() {
        _fullName = fullName;
        _phone = phone;
        _city = city;
        _district = district;
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

    // ✅ Şehir + İlçe tek satır gösterim
    final locationText = [
      _city.trim(),
      _district.trim(),
    ].where((e) => e.isNotEmpty).join(' / ');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Profil',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: AppUI.fs(context, 16),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error.isNotEmpty)
            ? Center(
                child: Padding(
                  padding: EdgeInsets.all(AppUI.gap(context, 16)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error, textAlign: TextAlign.center),
                      SizedBox(height: AppUI.gap(context, 12)),
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
                      padding: EdgeInsets.fromLTRB(
                        AppUI.gap(context, 16),
                        AppUI.gap(context, 16),
                        AppUI.gap(context, 16),
                        AppUI.gap(context, 24),
                      ),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: maxW),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(
                                    AppUI.gap(context, 16),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      AppUI.r(context, 18),
                                    ),
                                    border: Border.all(
                                      color: Colors.black12.withOpacity(.06),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: AppUI.r(context, 30),
                                        backgroundColor: Colors.grey.shade200,
                                        backgroundImage: avatarProvider,
                                        child: avatarProvider == null
                                            ? Icon(
                                                Icons.person,
                                                size: AppUI.fs(context, 28),
                                                color: Colors.grey,
                                              )
                                            : null,
                                      ),
                                      SizedBox(width: AppUI.gap(context, 14)),
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
                                              style: TextStyle(
                                                fontSize: AppUI.fs(context, 16),
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            SizedBox(
                                              height: AppUI.gap(context, 4),
                                            ),
                                            Text(
                                              _email.isEmpty ? '-' : _email,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.black.withOpacity(
                                                  .55,
                                                ),
                                                fontWeight: FontWeight.w500,
                                                fontSize: AppUI.fs(context, 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: AppUI.gap(context, 12)),
                                _infoCard(
                                  icon: Icons.phone,
                                  label: 'Telefon',
                                  value: _phone,
                                ),
                                SizedBox(height: AppUI.gap(context, 10)),
                                _infoCard(
                                  icon: Icons.location_on_outlined,
                                  label: 'Konum',
                                  value: locationText,
                                  maxLines: 2,
                                ),
                                SizedBox(height: AppUI.gap(context, 10)),
                                _infoCard(
                                  icon: Icons.info_outline,
                                  label: 'Kısa bio',
                                  value: _bio,
                                  maxLines: 3,
                                ),
                                SizedBox(height: AppUI.gap(context, 14)),
                                SizedBox(
                                  width: double.infinity,
                                  height: AppUI.gap(context, 50),
                                  child: ElevatedButton.icon(
                                    onPressed: _goEdit,
                                    icon: const Icon(Icons.edit),
                                    label: Text(
                                      'Profili Düzenle',
                                      style: TextStyle(
                                        fontSize: AppUI.fs(context, 14),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: AppUI.gap(context, 10)),
                                Text(
                                  'Aşağı çekerek yenileyebilirsin.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontSize: AppUI.fs(context, 12),
                                      ),
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
      padding: EdgeInsets.symmetric(
        horizontal: AppUI.gap(context, 14),
        vertical: AppUI.gap(context, 12),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppUI.r(context, 18)),
        border: Border.all(color: Colors.black12.withOpacity(.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: AppUI.r(context, 18),
            backgroundColor: Colors.grey.shade100,
            child: Icon(
              icon,
              size: AppUI.fs(context, 18),
              color: Colors.black87,
            ),
          ),
          SizedBox(width: AppUI.gap(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppUI.fs(context, 12),
                    color: Colors.black.withOpacity(.55),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppUI.gap(context, 3)),
                Text(
                  v,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppUI.fs(context, 14),
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
