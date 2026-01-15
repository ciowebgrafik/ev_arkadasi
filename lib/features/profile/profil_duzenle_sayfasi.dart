import 'dart:typed_data';

import 'package:ev_arkadasi/core/widgets/ad_banner_box.dart';
import 'package:ev_arkadasi/core/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ✅ ProfilDuzenleSayfasi
/// - Şehir/İlçe dropdown (cities + districts)
/// - Avatar seç + Supabase Storage upload
/// - Kaydet → profiles update
/// - Altta reklam alanı: SENİN sisteminle uyumlu olacak şekilde
///   ✅ core/widgets/ad_banner_box.dart (AdBannerBox) kullanılıyor.
///
/// Not: Bu sayfada "placeholder" reklam yok artık.
/// Direkt AdBannerBox var (test id ile çalışır / AdMob yoksa zaten görünmez).

class ProfilDuzenleSayfasi extends StatefulWidget {
  const ProfilDuzenleSayfasi({super.key});

  @override
  State<ProfilDuzenleSayfasi> createState() => _ProfilDuzenleSayfasiState();
}

class _ProfilDuzenleSayfasiState extends State<ProfilDuzenleSayfasi> {
  static const Color kTurkuaz = Color(0xFF00B8D4);

  final SupabaseClient supabase = Supabase.instance.client;

  final _adController = TextEditingController();
  final _telefonController = TextEditingController();
  final _bioController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  Uint8List? _avatarBytes;

  Uint8List? _existingAvatarBytes;
  String _existingAvatarPath = '';
  bool _loadingAvatar = false;

  String _initialCityName = '';
  String _initialDistrictName = '';

  int? _selectedCityId;
  String? _selectedCityName;
  String? _selectedDistrictName;

  bool _loadingCities = true;
  bool _loadingDistricts = false;

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
    await _loadCities();
    await _profiliYukle();
  }

  Future<void> _loadCities() async {
    if (mounted) setState(() => _loadingCities = true);

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
    if (mounted) {
      setState(() {
        _loadingDistricts = true;
        _districts = [];
        _selectedDistrictName = null;
      });
    }

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

  Future<void> _loadExistingAvatarBytesIfNeeded() async {
    if (_avatarBytes != null) return;

    final path = _existingAvatarPath.trim();
    if (path.isEmpty) return;

    if (mounted) setState(() => _loadingAvatar = true);

    try {
      final bytes = await supabase.storage.from('avatars').download(path);
      if (!mounted) return;

      if (_avatarBytes == null) {
        setState(() => _existingAvatarBytes = bytes);
      }
    } catch (_) {
      // avatar yoksa sessiz geç
    } finally {
      if (mounted) setState(() => _loadingAvatar = false);
    }
  }

  Future<void> _profiliYukle() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (mounted) {
      setState(() {
        _loading = true;
        _existingAvatarBytes = null;
        _existingAvatarPath = '';
      });
    }

    try {
      final data = await supabase
          .from('profiles')
          .select('full_name, phone, city, district, bio, avatar_path')
          .eq('id', user.id)
          .maybeSingle();

      _adController.text = (data?['full_name'] ?? '').toString();
      _telefonController.text = (data?['phone'] ?? '').toString();
      _bioController.text = (data?['bio'] ?? '').toString();

      _initialCityName = (data?['city'] ?? '').toString().trim();
      _initialDistrictName = (data?['district'] ?? '').toString().trim();

      _existingAvatarPath = (data?['avatar_path'] ?? '').toString();

      // ✅ Şehir seçimini eşle (isim üzerinden)
      if (_initialCityName.isNotEmpty && _cities.isNotEmpty) {
        final row = _cities.firstWhere(
          (x) =>
              (x['name'] ?? '').toString().trim().toLowerCase() ==
              _initialCityName.toLowerCase(),
          orElse: () => const {'id': null, 'name': ''},
        );

        final idRaw = row['id'];
        final id = (idRaw is int) ? idRaw : int.tryParse('${idRaw ?? ''}');

        if (id != null) {
          _selectedCityId = id;
          _selectedCityName = (row['name'] ?? '').toString().trim();

          await _loadDistrictsOfCityId(id);

          // ✅ İlçe eşle
          if (_initialDistrictName.isNotEmpty) {
            final match = _districts.firstWhere(
              (d) => d.toLowerCase() == _initialDistrictName.toLowerCase(),
              orElse: () => _initialDistrictName,
            );
            _selectedDistrictName = match;
          }
        }
      }

      await _loadExistingAvatarBytesIfNeeded();
    } catch (e) {
      if (!mounted) return;
      _snack('Profil okunamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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

    if (_saving) return;
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

      if (newAvatarPath != null) updateMap['avatar_path'] = newAvatarPath;

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

  // =====================
  // ✅ ŞEHİR / İLÇE UI
  // =====================

  Widget _cityDropdown() {
    if (_loadingCities) {
      return SizedBox(
        height: AppUI.gap(context, 56),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return DropdownButtonFormField<int>(
      value: _selectedCityId,
      isExpanded: true,
      items: _cities
          .map((c) {
            final idRaw = c['id'];
            final id = (idRaw is int) ? idRaw : int.tryParse('${idRaw ?? ''}');
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
      decoration: InputDecoration(
        labelText: 'Şehir',
        border: const OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppUI.gap(context, 12),
          vertical: AppUI.gap(context, 14),
        ),
      ),
    );
  }

  Widget _districtDropdown() {
    final disabled = _saving || _selectedCityId == null;

    if (_loadingDistricts) {
      return SizedBox(
        height: AppUI.gap(context, 56),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppUI.gap(context, 12),
          vertical: AppUI.gap(context, 14),
        ),
      ),
    );
  }

  // =====================
  // ✅ BODY
  // =====================

  Widget _buildBody(BuildContext context) {
    final ImageProvider? bg = (_avatarBytes != null)
        ? MemoryImage(_avatarBytes!)
        : (_existingAvatarBytes != null)
        ? MemoryImage(_existingAvatarBytes!)
        : null;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          AbsorbPointer(
            absorbing: _saving,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                AppUI.gap(context, 16),
                AppUI.gap(context, 16),
                AppUI.gap(context, 16),
                AppUI.gap(context, 16) + bottomInset,
              ),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _saving ? null : _fotoSec,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: AppUI.r(context, 54),
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: bg,
                          child: bg == null
                              ? Icon(
                                  Icons.camera_alt,
                                  size: AppUI.fs(context, 32),
                                )
                              : null,
                        ),
                        if (_loadingAvatar)
                          const Positioned.fill(
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppUI.gap(context, 20)),
                TextField(
                  controller: _adController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Ad Soyad',
                    border: const OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppUI.gap(context, 12),
                      vertical: AppUI.gap(context, 14),
                    ),
                  ),
                ),
                SizedBox(height: AppUI.gap(context, 12)),
                TextField(
                  controller: _telefonController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Telefon',
                    border: const OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppUI.gap(context, 12),
                      vertical: AppUI.gap(context, 14),
                    ),
                  ),
                ),
                SizedBox(height: AppUI.gap(context, 12)),
                _cityDropdown(),
                SizedBox(height: AppUI.gap(context, 12)),
                _districtDropdown(),
                SizedBox(height: AppUI.gap(context, 12)),
                TextField(
                  controller: _bioController,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    labelText: 'Hakkımda',
                    border: const OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppUI.gap(context, 12),
                      vertical: AppUI.gap(context, 14),
                    ),
                  ),
                ),
                SizedBox(height: AppUI.gap(context, 22)),
                SizedBox(
                  width: double.infinity,
                  height: AppUI.gap(context, 52),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTurkuaz,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppUI.r(context, 12),
                        ),
                      ),
                    ),
                    onPressed: _saving ? null : _kaydet,
                    child: Text(
                      _saving ? 'Kaydediliyor...' : 'Kaydet',
                      style: TextStyle(
                        fontSize: AppUI.fs(context, 15),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                // ✅ SENİN SİSTEMİN: GERÇEK BANNER WIDGET
                // - Reklam gösterilemiyorsa zaten shrink olur.
                // - Sabit ve güvenli.
                SizedBox(height: AppUI.gap(context, 12)),
                const AdBannerBox(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  backgroundColor: Colors.white,
                ),

                SizedBox(height: AppUI.gap(context, 24)),
              ],
            ),
          ),
          if (_saving)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: Colors.black.withOpacity(0.15),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        title: Text(
          'Profil Düzenle',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: AppUI.fs(context, 16),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _saving ? null : () async => _initLoad(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Material(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(context),
        ),
      ),
    );
  }
}
