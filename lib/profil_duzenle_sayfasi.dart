import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilDuzenleSayfasi extends StatefulWidget {
  const ProfilDuzenleSayfasi({super.key});

  @override
  State<ProfilDuzenleSayfasi> createState() => _ProfilDuzenleSayfasiState();
}

class _ProfilDuzenleSayfasiState extends State<ProfilDuzenleSayfasi> {
  final supabase = Supabase.instance.client;

  final _adController = TextEditingController();
  final _telefonController = TextEditingController();
  final _sehirController = TextEditingController();
  final _bioController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  Uint8List? _avatarBytes;
  String _existingAvatarPath = '';

  @override
  void initState() {
    super.initState();
    _profiliYukle();
  }

  @override
  void dispose() {
    _adController.dispose();
    _telefonController.dispose();
    _sehirController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _profiliYukle() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      final data = await supabase
          .from('profiles')
          .select('full_name, phone, city, bio, avatar_path')
          .eq('id', user.id)
          .maybeSingle();

      _adController.text = (data?['full_name'] ?? '').toString();
      _telefonController.text = (data?['phone'] ?? '').toString();
      _sehirController.text = (data?['city'] ?? '').toString();
      _bioController.text = (data?['bio'] ?? '').toString();
      _existingAvatarPath = (data?['avatar_path'] ?? '').toString();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil okunamadı: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fotoSec() async {
    final picker = ImagePicker();

    // ✅ HIZLANDIRMA: küçük boyut + kalite düşürme
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1024,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _avatarBytes = bytes);
    }
  }

  Future<String?> _fotoYuklePath(String uid) async {
    if (_avatarBytes == null) return null;

    final path = '$uid/avatar.jpg';

    await supabase.storage.from('avatars').uploadBinary(
      path,
      _avatarBytes!,
      fileOptions: const FileOptions(
        upsert: true,
        contentType: 'image/jpeg',
        cacheControl: '3600',
      ),
    );

    return path;
  }

  Future<String?> _signedAvatarUrl(String path) async {
    if (path.isEmpty) return null;

    final url = await supabase.storage.from('avatars').createSignedUrl(
      path,
      60 * 60,
    );

    final bust = DateTime.now().millisecondsSinceEpoch;
    return '$url${url.contains('?') ? '&' : '?'}cb=$bust';
  }

  Future<void> _kaydet() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final fullName = _adController.text.trim();
    final phone = _telefonController.text.trim();
    final city = _sehirController.text.trim();
    final bio = _bioController.text.trim();

    if (fullName.isEmpty || phone.isEmpty || city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad Soyad / Telefon / Şehir boş olamaz')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final newAvatarPath = await _fotoYuklePath(user.id);

      final updateMap = <String, dynamic>{
        'full_name': fullName,
        'phone': phone,
        'city': city,
        'bio': bio,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (newAvatarPath != null) {
        updateMap['avatar_path'] = newAvatarPath;
      }

      await supabase.from('profiles').update(updateMap).eq('id', user.id);

      if (!mounted) return;
      Navigator.pop(context, true); // ✅ ProfilSayfası bunu yakalayıp Home’a döndürüyor
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydetme hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Düzenle')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                FutureBuilder<String?>(
                  future: _avatarBytes == null
                      ? _signedAvatarUrl(_existingAvatarPath)
                      : Future.value(null),
                  builder: (context, snap) {
                    final url = snap.data ?? '';

                    ImageProvider? bg;
                    if (_avatarBytes != null) {
                      bg = MemoryImage(_avatarBytes!);
                    } else if (url.isNotEmpty) {
                      bg = NetworkImage(url);
                    }

                    return GestureDetector(
                      onTap: _saving ? null : _fotoSec,
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: bg,
                        child: bg == null
                            ? const Icon(Icons.camera_alt, size: 32)
                            : null,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _adController,
                  decoration: const InputDecoration(
                    labelText: 'Ad Soyad',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _telefonController,
                  decoration: const InputDecoration(
                    labelText: 'Telefon',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _sehirController,
                  decoration: const InputDecoration(
                    labelText: 'Şehir',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    labelText: 'Hakkımda',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _kaydet,
                    child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
                  ),
                ),
              ],
            ),
          ),

          // ✅ Kaydetme sırasında ekranı kilitle + loading
          if (_saving)
            Container(
              color: Colors.black.withOpacity(0.15),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}