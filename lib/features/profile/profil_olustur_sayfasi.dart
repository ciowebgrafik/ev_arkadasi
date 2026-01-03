import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilOlusturSayfasi extends StatefulWidget {
  final Future<void> Function()? onProfileSaved;

  const ProfilOlusturSayfasi({super.key, this.onProfileSaved});

  @override
  State<ProfilOlusturSayfasi> createState() => _ProfilOlusturSayfasiState();
}

class _ProfilOlusturSayfasiState extends State<ProfilOlusturSayfasi> {
  final supabase = Supabase.instance.client;

  final _adController = TextEditingController();
  final _telefonController = TextEditingController();
  final _sehirController = TextEditingController();
  final _bioController = TextEditingController();

  Uint8List? _avatarBytes;
  bool _saving = false;

  @override
  void dispose() {
    _adController.dispose();
    _telefonController.dispose();
    _sehirController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _fotoSec() async {
    final picker = ImagePicker();

    // ✅ HIZLANDIRMA: küçük boyut + kalite düşürme
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1024,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _avatarBytes = bytes);
  }

  /// Storage'a yükler ve DB'ye yazılacak PATH döner
  Future<String?> _fotoYuklePath(String uid) async {
    if (_avatarBytes == null) return null;

    final path = '$uid/avatar.jpg';

    await supabase.storage
        .from('avatars')
        .uploadBinary(
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

  Future<void> _kaydet() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final fullName = _adController.text.trim();
    final phone = _telefonController.text.trim();
    final city = _sehirController.text.trim();
    final bio = _bioController.text.trim();

    if (fullName.isEmpty || phone.isEmpty || city.isEmpty) {
      _snack('Ad Soyad / Telefon / Şehir boş olamaz');
      return;
    }

    setState(() => _saving = true);

    try {
      final avatarPath = await _fotoYuklePath(user.id);

      await supabase.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'full_name': fullName,
        'phone': phone,
        'city': city,
        'bio': bio,
        'avatar_path': avatarPath, // ✅ sadece path
        'has_password': false, // ✅ AuthGate akışına uyumlu
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      if (!mounted) return;

      _snack('Profil oluşturuldu ✅');
      await widget.onProfileSaved?.call();
    } catch (e) {
      _snack('Profil kaydetme hatası: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Scaffold yok (AppPage var)
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            children: [
              // ✅ ÜST BAR (başlık)
              Row(
                children: const [
                  Icon(Icons.person_add_alt_1),
                  SizedBox(width: 8),
                  Text(
                    'Profil Oluştur',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: _saving ? null : _fotoSec,
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _avatarBytes != null
                      ? MemoryImage(_avatarBytes!)
                      : null,
                  child: _avatarBytes == null
                      ? const Icon(Icons.camera_alt, size: 32)
                      : null,
                ),
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
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _kaydet,
                  child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
                ),
              ),

              const SizedBox(height: 80), // watermark ile çakışmasın
            ],
          ),
        ),

        // ✅ Kaydetme sırasında ekran kilidi + loading
        if (_saving)
          Container(
            color: Colors.black.withOpacity(0.15),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
