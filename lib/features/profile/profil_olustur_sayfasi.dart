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
  static const Color kTurkuaz = Color(0xFF00B8D4);

  final supabase = Supabase.instance.client;

  final _adController = TextEditingController();
  final _telefonController = TextEditingController();
  final _bioController = TextEditingController();

  // ✅ Seçimler
  int? _selectedCityId; // cities.id (int8)
  String? _selectedCityName;
  String? _selectedDistrictName;

  Uint8List? _avatarBytes;
  bool _saving = false;

  // ✅ DB listeler
  bool _loadingCities = true;
  bool _loadingDistricts = false;

  // city item: {id:int, name:String}
  List<Map<String, dynamic>> _cities = [];
  List<String> _districts = [];

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    _adController.dispose();
    _telefonController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ===================== DB LOADERS =====================

  Future<void> _loadCities() async {
    setState(() => _loadingCities = true);

    try {
      final res = await supabase
          .from('cities')
          .select('id,name')
          .order('name', ascending: true);

      final list = (res as List)
          .map(
            (e) => {'id': e['id'], 'name': (e['name'] ?? '').toString().trim()},
          )
          .where(
            (m) => m['id'] != null && (m['name'] as String).trim().isNotEmpty,
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _cities = list;
        _loadingCities = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCities = false);
      _snack('Şehirler çekilemedi: $e');
    }
  }

  Future<void> _loadDistrictsOfCityId(int cityId) async {
    setState(() {
      _loadingDistricts = true;
      _districts = [];
      _selectedDistrictName = null;
    });

    try {
      final res = await supabase
          .from('districts')
          .select('name')
          .eq('city_id', cityId)
          .order('name', ascending: true);

      final list =
          (res as List)
              .map((e) => (e['name'] ?? '').toString().trim())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      if (!mounted) return;

      setState(() {
        _districts = list;
        _loadingDistricts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDistricts = false);
      _snack('İlçeler çekilemedi: $e');
    }
  }

  // ===================== PHOTO =====================

  Future<void> _fotoSec() async {
    final picker = ImagePicker();

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

  // ===================== SAVE =====================

  Future<void> _kaydet() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _snack('Oturum bulunamadı. Lütfen tekrar giriş yap.');
      return;
    }

    final fullName = _adController.text.trim();
    final phone = _telefonController.text.trim();
    final bio = _bioController.text.trim();

    final city = (_selectedCityName ?? '').trim();
    final district = (_selectedDistrictName ?? '').trim();

    if (fullName.isEmpty || phone.isEmpty || city.isEmpty || district.isEmpty) {
      _snack('Ad Soyad / Telefon / Şehir / İlçe boş olamaz');
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
        'district': district, // ✅ profiles tablosunda district (text) olmalı
        'bio': bio.isEmpty ? null : bio,
        'avatar_path': avatarPath,
        'has_password': false,
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

  // ===================== UI =====================

  Widget _cityDropdown() {
    if (_loadingCities) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return DropdownButtonFormField<int>(
      value: _selectedCityId,
      isExpanded: true,
      items: _cities
          .map((c) {
            final id = c['id'];
            final name = (c['name'] ?? '').toString();
            if (id == null) return null;
            return DropdownMenuItem<int>(
              value: (id is int) ? id : int.tryParse(id.toString()),
              child: Text(name, overflow: TextOverflow.ellipsis),
            );
          })
          .whereType<DropdownMenuItem<int>>()
          .toList(),
      onChanged: _saving
          ? null
          : (id) async {
              if (id == null) return;

              final row = _cities.firstWhere(
                (x) =>
                    (x['id'] is int ? x['id'] : int.tryParse('${x['id']}')) ==
                    id,
                orElse: () => const {'id': null, 'name': ''},
              );

              final name = (row['name'] ?? '').toString().trim();

              setState(() {
                _selectedCityId = id;
                _selectedCityName = name;
                _selectedDistrictName = null;
                _districts = [];
              });

              await _loadDistrictsOfCityId(id);
            },
      decoration: const InputDecoration(
        labelText: 'Şehir',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _districtDropdown() {
    final disabled = _saving || _selectedCityId == null;

    if (_loadingDistricts) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return DropdownButtonFormField<String>(
      value:
          (_selectedDistrictName != null &&
              _selectedDistrictName!.trim().isNotEmpty)
          ? _selectedDistrictName
          : null,
      isExpanded: true,
      items: _districts
          .map(
            (d) => DropdownMenuItem<String>(
              value: d,
              child: Text(d, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: disabled
          ? null
          : (v) {
              setState(() => _selectedDistrictName = v);
            },
      decoration: InputDecoration(
        labelText: 'İlçe',
        border: const OutlineInputBorder(),
        hintText: (_selectedCityId == null)
            ? 'Önce şehir seç'
            : (_districts.isEmpty ? 'İlçe bulunamadı' : null),
      ),
    );
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      // ✅ Klavye + küçük ekranlarda taşmayı azaltır
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        title: const Text('Profil Oluştur'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _saving
                ? null
                : () async {
                    await _loadCities();
                    if (_selectedCityId != null) {
                      await _loadDistrictsOfCityId(_selectedCityId!);
                    }
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, 16, 16, 20 + bottomInset),
                child: Column(
                  children: [
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
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Ad Soyad',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _telefonController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Telefon',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _cityDropdown(),
                    const SizedBox(height: 12),
                    _districtDropdown(),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kTurkuaz,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _saving ? null : _kaydet,
                        child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),

              if (_saving)
                AbsorbPointer(
                  absorbing: true,
                  child: Container(
                    color: Colors.black.withOpacity(0.15),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
