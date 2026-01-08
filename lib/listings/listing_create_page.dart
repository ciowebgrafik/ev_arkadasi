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
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  bool _billsIncluded = false;
  bool _urgent = false;

  // ✅ Doping planı
  BoostPlan _boostPlan = BoostPlan.none;

  ListingType _type = ListingType.roommate;
  PricePeriod _pricePeriod = PricePeriod.monthly;

  final _roomCountCtrl = TextEditingController();
  final _jobPositionCtrl = TextEditingController();

  ItemCategory _itemCategory = ItemCategory.all;

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

  @override
  void initState() {
    super.initState();
    _loadMyPhone();
    _initEditIfNeeded();
  }

  void _initEditIfNeeded() {
    final l = widget.editListing;
    if (l == null) return;

    _editId = (l['id'] ?? '').toString();

    _titleCtrl.text = (l['title'] ?? '').toString();
    _descCtrl.text = (l['description'] ?? '').toString();
    _cityCtrl.text = (l['city'] ?? '').toString();
    _districtCtrl.text = (l['district'] ?? '').toString();

    final price = l['price'];
    if (price != null) _priceCtrl.text = price.toString();

    _billsIncluded = l['bills_included'] == true;
    _urgent = l['is_urgent'] == true;

    _type = _parseType(l['type']);
    _pricePeriod = _parsePeriod(l['price_period']);

    final details = _castMap(l['details']);
    final rules = _castMap(l['rules']);
    final prefs = _castMap(l['preferences']);

    // ✅ doping: yeni alan varsa onu oku, yoksa eski boosted'ı none/bronze gibi map et
    if (details.containsKey('boost_plan')) {
      _boostPlan = BoostPlanX.fromDb(details['boost_plan']);
    } else if (details['boosted'] == true) {
      // eski veriler için: boosted=true ise en az bronz sayalım
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

    if (_type == ListingType.job) {
      _jobPositionCtrl.text = (details['position'] ?? '').toString();
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
    switch (s) {
      case 'item':
        return ListingType.item;
      case 'job':
        return ListingType.job;
      case 'roommate':
      default:
        return ListingType.roommate;
    }
  }

  PricePeriod _parsePeriod(dynamic v) {
    final s = (v ?? '').toString().toLowerCase().trim();
    switch (s) {
      case 'once':
        return PricePeriod.once;
      case 'daily':
        return PricePeriod.daily;
      case 'weekly':
        return PricePeriod.weekly;
      case 'yearly':
        return PricePeriod.yearly;
      case 'monthly':
      default:
        return PricePeriod.monthly;
    }
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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _priceCtrl.dispose();
    _roomCountCtrl.dispose();
    _jobPositionCtrl.dispose();
    super.dispose();
  }

  PricePeriod _defaultPeriodForType(ListingType t) {
    if (t == ListingType.item) return PricePeriod.once;
    if (t == ListingType.job) return PricePeriod.daily;
    return PricePeriod.monthly;
  }

  int _remainingPickCount() {
    final current = _existingImagePaths.length + _pickedImages.length;
    final remaining = 10 - current;
    return remaining < 0 ? 0 : remaining;
  }

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

  void _removeNewImageAt(int i) {
    setState(() => _pickedImages.removeAt(i));
  }

  void _removeExistingPath(String path) {
    setState(() {
      _existingImagePaths.remove(path);
      _existingUrlCache.remove(path);
      _removedExistingPaths.add(path);
    });
  }

  // ✅ Doping detaylarını tek yerden üretelim
  Map<String, dynamic> _buildBoostDetails() {
    final now = DateTime.now();
    final days = _boostPlan.days;

    final boosted = _boostPlan != BoostPlan.none;
    final end = boosted ? now.add(Duration(days: days)) : null;

    return <String, dynamic>{
      'boost_plan': _boostPlan.dbValue, // none/bronze/silver/gold
      'boosted': boosted, // geri uyum
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
    } else if (_type == ListingType.item) {
      final v = _itemCategory.dbValue;
      if (v != null) details['category'] = v;
    } else if (_type == ListingType.job) {
      if (_jobPositionCtrl.text.trim().isNotEmpty) {
        details['position'] = _jobPositionCtrl.text.trim();
      }
      details['job_type'] = (_pricePeriod == PricePeriod.monthly)
          ? 'monthly'
          : 'daily';
    }

    // ✅ doping detaylarını ekle
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

  Future<void> _save({required bool publish}) async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Başlık zorunlu.')));
      return;
    }

    setState(() => _loading = true);

    try {
      if (_myPhone == null && !_loadingPhone) {
        await _loadMyPhone();
      }

      final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.'));
      final status = publish ? 'published' : 'draft';

      // ================= EDIT =================
      if (widget.isEdit) {
        final id = _editId;
        if (id == null || id.isEmpty) throw Exception('İlan id bulunamadı.');

        await _service.updateListing(
          listingId: id,
          type: _type,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
          district: _districtCtrl.text.trim().isEmpty
              ? null
              : _districtCtrl.text.trim(),
          price: price,
          pricePeriod: (_type == ListingType.item)
              ? PricePeriod.once
              : _pricePeriod,
          billsIncluded: _billsIncluded,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              publish ? 'Güncellendi + Yayınlandı ✅' : 'Güncellendi ✅',
            ),
          ),
        );
        Navigator.pop(context, true);
        return;
      }

      // ================= CREATE =================
      final listingId = await _service.createListing(
        type: _type,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        district: _districtCtrl.text.trim().isEmpty
            ? null
            : _districtCtrl.text.trim(),
        price: price,
        pricePeriod: (_type == ListingType.item)
            ? PricePeriod.once
            : _pricePeriod,
        billsIncluded: _billsIncluded,
        isUrgent: _urgent,
        phone: _myPhone,
        details: _buildDetails(),
        rules: _buildRules(),
        preferences: _buildPreferences(),
        status: status,
      );

      if (_pickedImages.isNotEmpty) {
        final xfiles = _pickedImages.map((e) => e.file).toList();
        final paths = await _service.uploadListingImages(
          listingId: listingId,
          images: xfiles,
        );
        await _service.attachListingImages(
          listingId: listingId,
          imagePaths: paths,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            publish
                ? 'Yayınlandı ✅ (id: $listingId)'
                : 'Taslak kaydedildi ✅ (id: $listingId)',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hata: $e')));
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
    final totalCount = _existingImagePaths.length + _pickedImages.length;

    return _card('Yeni Fotoğraflar', [
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
      if (_pickedImages.isEmpty)
        const Text('Toplamda en fazla 10 fotoğraf olabilir.'),
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
    ]);
  }

  Widget _photoManagementSection() {
    if (!widget.isEdit) return const SizedBox.shrink();

    return _card('Foto Yönetimi', [
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

  // ✅ DOPING: artık hem create hem editte görünsün
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
        'Not: Şimdilik sadece plan bilgisi kaydediliyor. (Ödeme/aktif sıralama kısmını sonra bağlarız.)',
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

  @override
  Widget build(BuildContext context) {
    final periodItems = PricePeriod.values
        .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
        .toList();

    final phoneText = _loadingPhone
        ? 'Telefon: yükleniyor...'
        : (_myPhone == null || _myPhone!.trim().isEmpty)
        ? 'Telefon: Profilinde yok (Profilim’den ekleyebilirsin)'
        : 'Telefon (profil): ${_myPhone!}';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        title: Text(widget.isEdit ? 'İlanı Düzenle' : 'İlan Ekle'),
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
                items: ListingType.values
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
                          if (_type == ListingType.item)
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

            // ✅ Doping: artık her iki modda da var
            _dopingSection(),

            // ✅ Editte: foto yönetimi + mevcut fotolar
            _photoManagementSection(),
            _existingImagesSection(),
            _newImagesSection(),

            _card('Konum', [
              TextField(
                controller: _cityCtrl,
                decoration: const InputDecoration(labelText: 'Şehir'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _districtCtrl,
                decoration: const InputDecoration(labelText: 'İlçe'),
              ),
            ]),

            _card('Fiyat ve Periyot', [
              TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Fiyat'),
              ),
              const SizedBox(height: 10),
              if (_type != ListingType.item)
                DropdownButtonFormField<PricePeriod>(
                  value: _pricePeriod,
                  decoration: const InputDecoration(
                    labelText: 'Fiyat Periyodu',
                  ),
                  items: periodItems,
                  onChanged: (v) =>
                      setState(() => _pricePeriod = v ?? _pricePeriod),
                ),
              const SizedBox(height: 10),
              if (_type == ListingType.roommate)
                SwitchListTile(
                  value: _billsIncluded,
                  onChanged: (v) => setState(() => _billsIncluded = v),
                  title: const Text('Faturalar dahil mi? (ev için)'),
                  contentPadding: EdgeInsets.zero,
                ),
              SwitchListTile(
                value: _urgent,
                onChanged: (v) => setState(() => _urgent = v),
                title: const Text('Acil / öne çıkar'),
                contentPadding: EdgeInsets.zero,
              ),
            ]),

            _card('Türüne Göre Ek Alanlar', [
              if (_type == ListingType.roommate)
                TextField(
                  controller: _roomCountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ev Oda Sayısı (örn: 2+1)',
                  ),
                ),
              if (_type == ListingType.job) ...[
                TextField(
                  controller: _jobPositionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pozisyon (örn: garson)',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Acil iş ilanında genelde "Günlük" veya "Aylık" seçilir.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
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
