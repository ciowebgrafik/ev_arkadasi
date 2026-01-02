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

  Future<void> _fotoSec() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _avatarBytes = bytes);
  }

  /// Storage'a yükler ve DB'ye yazılacak PATH döner
  Future<String?> _fotoYuklePath(String uid) async {
    if (_avatarBytes == null) return null;

    final path = '$uid/avatar.jpg';

    await supabase.storage.from('avatars').uploadBinary(
      path,
      _avatarBytes!,
      fileOptions: const FileOptions(upsert: true),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad Soyad / Telefon / Şehir boş olamaz')),
      );
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
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil oluşturuldu ✅')),
      );

      await widget.onProfileSaved?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil kaydetme hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Oluştur')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _fotoSec,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                child: _avatarBytes == null ? const Icon(Icons.camera_alt, size: 32) : null,
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
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _kaydet,
                child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}