import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listing_enums.dart';
import 'listings_service.dart';

/// ================= EV EŞYASI KATEGORİ =================
/// Not: "Hepsi" seçilirse details['category'] yazmayacağız.
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

  /// DB’de saklanacak değer
  String? get dbValue {
    switch (this) {
      case ItemCategory.all:
        return null; // Hepsi = kategori yok
      case ItemCategory.whiteGoods:
        return 'white_goods';
      case ItemCategory.furniture:
        return 'furniture';
      case ItemCategory.other:
        return 'other';
    }
  }

  /// DB’den okurken lazım olursa (ileride)
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

class ListingCreatePage extends StatefulWidget {
  const ListingCreatePage({super.key});

  @override
  State<ListingCreatePage> createState() => _ListingCreatePageState();
}

class _ListingCreatePageState extends State<ListingCreatePage> {
  final _service = ListingsService();
  final _picker = ImagePicker();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  bool _billsIncluded = false;
  bool _urgent = false;

  ListingType _type = ListingType.roommate;
  PricePeriod _pricePeriod = PricePeriod.monthly;

  // Tip-özel örnek alanlar (details)
  final _roomCountCtrl = TextEditingController(); // ev arkadaşı
  final _jobPositionCtrl = TextEditingController(); // acil iş

  // ✅ Ev eşyası kategori dropdown
  ItemCategory _itemCategory = ItemCategory.all;

  // ✅ Kurallar (rules)
  bool _ruleSmoking = false;
  bool _rulePets = false;
  bool _ruleGuests = true;

  // ✅ Tercihler (preferences)
  String _prefGender = 'any'; // any / male / female
  bool _prefStudent = false;
  bool _prefWorker = false;

  // Foto seçimi (XFile + bytes) -> hem Android hem Web için
  final List<_PickedImage> _pickedImages = [];

  bool _loading = false;

  // ✅ PROFİL TELEFONU (otomatik)
  String? _myPhone;
  bool _loadingPhone = true;

  @override
  void initState() {
    super.initState();
    _loadMyPhone();
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
    if (t == ListingType.item) return PricePeriod.once; // tek sefer
    if (t == ListingType.job) return PricePeriod.daily; // acil iş çoğu günlük
    return PricePeriod.monthly; // ev arkadaşı çoğu aylık
  }

  Future<void> _pickImages() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 80);
      if (!mounted) return;
      if (files.isEmpty) return;

      final remaining = 10 - _pickedImages.length;
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

  void _removeImageAt(int i) {
    setState(() => _pickedImages.removeAt(i));
  }

  Map<String, dynamic> _buildDetails() {
    final details = <String, dynamic>{};

    if (_type == ListingType.roommate) {
      if (_roomCountCtrl.text.trim().isNotEmpty) {
        details['room_count'] = _roomCountCtrl.text.trim(); // "2+1" gibi
      }
    } else if (_type == ListingType.item) {
      // ✅ dropdown kategoriyi DB'ye yaz
      final v = _itemCategory.dbValue;
      if (v != null) details['category'] = v;
    } else if (_type == ListingType.job) {
      if (_jobPositionCtrl.text.trim().isNotEmpty) {
        details['position'] = _jobPositionCtrl.text.trim(); // "garson" vb
      }
      details['job_type'] = (_pricePeriod == PricePeriod.monthly)
          ? 'monthly'
          : 'daily';
    }

    return details;
  }

  // ✅ rules jsonb
  Map<String, dynamic> _buildRules() {
    if (_type != ListingType.roommate) return {}; // şimdilik sadece ev arkadaşı
    return <String, dynamic>{
      'smoking': _ruleSmoking,
      'pets': _rulePets,
      'guests': _ruleGuests,
    };
  }

  // ✅ preferences jsonb
  Map<String, dynamic> _buildPreferences() {
    if (_type != ListingType.roommate) return {}; // şimdilik sadece ev arkadaşı
    return <String, dynamic>{
      'gender': _prefGender, // any/male/female
      'student': _prefStudent,
      'worker': _prefWorker,
    };
  }

  Map<String, dynamic> _buildDraftPayload({
    required bool publish,
    required String? phoneFromProfile,
  }) {
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.'));

    return <String, dynamic>{
      'type': _type,
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      'district': _districtCtrl.text.trim().isEmpty
          ? null
          : _districtCtrl.text.trim(),
      'price': price,

      // ✅ ev eşyasında periyot zorla once
      'pricePeriod': (_type == ListingType.item)
          ? PricePeriod.once
          : _pricePeriod,

      'billsIncluded': _billsIncluded,
      'isUrgent': _urgent,
      'phone': phoneFromProfile,
      'details': _buildDetails(),
      'rules': _buildRules(),
      'preferences': _buildPreferences(),
      'status': publish ? 'published' : 'draft',
    };
  }

  Future<void> _openPreview() async {
    final payload = _buildDraftPayload(
      publish: true,
      phoneFromProfile: _myPhone,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListingPreviewPage(
          payload: payload,
          images: List<_PickedImage>.from(_pickedImages),
        ),
      ),
    );
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

      final payload = _buildDraftPayload(
        publish: publish,
        phoneFromProfile: _myPhone,
      );

      final listingId = await _service.createListing(
        type: payload['type'] as ListingType,
        title: payload['title'] as String,
        description: payload['description'] as String?,
        city: payload['city'] as String?,
        district: payload['district'] as String?,
        price: payload['price'] as double?,
        pricePeriod: payload['pricePeriod'] as PricePeriod,
        billsIncluded: payload['billsIncluded'] as bool,
        isUrgent: payload['isUrgent'] as bool,
        phone: payload['phone'] as String?,
        details: payload['details'] as Map<String, dynamic>,
        rules: payload['rules'] as Map<String, dynamic>,
        preferences: payload['preferences'] as Map<String, dynamic>,
        status: payload['status'] as String,
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

  Widget _imagesSection() {
    return _card('Fotoğraflar', [
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _pickImages,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _pickedImages.isEmpty
                    ? 'Fotoğraf Seç'
                    : 'Fotoğraf Ekle (${_pickedImages.length}/10)',
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
        const Text('En fazla 10 fotoğraf seçebilirsin.'),
      if (_pickedImages.isNotEmpty)
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _pickedImages.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
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
                      onTap: () => _removeImageAt(i),
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
        title: const Text('İlan Ekle'),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _openPreview,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Önizleme'),
          ),
        ],
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
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _type = v;
                    _pricePeriod = _defaultPeriodForType(v);

                    if (_type != ListingType.roommate) _billsIncluded = false;

                    // ✅ ev eşyasına geçince kategori default "Hepsi" olsun
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

              // ✅ SADECE EV EŞYASI: KATEGORİ BAŞLIK İLE AÇIKLAMA ARASINDA (DROPDOWN)
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
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _itemCategory = v);
                  },
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

            _imagesSection(),

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

              // ✅ SADECE EV EŞYASINDA: FİYAT PERİYODU GÖZÜKMEYECEK
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
              if (_type == ListingType.roommate) ...[
                TextField(
                  controller: _roomCountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ev Oda Sayısı (örn: 2+1)',
                  ),
                ),
              ],
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
                    child: _loading ? const Text('...') : const Text('Yayınla'),
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

/// ================== ÖNİZLEME SAYFASI ==================
class ListingPreviewPage extends StatelessWidget {
  const ListingPreviewPage({
    super.key,
    required this.payload,
    required this.images,
  });

  final Map<String, dynamic> payload;
  final List<_PickedImage> images;

  String _fmtPrice() {
    final price = payload['price'];
    if (price == null) return 'Fiyat belirtilmemiş';

    final pp = payload['pricePeriod'] as PricePeriod;
    final double p = (price is num)
        ? price.toDouble()
        : double.tryParse('$price') ?? 0;

    final str = (p % 1 == 0) ? p.toStringAsFixed(0) : p.toStringAsFixed(2);
    return '₺$str / ${pp.label}';
  }

  String _labelGender(String v) {
    switch (v) {
      case 'male':
        return 'Erkek';
      case 'female':
        return 'Kadın';
      default:
        return 'Farketmez';
    }
  }

  String _labelItemCategoryFromDetails(Map details) {
    final v = (details['category'] ?? '').toString();
    switch (v) {
      case 'white_goods':
        return 'Beyaz Eşya';
      case 'furniture':
        return 'Mobilya';
      case 'other':
        return 'Diğer';
      default:
        return 'Hepsi';
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = payload['type'] as ListingType;
    final title = (payload['title'] ?? '').toString();
    final desc = (payload['description'] ?? '').toString();
    final city = (payload['city'] ?? '').toString();
    final district = (payload['district'] ?? '').toString();
    final phone = (payload['phone'] ?? '').toString();
    final urgent = payload['isUrgent'] == true;
    final bills = payload['billsIncluded'] == true;

    final rules = (payload['rules'] as Map?)?.cast<String, dynamic>() ?? {};
    final prefs =
        (payload['preferences'] as Map?)?.cast<String, dynamic>() ?? {};
    final details = (payload['details'] as Map?)?.cast<String, dynamic>() ?? {};

    final loc = [
      if (city.trim().isNotEmpty) city.trim(),
      if (district.trim().isNotEmpty) district.trim(),
    ].join(' / ');

    List<String> ruleChips = [];
    if (type == ListingType.roommate && rules.isNotEmpty) {
      ruleChips.add(
        rules['smoking'] == true ? 'Sigara: Evet' : 'Sigara: Hayır',
      );
      ruleChips.add(rules['pets'] == true ? 'Evcil: Var' : 'Evcil: Yok');
      ruleChips.add(
        rules['guests'] == true ? 'Misafir: Olur' : 'Misafir: Olmaz',
      );
    }

    List<String> prefChips = [];
    if (type == ListingType.roommate && prefs.isNotEmpty) {
      prefChips.add(
        'Cinsiyet: ${_labelGender((prefs['gender'] ?? 'any').toString())}',
      );
      if (prefs['student'] == true) prefChips.add('Öğrenci');
      if (prefs['worker'] == true) prefChips.add('Çalışan');
      if (prefs['student'] != true && prefs['worker'] != true) {
        prefChips.add('Meslek: Farketmez');
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Önizleme')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.isEmpty ? '(Başlıksız)' : title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (urgent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'ACİL',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(context, type.label),
                      _chip(context, _fmtPrice()),
                      if (loc.isNotEmpty) _chip(context, loc),
                      if (type == ListingType.roommate && bills)
                        _chip(context, 'Faturalar dahil'),
                      if (type == ListingType.item)
                        _chip(
                          context,
                          'Kategori: ${_labelItemCategoryFromDetails(details)}',
                        ),
                      if (phone.trim().isNotEmpty)
                        _chip(context, 'Tel: $phone'),
                    ],
                  ),
                  if (ruleChips.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Kurallar',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ruleChips
                          .map((t) => _chip(context, t))
                          .toList(),
                    ),
                  ],
                  if (prefChips.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Tercihler',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: prefChips
                          .map((t) => _chip(context, t))
                          .toList(),
                    ),
                  ],
                  if (desc.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(desc),
                  ],
                ],
              ),
            ),
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Fotoğraflar', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: PageView.builder(
                itemCount: images.length,
                itemBuilder: (_, i) {
                  final img = images[i];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(img.bytes, fit: BoxFit.cover),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
