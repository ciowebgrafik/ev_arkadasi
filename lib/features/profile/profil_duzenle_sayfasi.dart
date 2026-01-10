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
  static const Color kTurkuaz = Color(0xFF00B8D4);

  final supabase = Supabase.instance.client;

  final _adController = TextEditingController();
  final _telefonController = TextEditingController();
  final _bioController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  Uint8List? _avatarBytes;
  String _existingAvatarPath = '';
  String? _cachedSignedUrl;

  // ✅ Mevcut profil değerleri (DB’den)
  String _initialCityName = '';
  String _initialDistrictName = '';

  // ✅ Dropdown seçimleri
  int? _selectedCityId;
  String? _selectedCityName;
  String? _selectedDistrictName;

  // ✅ DB’den listeler
  bool _loadingCities = true;
  bool _loadingDistricts = false;

  // city item: {id:int, name:String}
  List<Map<String, dynamic>> _cities = [];
  List<String> _districts = [];

  @override
  void initState() {
    super.initState();
    _initLoad();
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

  Future<void> _initLoad() async {
    // 1) şehirleri yükle
    await _loadCities();
    // 2) profili yükle (seçimleri set edecek)
    await _profiliYukle();
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

  // ===================== PROFILE LOAD =====================

  Future<void> _profiliYukle() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _cachedSignedUrl = null;
    });

    try {
      final data = await supabase
          .from('profiles')
          .select('full_name, phone, city, district, bio, avatar_path')
          .eq('id', user.id)
          .maybeSingle();

      _adController.text = (data?['full_name'] ?? '').toString();
      _telefonController.text = (data?['phone'] ?? '').toString();
      _bioController.text = (data?['bio'] ?? '').toString();
      _existingAvatarPath = (data?['avatar_path'] ?? '').toString();

      _initialCityName = (data?['city'] ?? '').toString().trim();
      _initialDistrictName = (data?['district'] ?? '').toString().trim();

      if (_existingAvatarPath.trim().isNotEmpty) {
        _cachedSignedUrl = await _signedAvatarUrl(_existingAvatarPath);
      }

      // ✅ şehir ismine göre cityId bul
      if (_initialCityName.isNotEmpty && _cities.isNotEmpty) {
        final row = _cities.firstWhere(
          (x) =>
              (x['name'] ?? '').toString().trim().toLowerCase() ==
              _initialCityName.toLowerCase(),
          orElse: () => const {'id': null, 'name': ''},
        );

        final idRaw = row['id'];
        final id = (idRaw is int)
            ? idRaw
            : int.tryParse(idRaw?.toString() ?? '');

        if (id != null) {
          _selectedCityId = id;
          _selectedCityName = (row['name'] ?? '').toString().trim();

          // ✅ ilçeleri çek
          await _loadDistrictsOfCityId(id);

          // ✅ ilçeyi seçili getir (varsa listede)
          if (_initialDistrictName.isNotEmpty &&
              _districts.any(
                (d) => d.toLowerCase() == _initialDistrictName.toLowerCase(),
              )) {
            _selectedDistrictName = _districts.firstWhere(
              (d) => d.toLowerCase() == _initialDistrictName.toLowerCase(),
              orElse: () => _initialDistrictName,
            );
          }
        }
      }

      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      _snack('Profil okunamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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

  Future<String?> _signedAvatarUrl(String path) async {
    if (path.isEmpty) return null;

    final url = await supabase.storage
        .from('avatars')
        .createSignedUrl(path, 60 * 60);
    final bust = DateTime.now().millisecondsSinceEpoch;
    return '$url${url.contains('?') ? '&' : '?'}cb=$bust';
  }

  // ===================== SAVE =====================

  Future<void> _kaydet() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final fullName = _adController.text.trim();
    final phone = _telefonController.text.trim();
    final bio = _bioController.text.trim();

    final city = (_selectedCityName ?? _initialCityName).trim();
    final district = (_selectedDistrictName ?? _initialDistrictName).trim();

    if (fullName.isEmpty || phone.isEmpty || city.isEmpty || district.isEmpty) {
      _snack('Ad Soyad / Telefon / Şehir / İlçe boş olamaz');
      return;
    }

    setState(() => _saving = true);

    try {
      final newAvatarPath = await _fotoYuklePath(user.id);

      final updateMap = <String, dynamic>{
        'full_name': fullName,
        'phone': phone,
        'city': city,
        'district': district,
        'bio': bio.isEmpty ? null : bio,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (newAvatarPath != null) {
        updateMap['avatar_path'] = newAvatarPath;
      }

      await supabase.from('profiles').update(updateMap).eq('id', user.id);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack('Kaydetme hatası: $e');
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
            final idRaw = c['id'];
            final id = (idRaw is int)
                ? idRaw
                : int.tryParse(idRaw?.toString() ?? '');
            final name = (c['name'] ?? '').toString();
            if (id == null) return null;
            return DropdownMenuItem<int>(
              value: id,
              child: Text(name, overflow: TextOverflow.ellipsis),
            );
          })
          .whereType<DropdownMenuItem<int>>()
          .toList(),
      onChanged: _saving
          ? null
          : (id) async {
              if (id == null) return;

              // name’i bul
              final row = _cities.firstWhere((x) {
                final rid = (x['id'] is int)
                    ? x['id'] as int
                    : int.tryParse('${x['id']}');
                return rid == id;
              }, orElse: () => const {'id': null, 'name': ''});

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
          : (v) => setState(() => _selectedDistrictName = v),
      decoration: InputDecoration(
        labelText: 'İlçe',
        border: const OutlineInputBorder(),
        hintText: (_selectedCityId == null)
            ? 'Önce şehir seç'
            : (_districts.isEmpty ? 'İlçe bulunamadı' : null),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    ImageProvider? bg;

    if (_avatarBytes != null) {
      bg = MemoryImage(_avatarBytes!);
    } else if ((_cachedSignedUrl ?? '').trim().isNotEmpty) {
      bg = NetworkImage(_cachedSignedUrl!);
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              GestureDetector(
                onTap: _saving ? null : _fotoSec,
                child: CircleAvatar(
                  radius: 54,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: bg,
                  child: bg == null
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
              const SizedBox(height: 22),

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

              const SizedBox(height: 24),
            ],
          ),
        ),

        if (_saving)
          Container(
            color: Colors.black.withOpacity(0.15),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        title: const Text(
          'Profil Düzenle',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _saving ? null : _initLoad,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Material(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context),
      ),
    );
  }
}
