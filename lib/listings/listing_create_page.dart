import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listing_enums.dart';
import 'listings_service.dart';

enum ItemCategory { all, whiteGoods, furniture, other }

extension ItemCategoryX on ItemCategory {
  String get label {
    switch (this) {
      case ItemCategory.all:
        return 'Hepsi';
      case ItemCategory.whiteGoods:
        return 'Beyaz Eşya';
      case ItemCategory.furniture:
        return 'Mobilya';
      case ItemCategory.other:
        return 'Diğer';
    }
  }

  String? get dbValue {
    switch (this) {
      case ItemCategory.all:
        return null;
      case ItemCategory.whiteGoods:
        return 'white_goods';
      case ItemCategory.furniture:
        return 'furniture';
      case ItemCategory.other:
        return 'other';
    }
  }

  static ItemCategory fromDb(String? v) {
    switch (v) {
      case 'white_goods':
        return ItemCategory.whiteGoods;
      case 'furniture':
        return ItemCategory.furniture;
      case 'other':
        return ItemCategory.other;
      default:
        return ItemCategory.all;
    }
  }
}

enum PhotoUpdateMode { append, replace }

extension PhotoUpdateModeX on PhotoUpdateMode {
  String get label {
    switch (this) {
      case PhotoUpdateMode.append:
        return 'Eskilere ekle';
      case PhotoUpdateMode.replace:
        return 'Eskileri değiştir';
    }
  }
}

// ✅ DOPING PLANLARI
enum BoostPlan { none, bronze, silver, gold }

extension BoostPlanX on BoostPlan {
  String get label {
    switch (this) {
      case BoostPlan.none:
        return 'Yok';
      case BoostPlan.bronze:
        return 'Bronz (7 gün)';
      case BoostPlan.silver:
        return 'Gümüş (15 gün)';
      case BoostPlan.gold:
        return 'Altın (30 gün)';
    }
  }

  String get dbValue {
    switch (this) {
      case BoostPlan.none:
        return 'none';
      case BoostPlan.bronze:
        return 'bronze';
      case BoostPlan.silver:
        return 'silver';
      case BoostPlan.gold:
        return 'gold';
    }
  }

  int get days {
    switch (this) {
      case BoostPlan.none:
        return 0;
      case BoostPlan.bronze:
        return 7;
      case BoostPlan.silver:
        return 15;
      case BoostPlan.gold:
        return 30;
    }
  }

  static BoostPlan fromDb(dynamic v) {
    final s = (v ?? '').toString().toLowerCase().trim();
    switch (s) {
      case 'bronze':
        return BoostPlan.bronze;
      case 'silver':
        return BoostPlan.silver;
      case 'gold':
        return BoostPlan.gold;
      case 'none':
      default:
        return BoostPlan.none;
    }
  }
}

/// =======================
/// ✅ City/District Models
/// =======================
class _CityRow {
  final int id;
  final String name;
  final String slug;

  const _CityRow({required this.id, required this.name, required this.slug});

  static _CityRow fromJson(Map<String, dynamic> j) {
    return _CityRow(
      id: (j['id'] as num).toInt(),
      name: (j['name'] ?? '').toString(),
      slug: (j['slug'] ?? '').toString(),
    );
  }
}

class _DistrictRow {
  final int id;
  final int cityId;
  final String name;
  final String slug;

  const _DistrictRow({
    required this.id,
    required this.cityId,
    required this.name,
    required this.slug,
  });

  static _DistrictRow fromJson(Map<String, dynamic> j) {
    return _DistrictRow(
      id: (j['id'] as num).toInt(),
      cityId: (j['city_id'] as num).toInt(),
      name: (j['name'] ?? '').toString(),
      slug: (j['slug'] ?? '').toString(),
    );
  }
}

class ListingCreatePage extends StatefulWidget {
  const ListingCreatePage({super.key, this.editListing});

  final Map<String, dynamic>? editListing;

  bool get isEdit => editListing != null;

  @override
  State<ListingCreatePage> createState() => _ListingCreatePageState();
}

class _ListingCreatePageState extends State<ListingCreatePage> {
  static const Color kTurkuaz = Color(0xFF00B8D4);

  final _service = ListingsService();
  final _picker = ImagePicker();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(); // dropdown seçimiyle dolacak
  final _districtCtrl = TextEditingController(); // dropdown seçimiyle dolacak
  final _priceCtrl = TextEditingController();

  bool _billsIncluded = false; // sadece roommate
  bool _urgent = false;

  BoostPlan _boostPlan = BoostPlan.none;

  ListingType _type = ListingType.roommate;
  PricePeriod _pricePeriod = PricePeriod.monthly; // sadece roommate için

  final _roomCountCtrl = TextEditingController(); // sadece roommate
  ItemCategory _itemCategory = ItemCategory.all; // sadece item

  bool _ruleSmoking = false;
  bool _rulePets = false;
  bool _ruleGuests = true;

  String _prefGender = 'any';
  bool _prefStudent = false;
  bool _prefWorker = false;

  final List<_PickedImage> _pickedImages = [];

  bool _loading = false;

  String? _myPhone;
  bool _loadingPhone = true;

  // ✅ Edit mod
  String? _editId;

  // mevcut fotolar (kalanlar)
  List<String> _existingImagePaths = [];

  // ekranda göstermek için signed url cache
  final Map<String, String?> _existingUrlCache = {};

  // foto güncelleme modu
  PhotoUpdateMode _photoMode = PhotoUpdateMode.append;

  // storage'dan sil
  bool _deleteRemovedFromStorage = false;

  // editte silinen eski pathler (storage için)
  final List<String> _removedExistingPaths = [];

  // ===========================
  // ✅ City / District dropdown state
  // ===========================
  bool _loadingCities = false;
  bool _loadingDistricts = false;
  String? _locError;

  List<_CityRow> _cities = [];
  List<_DistrictRow> _districts = [];

  int? _selectedCityId;
  int? _selectedDistrictId;

  // Edit prefill (ID varsa önce onu kullan)
  int? _initialCityId;
  int? _initialDistrictId;
  String _initialCityName = '';
  String _initialDistrictName = '';

  @override
  void initState() {
    super.initState();
    _loadMyPhone();
    _initEditIfNeeded();
    _loadCities();
  }

  bool get _isBasicOtherType =>
      _type != ListingType.roommate && _type != ListingType.item;

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  void _initEditIfNeeded() {
    final l = widget.editListing;
    if (l == null) return;

    _editId = (l['id'] ?? '').toString();

    _titleCtrl.text = (l['title'] ?? '').toString();
    _descCtrl.text = (l['description'] ?? '').toString();

    // ✅ Yeni: ID varsa al
    _initialCityId = _asInt(l['city_id']);
    _initialDistrictId = _asInt(l['district_id']);

    // ✅ Eski: isimler (fallback + arama için hâlâ tutuyoruz)
    _cityCtrl.text = (l['city'] ?? '').toString();
    _districtCtrl.text = (l['district'] ?? '').toString();

    _initialCityName = _cityCtrl.text.trim();
    _initialDistrictName = _districtCtrl.text.trim();

    final price = l['price'];
    if (price != null) _priceCtrl.text = price.toString();

    _billsIncluded = l['bills_included'] == true;
    _urgent = l['is_urgent'] == true;

    _type = _parseType(l['type']);
    _pricePeriod = _parsePeriod(l['price_period']);

    final details = _castMap(l['details']);
    final rules = _castMap(l['rules']);
    final prefs = _castMap(l['preferences']);

    // ✅ doping oku
    if (details.containsKey('boost_plan')) {
      _boostPlan = BoostPlanX.fromDb(details['boost_plan']);
    } else if (details['boosted'] == true) {
      _boostPlan = BoostPlan.bronze;
    } else {
      _boostPlan = BoostPlan.none;
    }

    if (_type == ListingType.roommate) {
      _roomCountCtrl.text = (details['room_count'] ?? '').toString();
      _ruleSmoking = rules['smoking'] == true;
      _rulePets = rules['pets'] == true;
      _ruleGuests = rules['guests'] == true;
      _prefGender = (prefs['gender'] ?? 'any').toString();
      _prefStudent = prefs['student'] == true;
      _prefWorker = prefs['worker'] == true;
    }

    if (_type == ListingType.item) {
      _itemCategory = ItemCategoryX.fromDb(
        (details['category'] ?? '').toString(),
      );
    }

    _existingImagePaths = _service.extractImagePaths(l);
    _loadExistingSignedUrls();
  }

  Future<void> _loadExistingSignedUrls() async {
    _existingUrlCache.clear();
    for (final p in _existingImagePaths) {
      _existingUrlCache[p] = await _service.createSignedListingImageUrl(
        path: p,
      );
    }
    if (mounted) setState(() {});
  }

  ListingType _parseType(dynamic v) {
    final s = (v ?? '').toString().toLowerCase().trim();
    return listingTypeFromDb(s);
  }

  PricePeriod _parsePeriod(dynamic v) {
    final s = (v ?? '').toString().toLowerCase().trim();
    return pricePeriodFromDb(s);
  }

  Map<String, dynamic> _castMap(dynamic v) {
    if (v == null) return {};
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry('$k', val));
    return {};
  }

  Future<void> _loadMyPhone() async {
    setState(() => _loadingPhone = true);
    try {
      final sb = Supabase.instance.client;
      final user = sb.auth.currentUser;
      if (user == null) {
        _myPhone = null;
        return;
      }

      final res = await sb
          .from('profiles')
          .select('phone')
          .eq('id', user.id)
          .maybeSingle();
      final phone = (res?['phone'] ?? '').toString().trim();
      _myPhone = phone.isEmpty ? null : phone;
    } catch (_) {
      _myPhone = null;
    } finally {
      if (mounted) setState(() => _loadingPhone = false);
    }
  }

  // ===========================
  // ✅ Load cities/districts
  // ===========================
  Future<void> _loadCities() async {
    setState(() {
      _loadingCities = true;
      _locError = null;
    });

    try {
      final sb = Supabase.instance.client;
      final res = await sb
          .from('cities')
          .select('id,name,slug')
          .order('id', ascending: true);

      _cities = (res as List)
          .map((e) => _CityRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      // ✅ Edit prefill: önce ID ile
      if (widget.isEdit) {
        if (_initialCityId != null) {
          final exists = _cities.any((c) => c.id == _initialCityId);
          if (exists) {
            _selectedCityId = _initialCityId;
            final city = _cities.firstWhere((c) => c.id == _selectedCityId);
            _cityCtrl.text = city.name;

            await _loadDistricts(_selectedCityId!);

            if (_initialDistrictId != null &&
                _districts.any((d) => d.id == _initialDistrictId)) {
              _selectedDistrictId = _initialDistrictId;
              final d = _districts.firstWhere(
                (x) => x.id == _selectedDistrictId,
              );
              _districtCtrl.text = d.name;
            }
          }
        }

        // ✅ Eğer ID yoksa (eski ilan), isimden eşle
        if (_selectedCityId == null && _initialCityName.trim().isNotEmpty) {
          final nameLower = _initialCityName.trim().toLowerCase();
          final foundCity = _cities.firstWhere(
            (c) => c.name.trim().toLowerCase() == nameLower,
            orElse: () => const _CityRow(id: -1, name: '', slug: ''),
          );
          if (foundCity.id != -1) {
            _selectedCityId = foundCity.id;
            _cityCtrl.text = foundCity.name;
            await _loadDistricts(foundCity.id);

            final distLower = _initialDistrictName.trim().toLowerCase();
            if (distLower.isNotEmpty) {
              final foundDist = _districts.firstWhere(
                (d) => d.name.trim().toLowerCase() == distLower,
                orElse: () =>
                    const _DistrictRow(id: -1, cityId: -1, name: '', slug: ''),
              );
              if (foundDist.id != -1) {
                _selectedDistrictId = foundDist.id;
                _districtCtrl.text = foundDist.name;
              }
            }
          }
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _locError = 'Şehirler yüklenemedi: $e');
    } finally {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _loadDistricts(int cityId) async {
    setState(() {
      _loadingDistricts = true;
      _locError = null;
      _districts = [];
      _selectedDistrictId = null;
      _districtCtrl.text = '';
    });

    try {
      final sb = Supabase.instance.client;
      final res = await sb
          .from('districts')
          .select('id,city_id,name,slug')
          .eq('city_id', cityId)
          .order('name', ascending: true);

      _districts = (res as List)
          .map((e) => _DistrictRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _locError = 'İlçeler yüklenemedi: $e');
    } finally {
      if (mounted) setState(() => _loadingDistricts = false);
    }
  }

  void _onCityChanged(int? cityId) async {
    if (cityId == null) return;

    final city = _cities.firstWhere((c) => c.id == cityId);
    setState(() {
      _selectedCityId = cityId;
      _cityCtrl.text = city.name; // ✅ isim (arama/filtre uyumluluğu)
      _districtCtrl.text = '';
      _selectedDistrictId = null;
    });

    await _loadDistricts(cityId);
  }

  void _onDistrictChanged(int? districtId) {
    if (districtId == null) return;
    final d = _districts.firstWhere((x) => x.id == districtId);
    setState(() {
      _selectedDistrictId = districtId;
      _districtCtrl.text = d.name; // ✅ isim (arama/filtre uyumluluğu)
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _priceCtrl.dispose();
    _roomCountCtrl.dispose();
    super.dispose();
  }

  PricePeriod _defaultPeriodForType(ListingType t) {
    if (t == ListingType.roommate) return PricePeriod.monthly;
    return PricePeriod.once; // ✅ item + diğer türler => Tek Sefer
  }

  int _remainingPickCount() {
    final current = _existingImagePaths.length + _pickedImages.length;
    final remaining = 10 - current;
    return remaining < 0 ? 0 : remaining;
  }

  int _totalPhotoCount() => _existingImagePaths.length + _pickedImages.length;

  Future<void> _pickImages() async {
    try {
      final remaining = _remainingPickCount();
      if (remaining <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('En fazla 10 fotoğraf olabilir.')),
        );
        return;
      }

      final files = await _picker.pickMultiImage(imageQuality: 80);
      if (!mounted) return;
      if (files.isEmpty) return;

      final take = files.take(remaining).toList();

      final newOnes = <_PickedImage>[];
      for (final f in take) {
        final bytes = await f.readAsBytes();
        newOnes.add(_PickedImage(file: f, bytes: bytes));
      }

      if (!mounted) return;
      setState(() => _pickedImages.addAll(newOnes));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Foto seçilemedi: $e')));
    }
  }

  void _removeNewImageAt(int i) => setState(() => _pickedImages.removeAt(i));

  void _removeExistingPath(String path) {
    setState(() {
      _existingImagePaths.remove(path);
      _existingUrlCache.remove(path);
      _removedExistingPaths.add(path);
    });
  }

  Map<String, dynamic> _buildBoostDetails() {
    final now = DateTime.now();
    final days = _boostPlan.days;

    final boosted = _boostPlan != BoostPlan.none;
    final end = boosted ? now.add(Duration(days: days)) : null;

    return <String, dynamic>{
      'boost_plan': _boostPlan.dbValue,
      'boosted': boosted,
      'boost_days': days,
      'boost_start': now.toIso8601String(),
      'boost_end': end?.toIso8601String(),
    };
  }

  Map<String, dynamic> _buildDetails() {
    final details = <String, dynamic>{};

    if (_type == ListingType.roommate) {
      if (_roomCountCtrl.text.trim().isNotEmpty) {
        details['room_count'] = _roomCountCtrl.text.trim();
      }
    }

    if (_type == ListingType.item) {
      final v = _itemCategory.dbValue;
      if (v != null) details['category'] = v;
    }

    details.addAll(_buildBoostDetails());
    return details;
  }

  Map<String, dynamic> _buildRules() {
    if (_type != ListingType.roommate) return {};
    return <String, dynamic>{
      'smoking': _ruleSmoking,
      'pets': _rulePets,
      'guests': _ruleGuests,
    };
  }

  Map<String, dynamic> _buildPreferences() {
    if (_type != ListingType.roommate) return {};
    return <String, dynamic>{
      'gender': _prefGender,
      'student': _prefStudent,
      'worker': _prefWorker,
    };
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ===========================
  // ✅ SUPABASE DIRECT SAVE
  // ✅ Konum: city_id + district_id (ID) + city/district (isim) birlikte
  // ===========================
  Future<String> _supabaseCreateListing({
    required ListingType type,
    required String title,
    String? description,
    required int cityId,
    required int districtId,
    required String cityName,
    required String districtName,
    double? price,
    required PricePeriod pricePeriod,
    required bool billsIncluded,
    required bool isUrgent,
    String? phone,
    required Map<String, dynamic> details,
    required Map<String, dynamic> rules,
    required Map<String, dynamic> preferences,
    required String status,
  }) async {
    final sb = Supabase.instance.client;
    final user = sb.auth.currentUser;
    if (user == null) throw Exception('Giriş yapılmamış.');

    final data = <String, dynamic>{
      'owner_id': user.id,
      'type': listingTypeToDb(type),
      'title': title,
      'description': description,
      // ✅ Konum (ID + isim)
      'city_id': cityId,
      'district_id': districtId,
      'city': cityName,
      'district': districtName,

      'price': price,
      'price_period': pricePeriodToDb(pricePeriod),
      'bills_included': billsIncluded,
      'is_urgent': isUrgent,
      'phone': phone,
      'details': details,
      'rules': rules,
      'preferences': preferences,
      'status': status,
    };

    final res = await sb.from('listings').insert(data).select('id').single();
    return (res['id'] ?? '').toString();
  }

  Future<void> _supabaseUpdateListing({
    required String listingId,
    required ListingType type,
    required String title,
    String? description,
    required int cityId,
    required int districtId,
    required String cityName,
    required String districtName,
    double? price,
    required PricePeriod pricePeriod,
    required bool billsIncluded,
    required bool isUrgent,
    String? phone,
    required Map<String, dynamic> details,
    required Map<String, dynamic> rules,
    required Map<String, dynamic> preferences,
    required String status,
  }) async {
    final sb = Supabase.instance.client;
    final user = sb.auth.currentUser;
    if (user == null) throw Exception('Giriş yapılmamış.');

    final data = <String, dynamic>{
      'type': listingTypeToDb(type),
      'title': title,
      'description': description,
      // ✅ Konum (ID + isim)
      'city_id': cityId,
      'district_id': districtId,
      'city': cityName,
      'district': districtName,

      'price': price,
      'price_period': pricePeriodToDb(pricePeriod),
      'bills_included': billsIncluded,
      'is_urgent': isUrgent,
      'phone': phone,
      'details': details,
      'rules': rules,
      'preferences': preferences,
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };

    await sb
        .from('listings')
        .update(data)
        .eq('id', listingId)
        .eq('owner_id', user.id);
  }

  Future<void> _save({required bool publish}) async {
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('Başlık zorunlu.');
      return;
    }

    // ✅ Konum zorunlu
    if (_selectedCityId == null) {
      _snack('Lütfen şehir seç.');
      return;
    }
    if (_selectedDistrictId == null) {
      _snack('Lütfen ilçe seç.');
      return;
    }

    // ✅ Foto zorunlu: en az 2
    if (_totalPhotoCount() < 2) {
      _snack('En az 2 fotoğraf zorunlu.');
      return;
    }

    setState(() => _loading = true);

    try {
      if (_myPhone == null && !_loadingPhone) {
        await _loadMyPhone();
      }

      final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.'));

      // ✅ roommate hariç tüm türlerde fiyat zorunlu
      if (_type != ListingType.roommate && (price == null || price <= 0)) {
        _snack('Fiyat zorunlu (Tek Sefer).');
        setState(() => _loading = false);
        return;
      }

      final status = publish ? 'published' : 'draft';

      final finalPeriod = (_type == ListingType.roommate)
          ? _pricePeriod
          : PricePeriod.once;

      final cityId = _selectedCityId!;
      final districtId = _selectedDistrictId!;
      final cityName = _cityCtrl.text.trim();
      final districtName = _districtCtrl.text.trim();

      // ================= EDIT =================
      if (widget.isEdit) {
        final id = _editId;
        if (id == null || id.isEmpty) throw Exception('İlan id bulunamadı.');

        await _supabaseUpdateListing(
          listingId: id,
          type: _type,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          cityId: cityId,
          districtId: districtId,
          cityName: cityName,
          districtName: districtName,
          price: price,
          pricePeriod: finalPeriod,
          billsIncluded: (_type == ListingType.roommate)
              ? _billsIncluded
              : false,
          isUrgent: _urgent,
          phone: _myPhone,
          details: _buildDetails(),
          rules: _buildRules(),
          preferences: _buildPreferences(),
          status: status,
        );

        // yeni foto yükle
        List<String> newPaths = [];
        if (_pickedImages.isNotEmpty) {
          final xfiles = _pickedImages.map((e) => e.file).toList();
          newPaths = await _service.uploadListingImages(
            listingId: id,
            images: xfiles,
          );
        }

        // foto final list
        List<String> finalPaths;
        List<String> pathsToDeleteFromStorage = [];

        if (_photoMode == PhotoUpdateMode.append) {
          finalPaths = [..._existingImagePaths, ...newPaths];
          if (_deleteRemovedFromStorage && _removedExistingPaths.isNotEmpty) {
            pathsToDeleteFromStorage = [..._removedExistingPaths];
          }
        } else {
          finalPaths = [...newPaths];
          if (_deleteRemovedFromStorage) {
            final oldAll = _service.extractImagePaths(widget.editListing!);
            pathsToDeleteFromStorage = [...oldAll];
          }
        }

        await _service.attachListingImages(
          listingId: id,
          imagePaths: finalPaths,
        );

        if (_deleteRemovedFromStorage && pathsToDeleteFromStorage.isNotEmpty) {
          await _service.deleteListingImagesFromStorage(
            pathsToDeleteFromStorage,
          );
        }

        if (!mounted) return;
        _snack(publish ? 'Güncellendi + Yayınlandı ✅' : 'Güncellendi ✅');
        Navigator.pop(context, true);
        return;
      }

      // ================= CREATE =================
      final listingId = await _supabaseCreateListing(
        type: _type,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        cityId: cityId,
        districtId: districtId,
        cityName: cityName,
        districtName: districtName,
        price: price,
        pricePeriod: finalPeriod,
        billsIncluded: (_type == ListingType.roommate) ? _billsIncluded : false,
        isUrgent: _urgent,
        phone: _myPhone,
        details: _buildDetails(),
        rules: _buildRules(),
        preferences: _buildPreferences(),
        status: status,
      );

      // foto upload
      final xfiles = _pickedImages.map((e) => e.file).toList();
      final paths = await _service.uploadListingImages(
        listingId: listingId,
        images: xfiles,
      );
      await _service.attachListingImages(
        listingId: listingId,
        imagePaths: paths,
      );

      if (!mounted) return;
      _snack(publish ? 'Yayınlandı ✅' : 'Taslak kaydedildi ✅');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack('Hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _card(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _existingImagesSection() {
    if (!widget.isEdit) return const SizedBox.shrink();
    if (_existingImagePaths.isEmpty) return const SizedBox.shrink();

    return _card('Mevcut Fotoğraflar', [
      Text(
        'Silmek için foto üstündeki (X) tuşuna bas.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _existingImagePaths.length,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final path = _existingImagePaths[i];
            final url = _existingUrlCache[path];

            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 84,
                    height: 84,
                    color: Colors.grey.shade200,
                    child: (url != null && url.isNotEmpty)
                        ? Image.network(url, fit: BoxFit.cover)
                        : const Icon(Icons.image_outlined, color: Colors.grey),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: InkWell(
                    onTap: () => _removeExistingPath(path),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ]);
  }

  Widget _newImagesSection() {
    final remaining = _remainingPickCount();
    final totalCount = _totalPhotoCount();

    return _card('Fotoğraflar (en az 2 zorunlu)', [
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _pickImages,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _pickedImages.isEmpty
                    ? 'Fotoğraf Seç (kalan: $remaining)'
                    : 'Fotoğraf Ekle (${_pickedImages.length} seçildi, toplam: $totalCount/10)',
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (_pickedImages.isNotEmpty)
            OutlinedButton(
              onPressed: _loading ? null : () => setState(_pickedImages.clear),
              child: const Text('Temizle'),
            ),
        ],
      ),
      const SizedBox(height: 10),
      if (_pickedImages.isNotEmpty)
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _pickedImages.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final img = _pickedImages[i];

              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      img.bytes,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => _removeNewImageAt(i),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      const SizedBox(height: 6),
      Text(
        'Toplam foto: $totalCount/10',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ]);
  }

  Widget _photoManagementSection() {
    if (!widget.isEdit) return const SizedBox.shrink();

    return _card('Foto Yönetimi (Edit)', [
      DropdownButtonFormField<PhotoUpdateMode>(
        value: _photoMode,
        decoration: const InputDecoration(labelText: 'Yeni foto ekleyince'),
        items: PhotoUpdateMode.values
            .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
            .toList(),
        onChanged: (v) => setState(() => _photoMode = v ?? _photoMode),
      ),
      const SizedBox(height: 10),
      CheckboxListTile(
        value: _deleteRemovedFromStorage,
        onChanged: (v) =>
            setState(() => _deleteRemovedFromStorage = v ?? false),
        title: const Text('Kaldırılan eski fotoğrafları storage’dan da sil'),
        subtitle: const Text(
          'Açarsan, kaldırdığın eski foto dosyaları Supabase Storage’dan silinir.',
        ),
        contentPadding: EdgeInsets.zero,
      ),
    ]);
  }

  Widget _dopingSection() {
    return _card('Doping', [
      DropdownButtonFormField<BoostPlan>(
        value: _boostPlan,
        decoration: const InputDecoration(labelText: 'Doping planı'),
        items: BoostPlan.values
            .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
            .toList(),
        onChanged: _loading
            ? null
            : (v) => setState(() => _boostPlan = v ?? BoostPlan.none),
      ),
      const SizedBox(height: 8),
      Text(
        'Not: Şimdilik plan bilgisi kaydediliyor. (Ödeme/öne çıkarma sonra.)',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ]);
  }

  Widget _rulesSection() {
    if (_type != ListingType.roommate) return const SizedBox.shrink();

    return _card('Ev Kuralları', [
      SwitchListTile(
        value: _ruleSmoking,
        onChanged: (v) => setState(() => _ruleSmoking = v),
        title: const Text('Sigara içilebilir mi?'),
        contentPadding: EdgeInsets.zero,
      ),
      SwitchListTile(
        value: _rulePets,
        onChanged: (v) => setState(() => _rulePets = v),
        title: const Text('Evcil hayvan kabul edilir mi?'),
        contentPadding: EdgeInsets.zero,
      ),
      SwitchListTile(
        value: _ruleGuests,
        onChanged: (v) => setState(() => _ruleGuests = v),
        title: const Text('Misafir gelebilir mi?'),
        contentPadding: EdgeInsets.zero,
      ),
    ]);
  }

  Widget _preferencesSection() {
    if (_type != ListingType.roommate) return const SizedBox.shrink();

    return _card('Kişi Tercihleri', [
      DropdownButtonFormField<String>(
        value: _prefGender,
        decoration: const InputDecoration(labelText: 'Tercih edilen cinsiyet'),
        items: const [
          DropdownMenuItem(value: 'any', child: Text('Farketmez')),
          DropdownMenuItem(value: 'male', child: Text('Erkek')),
          DropdownMenuItem(value: 'female', child: Text('Kadın')),
        ],
        onChanged: (v) => setState(() => _prefGender = v ?? 'any'),
      ),
      const SizedBox(height: 10),
      CheckboxListTile(
        value: _prefStudent,
        onChanged: (v) => setState(() => _prefStudent = v ?? false),
        title: const Text('Öğrenci tercih edilir'),
        contentPadding: EdgeInsets.zero,
      ),
      CheckboxListTile(
        value: _prefWorker,
        onChanged: (v) => setState(() => _prefWorker = v ?? false),
        title: const Text('Çalışan tercih edilir'),
        contentPadding: EdgeInsets.zero,
      ),
    ]);
  }

  Widget _locationSection() {
    return _card('Konum', [
      if (_locError != null) ...[
        Text(_locError!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 8),
      ],
      DropdownButtonFormField<int>(
        value: _selectedCityId,
        decoration: const InputDecoration(labelText: 'Şehir *'),
        isExpanded: true,
        items: _cities
            .map(
              (c) => DropdownMenuItem<int>(
                value: c.id,
                child: Text(c.name), // ✅ profesyonel: sadece isim
              ),
            )
            .toList(),
        onChanged: (_loadingCities || _loading)
            ? null
            : (v) => _onCityChanged(v),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<int>(
        value: _selectedDistrictId,
        decoration: InputDecoration(
          labelText: _selectedCityId == null ? 'Önce şehir seç' : 'İlçe *',
        ),
        isExpanded: true,
        items: _districts
            .map((d) => DropdownMenuItem<int>(value: d.id, child: Text(d.name)))
            .toList(),
        onChanged: (_selectedCityId == null || _loadingDistricts || _loading)
            ? null
            : (v) => _onDistrictChanged(v),
      ),
      const SizedBox(height: 8),
      if (_loadingCities || _loadingDistricts)
        const LinearProgressIndicator(minHeight: 2),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final phoneText = _loadingPhone
        ? 'Telefon: yükleniyor...'
        : (_myPhone == null || _myPhone!.trim().isEmpty)
        ? 'Telefon: Profilinde yok (Profilim’den ekleyebilirsin)'
        : 'Telefon (profil): ${_myPhone!}';

    // ✅ ilan türlerini sırayla göster
    final typeItems = [...ListingType.values]
      ..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        title: Text(widget.isEdit ? 'İlanı Düzenle' : 'İlan Yayınla'),
      ),
      body: AbsorbPointer(
        absorbing: _loading,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _card('Temel Bilgiler', [
              DropdownButtonFormField<ListingType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'İlan Türü'),
                items: typeItems
                    .map(
                      (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                    )
                    .toList(),
                onChanged: widget.isEdit
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() {
                          _type = v;
                          _pricePeriod = _defaultPeriodForType(v);

                          if (_type != ListingType.roommate)
                            _billsIncluded = false;
                          if (_type != ListingType.item)
                            _itemCategory = ItemCategory.all;
                        });
                      },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Başlık *'),
              ),
              if (_type == ListingType.item) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<ItemCategory>(
                  value: _itemCategory,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: ItemCategory.values
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _itemCategory = v ?? _itemCategory),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Açıklama'),
                maxLines: 4,
              ),
              const SizedBox(height: 10),
              Text(phoneText, style: Theme.of(context).textTheme.bodySmall),
            ]),
            _dopingSection(),
            _photoManagementSection(),
            _existingImagesSection(),
            _newImagesSection(),
            _locationSection(),
            _card('Fiyat', [
              TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Fiyat (Tek Sefer) *',
                ),
              ),
              const SizedBox(height: 10),
              if (_type == ListingType.roommate)
                DropdownButtonFormField<PricePeriod>(
                  value: _pricePeriod,
                  decoration: const InputDecoration(
                    labelText: 'Fiyat Periyodu',
                  ),
                  items: PricePeriod.values
                      .map(
                        (p) => DropdownMenuItem(value: p, child: Text(p.label)),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _pricePeriod = v ?? _pricePeriod),
                ),
              const SizedBox(height: 10),
              if (_type == ListingType.roommate)
                SwitchListTile(
                  value: _billsIncluded,
                  onChanged: (v) => setState(() => _billsIncluded = v),
                  title: const Text('Faturalar dahil mi? (Ev Arkadaşı)'),
                  contentPadding: EdgeInsets.zero,
                ),
              SwitchListTile(
                value: _urgent,
                onChanged: (v) => setState(() => _urgent = v),
                title: const Text('Acil / öne çıkar'),
                contentPadding: EdgeInsets.zero,
              ),
              if (_isBasicOtherType)
                Text(
                  'Bu ilan türünde sadece temel alanlar var (başlık, açıklama, foto, konum, fiyat).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ]),
            _card('Ev Arkadaşı (Özel)', [
              if (_type == ListingType.roommate)
                TextField(
                  controller: _roomCountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ev Oda Sayısı (örn: 2+1)',
                  ),
                ),
              if (_type != ListingType.roommate)
                const Text(
                  'Bu bölüm sadece Ev Arkadaşı ilanlarında kullanılır.',
                ),
            ]),
            _rulesSection(),
            _preferencesSection(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => _save(publish: false),
                    child: _loading
                        ? const Text('...')
                        : const Text('Taslak Kaydet'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => _save(publish: true),
                    child: _loading
                        ? const Text('...')
                        : Text(
                            widget.isEdit ? 'Güncelle + Yayınla' : 'Yayınla',
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PickedImage {
  final XFile file;
  final Uint8List bytes;

  const _PickedImage({required this.file, required this.bytes});
}
