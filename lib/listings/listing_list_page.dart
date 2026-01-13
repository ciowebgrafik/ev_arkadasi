import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listing_detail_page.dart';
import 'listing_enums.dart';
import 'listings_service.dart';

enum SortOption { newest, priceAsc, priceDesc }

// ✅ Ev Eşyası için kategori
enum ItemCategory { whiteGoods, furniture, other }

extension ItemCategoryX on ItemCategory {
  String get label {
    switch (this) {
      case ItemCategory.whiteGoods:
        return 'Beyaz Eşya';
      case ItemCategory.furniture:
        return 'Mobilya';
      case ItemCategory.other:
        return 'Diğer';
    }
  }

  String get db {
    switch (this) {
      case ItemCategory.whiteGoods:
        return 'white_goods';
      case ItemCategory.furniture:
        return 'furniture';
      case ItemCategory.other:
        return 'other';
    }
  }

  static ItemCategory? fromDb(String s) {
    final x = s.trim().toLowerCase();
    if (x == 'white_goods' || x == 'whitegoods' || x == 'beyaz_esya') {
      return ItemCategory.whiteGoods;
    }
    if (x == 'furniture' || x == 'mobilya') return ItemCategory.furniture;
    if (x == 'other' || x == 'diger' || x == 'diğer') return ItemCategory.other;
    return null;
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

class ListingListPage extends StatefulWidget {
  const ListingListPage({
    super.key,
    this.initialType,
    this.initialPeriod,
    this.initialItemCategory,
    this.initialCity,
    this.initialDistrict,
    this.initialQuery,
  });

  final ListingType? initialType;
  final PricePeriod? initialPeriod;
  final ItemCategory? initialItemCategory;

  final String? initialCity;
  final String? initialDistrict;
  final String? initialQuery;

  @override
  State<ListingListPage> createState() => _ListingListPageState();
}

class _ListingListPageState extends State<ListingListPage> {
  static const Color kTurkuaz = Color(0xFF00B8D4);

  final _service = ListingsService();
  final SupabaseClient _sb = Supabase.instance.client;

  // ✅ Saved Searches Service (Supabase)
  final _savedSearchService = SavedSearchesService();

  // Filters
  ListingType? _type;
  PricePeriod? _period; // Ev Arkadaşı / İş vb için
  ItemCategory? _itemCategory; // ✅ Ev Eşyası için

  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();

  // ✅ Arama (kelime)
  final _qCtrl = TextEditingController();

  // Sort
  SortOption _sort = SortOption.newest;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  // ✅ signed url cache (listingId -> url)
  final Map<String, String?> _firstImageUrlCache = {};

  bool get _isItemTypeSelected => _type == ListingType.item;

  // ===========================
  // ✅ City / District dropdown state (Filtre için)
  // ===========================
  bool _loadingCities = false;
  bool _loadingDistricts = false;
  String? _locError;

  List<_CityRow> _cities = [];
  List<_DistrictRow> _districts = [];

  int? _selectedCityId;
  int? _selectedDistrictId;

  @override
  void initState() {
    super.initState();

    _type = widget.initialType;

    if ((widget.initialCity ?? '').trim().isNotEmpty) {
      _cityCtrl.text = widget.initialCity!.trim();
    }
    if ((widget.initialDistrict ?? '').trim().isNotEmpty) {
      _districtCtrl.text = widget.initialDistrict!.trim();
    }
    if ((widget.initialQuery ?? '').trim().isNotEmpty) {
      _qCtrl.text = widget.initialQuery!.trim();
    }

    if (_type == ListingType.item) {
      _itemCategory = widget.initialItemCategory;
      _period = null;
    } else {
      _period = widget.initialPeriod;
      _itemCategory = null;
    }

    _loadCities(); // ✅ filtre dropdown için şehirleri hazırla
    _load();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _qCtrl.dispose();
    super.dispose();
  }

  // ===========================
  // ✅ Load cities/districts (Filtre)
  // ===========================
  Future<void> _loadCities() async {
    setState(() {
      _loadingCities = true;
      _locError = null;
    });

    try {
      final res = await _sb.from('cities').select('id,name,slug').order('id');

      _cities = (res as List)
          .map((e) => _CityRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      // ✅ text olarak şehir/ilçe doluysa id'ye eşle (isim veya slug ile)
      final cityTxt = _clean(_cityCtrl.text).toLowerCase();
      if (cityTxt.isNotEmpty) {
        final foundCity = _cities.firstWhere(
          (c) =>
              c.name.trim().toLowerCase() == cityTxt ||
              c.slug.trim().toLowerCase() == cityTxt,
          orElse: () => const _CityRow(id: -1, name: '', slug: ''),
        );
        if (foundCity.id != -1) {
          _selectedCityId = foundCity.id;

          await _loadDistricts(foundCity.id);

          final distTxt = _clean(_districtCtrl.text).toLowerCase();
          if (distTxt.isNotEmpty) {
            final foundDist = _districts.firstWhere(
              (d) =>
                  d.name.trim().toLowerCase() == distTxt ||
                  d.slug.trim().toLowerCase() == distTxt,
              orElse: () =>
                  const _DistrictRow(id: -1, cityId: -1, name: '', slug: ''),
            );
            if (foundDist.id != -1) {
              _selectedDistrictId = foundDist.id;
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
    });

    try {
      final res = await _sb
          .from('districts')
          .select('id,city_id,name,slug')
          .eq('city_id', cityId)
          .order('name');

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

  Future<void> _ensureCitiesLoaded() async {
    if (_cities.isNotEmpty) return;
    await _loadCities();
  }

  // ---------------------- BOOST BADGE HELPERS ----------------------
  Map<String, dynamic> _detailsOf(Map<String, dynamic> item) {
    final d = item['details'];
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return d.map((k, v) => MapEntry('$k', v));
    return {};
  }

  bool _isBoostActive(Map<String, dynamic> item) {
    final details = _detailsOf(item);
    final endStr = (details['boost_end'] ?? '').toString().trim();
    if (endStr.isEmpty) return false;

    try {
      final end = DateTime.parse(endStr);
      return end.isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  /// ✅ SIRALAMA ÖNCELİĞİ
  /// ALTIN (3) > ÖNE ÇIKAR (2) > ACİL (1) > NORMAL (0)
  int _boostRank(Map<String, dynamic> item) {
    if (!_isBoostActive(item)) return 0;

    final details = _detailsOf(item);
    final plan = (details['boost_plan'] ?? '').toString().toLowerCase().trim();

    switch (plan) {
      case 'gold':
        return 3;
      case 'featured':
        return 2;
      case 'urgent':
        return 1;
    }
    return 0;
  }

  // ✅ rozet rengi (yıldız)
  Color? _boostStarColor(Map<String, dynamic> item) {
    if (!_isBoostActive(item)) return null;

    final details = _detailsOf(item);
    final plan = (details['boost_plan'] ?? '').toString().toLowerCase().trim();

    if (plan == 'gold') return const Color(0xFFFFC107); // ALTIN sarı
    if (plan == 'featured') return const Color(0xFF00B8D4); // ÖNE ÇIKAR mavi
    if (plan == 'urgent') return Colors.grey; // ACİL gri
    return null;
  }

  // ✅ küçük yıldız rozet widget'ı
  Widget _boostStarBadge(Map<String, dynamic> item) {
    final color = _boostStarColor(item);
    if (color == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            blurRadius: 6,
            offset: Offset(0, 2),
            color: Color(0x33000000),
          ),
        ],
      ),
      child: Icon(
        Icons.star_rounded,
        size: 16, // ✅ küçük yıldız
        color: color,
      ),
    );
  }

  // ===========================
  // ✅ ARAMA: yazılan metinden "ilan türü" tahmini
  // (sadece _type seçili değilse devreye girer)
  // ===========================
  Set<ListingType> _inferTypesFromQuery(String raw) {
    final q = raw.toLowerCase().trim();
    if (q.isEmpty) return {};

    bool hasAny(List<String> keys) => keys.any((k) => q.contains(k));

    final out = <ListingType>{};

    // job
    if (hasAny([
      'iş',
      'is ilan',
      'iş ilan',
      'job',
      'kariyer',
      'çalış',
      'calis',
    ])) {
      if (ListingType.values.map((e) => e.name).contains('job')) {
        out.add(ListingType.values.byName('job'));
      }
    }

    // roommate
    if (hasAny([
      'ev arkadaşı',
      'ev arkadasi',
      'roommate',
      'kiracı',
      'kiraci',
    ])) {
      if (ListingType.values.map((e) => e.name).contains('roommate')) {
        out.add(ListingType.values.byName('roommate'));
      }
    }

    // item (eşya)
    if (hasAny([
      'eşya',
      'esya',
      'mobilya',
      'beyaz eşya',
      'beyaz esya',
      'dolap',
      'buzdolabı',
      'buzdolabi',
    ])) {
      out.add(ListingType.item);
    }

    return out;
  }

  // ---------------------- ✅ FETCH (title/desc + type search) ----------------------
  Future<List<Map<String, dynamic>>> _fetchListingsDirect() async {
    final cityTxt = _clean(_cityCtrl.text);
    final distTxt = _clean(_districtCtrl.text);
    final qTxt = _clean(_qCtrl.text);

    var query = _sb.from('listings').select('*');

    // ✅ SADECE YAYINDAKİLERİ GÖSTER
    query = query.eq('status', 'published');

    // ✅ Tür filtresi (seçiliyse)
    if (_type != null) {
      query = query.eq('type', listingTypeToDb(_type!));
    }

    // ✅ Periyot / Kategori
    if (_type == ListingType.item) {
      if (_itemCategory != null) {
        query = query.contains('details', {'category': _itemCategory!.db});
      }
    } else {
      if (_period != null) {
        query = query.eq('price_period', pricePeriodToDb(_period!));
      }
    }

    // ✅ Konum (id ile filtre)
    if (_selectedCityId != null) {
      query = query.eq('city_id', _selectedCityId!);
    } else if (cityTxt.isNotEmpty) {
      // ✅ FIX: ilike pattern olmalı
      query = query.ilike('city', '%$cityTxt%');
    }

    if (_selectedDistrictId != null) {
      query = query.eq('district_id', _selectedDistrictId!);
    } else if (distTxt.isNotEmpty) {
      // ✅ FIX: ilike pattern olmalı
      query = query.ilike('district', '%$distTxt%');
    }

    // ✅ Arama: başlık/açıklama + (type search)
    if (qTxt.isNotEmpty) {
      final pattern = '%$qTxt%';

      final orParts = <String>[
        'title.ilike.$pattern',
        'description.ilike.$pattern',
      ];

      // ✅ type search sadece tür filtresi seçili değilse
      if (_type == null) {
        final inferred = _inferTypesFromQuery(qTxt);
        for (final t in inferred) {
          orParts.add('type.eq.${listingTypeToDb(t)}');
        }
      }

      query = query.or(orParts.join(','));
    }

    // ✅ Sıralama: önce created_at çekelim, sonra localde boost + seçilen sort
    final res = await query.order('created_at', ascending: false);

    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ---------------------- LOAD ----------------------
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _fetchListingsDirect();
      if (!mounted) return;

      final sorted = List<Map<String, dynamic>>.from(items);

      // ✅ BOOST ÖNCELİKLİ SIRALAMA:
      // önce boostRank (gold>silver>bronze>none), sonra seçilen sort
      _applySort(sorted);

      // ✅ cache reset (liste değişince eski resim/url kalmasın)
      _firstImageUrlCache.clear();

      setState(() => _items = sorted);

      for (final it in sorted) {
        final id = (it['id'] ?? '').toString();
        if (id.isEmpty) continue;
        if (_firstImageUrlCache.containsKey(id)) continue;
        _firstImageUrlCache[id] = await _getFirstImageSignedUrl(it);
      }

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySort(List<Map<String, dynamic>> list) {
    double priceOf(Map<String, dynamic> it) {
      final p = it['price'];
      if (p == null) return -1;
      if (p is num) return p.toDouble();
      return double.tryParse('$p') ?? -1;
    }

    int createdCmp(Map<String, dynamic> a, Map<String, dynamic> b) {
      final ca = (a['created_at'] ?? '').toString();
      final cb = (b['created_at'] ?? '').toString();
      return cb.compareTo(ca); // yeni -> eski
    }

    // ✅ 1) önce boost önceliği
    int boostCmp(Map<String, dynamic> a, Map<String, dynamic> b) {
      final ra = _boostRank(a);
      final rb = _boostRank(b);
      if (ra != rb) return rb.compareTo(ra); // büyük rank öne
      return 0;
    }

    if (_sort == SortOption.newest) {
      list.sort((a, b) {
        final bc = boostCmp(a, b);
        if (bc != 0) return bc;
        return createdCmp(a, b);
      });
      return;
    }

    if (_sort == SortOption.priceAsc) {
      list.sort((a, b) {
        final bc = boostCmp(a, b);
        if (bc != 0) return bc;

        final pa = priceOf(a);
        final pb = priceOf(b);
        if (pa < 0 && pb < 0) return createdCmp(a, b);
        if (pa < 0) return 1;
        if (pb < 0) return -1;
        final pc = pa.compareTo(pb);
        return pc != 0 ? pc : createdCmp(a, b);
      });
      return;
    }

    if (_sort == SortOption.priceDesc) {
      list.sort((a, b) {
        final bc = boostCmp(a, b);
        if (bc != 0) return bc;

        final pa = priceOf(a);
        final pb = priceOf(b);
        if (pa < 0 && pb < 0) return createdCmp(a, b);
        if (pa < 0) return 1;
        if (pb < 0) return -1;
        final pc = pb.compareTo(pa);
        return pc != 0 ? pc : createdCmp(a, b);
      });
      return;
    }
  }

  // ---------------------- TOP ACTIONS ----------------------
  Future<void> _openFilterSheet() async {
    await _ensureCitiesLoaded();

    ListingType? tmpType = _type;
    PricePeriod? tmpPeriod = _period;
    ItemCategory? tmpItemCat = _itemCategory;

    int? tmpCityId = _selectedCityId;
    int? tmpDistrictId = _selectedDistrictId;

    String tmpCityName = _cityCtrl.text;
    String tmpDistrictName = _districtCtrl.text;

    // ✅ text var ama id yoksa eşle
    if (tmpCityId == null && _cities.isNotEmpty) {
      final cityLower = _clean(tmpCityName).toLowerCase();
      if (cityLower.isNotEmpty) {
        final found = _cities.firstWhere(
          (c) =>
              c.name.trim().toLowerCase() == cityLower ||
              c.slug.trim().toLowerCase() == cityLower,
          orElse: () => const _CityRow(id: -1, name: '', slug: ''),
        );
        if (found.id != -1) {
          tmpCityId = found.id;
          tmpCityName = found.name;
          await _loadDistricts(found.id);
        }
      }
    }

    if (tmpCityId != null && _districts.isEmpty) {
      await _loadDistricts(tmpCityId);
    }

    if (tmpDistrictId == null && tmpCityId != null && _districts.isNotEmpty) {
      final distLower = _clean(tmpDistrictName).toLowerCase();
      if (distLower.isNotEmpty) {
        final foundDist = _districts.firstWhere(
          (d) =>
              d.name.trim().toLowerCase() == distLower ||
              d.slug.trim().toLowerCase() == distLower,
          orElse: () =>
              const _DistrictRow(id: -1, cityId: -1, name: '', slug: ''),
        );
        if (foundDist.id != -1) {
          tmpDistrictId = foundDist.id;
          tmpDistrictName = foundDist.name;
        }
      }
    }

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final safeBottom = MediaQuery.of(ctx).padding.bottom;
        final bottomPad = bottomInset + safeBottom + 16;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: bottomPad,
            ),
            child: StatefulBuilder(
              builder: (ctx, setLocal) {
                final isItem = tmpType == ListingType.item;

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 6),
                      const Text(
                        'Filtrele',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<ListingType?>(
                        value: tmpType,
                        decoration: const InputDecoration(
                          labelText: 'Tür',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Hepsi'),
                          ),
                          ...ListingType.values.map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.label),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setLocal(() {
                            tmpType = v;
                            if (tmpType == ListingType.item) {
                              tmpPeriod = null;
                            } else {
                              tmpItemCat = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      if (isItem)
                        DropdownButtonFormField<ItemCategory?>(
                          value: tmpItemCat,
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Hepsi'),
                            ),
                            ...ItemCategory.values.map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.label),
                              ),
                            ),
                          ],
                          onChanged: (v) => setLocal(() => tmpItemCat = v),
                        ),

                      if (!isItem)
                        DropdownButtonFormField<PricePeriod?>(
                          value: tmpPeriod,
                          decoration: const InputDecoration(
                            labelText: 'Periyot',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Hepsi'),
                            ),
                            ...PricePeriod.values.map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(p.label),
                              ),
                            ),
                          ],
                          onChanged: (v) => setLocal(() => tmpPeriod = v),
                        ),

                      const SizedBox(height: 12),

                      if (_locError != null) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _locError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      DropdownButtonFormField<int?>(
                        value: tmpCityId,
                        decoration: const InputDecoration(
                          labelText: 'Şehir',
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Hepsi'),
                          ),
                          ..._cities.map(
                            (c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          ),
                        ],
                        onChanged: (_loadingCities)
                            ? null
                            : (v) async {
                                setLocal(() {
                                  tmpCityId = v;
                                  tmpDistrictId = null;
                                  tmpDistrictName = '';
                                });

                                if (v == null) {
                                  setLocal(() {
                                    tmpCityName = '';
                                  });
                                  _districts = [];
                                  if (mounted) setLocal(() {});
                                  return;
                                }

                                final city = _cities.firstWhere(
                                  (c) => c.id == v,
                                );
                                setLocal(() {
                                  tmpCityName = city.name;
                                });

                                await _loadDistricts(v);
                                if (mounted) setLocal(() {});
                              },
                      ),

                      const SizedBox(height: 12),

                      DropdownButtonFormField<int?>(
                        value: tmpDistrictId,
                        decoration: InputDecoration(
                          labelText: (tmpCityId == null)
                              ? 'Önce şehir seç'
                              : 'İlçe',
                          border: const OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Hepsi'),
                          ),
                          ..._districts.map(
                            (d) => DropdownMenuItem<int?>(
                              value: d.id,
                              child: Text(d.name),
                            ),
                          ),
                        ],
                        onChanged: (tmpCityId == null || _loadingDistricts)
                            ? null
                            : (v) {
                                setLocal(() {
                                  tmpDistrictId = v;
                                  if (v == null) {
                                    tmpDistrictName = '';
                                  } else {
                                    final d = _districts.firstWhere(
                                      (x) => x.id == v,
                                    );
                                    tmpDistrictName = d.name;
                                  }
                                });
                              },
                      ),

                      const SizedBox(height: 10),
                      if (_loadingCities || _loadingDistricts)
                        const LinearProgressIndicator(minHeight: 2),

                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setLocal(() {
                                  tmpType = null;
                                  tmpPeriod = null;
                                  tmpItemCat = null;
                                  tmpCityId = null;
                                  tmpDistrictId = null;
                                  tmpCityName = '';
                                  tmpDistrictName = '';
                                });
                              },
                              child: const Text('Sıfırla'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Uygula'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (applied == true) {
      setState(() {
        _type = tmpType;

        if (_type == ListingType.item) {
          _itemCategory = tmpItemCat;
          _period = null;
        } else {
          _period = tmpPeriod;
          _itemCategory = null;
        }

        _cityCtrl.text = _clean(tmpCityName);
        _districtCtrl.text = _clean(tmpDistrictName);

        _selectedCityId = tmpCityId;
        _selectedDistrictId = tmpDistrictId;
      });

      await _load();
    }
  }

  void _onSortSelected(SortOption s) {
    setState(() => _sort = s);
    final copy = List<Map<String, dynamic>>.from(_items);
    _applySort(copy);
    setState(() => _items = copy);
  }

  // ✅ KAYITLI ARAMALAR: AÇ
  Future<void> _openSavedSearchesSheet() async {
    final user = _sb.auth.currentUser;
    if (user == null) {
      _snack('Önce giriş yapmalısın.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Kayıtlı Aramalar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<SavedSearch>>(
                  future: _savedSearchService.fetch(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Column(
                          children: [
                            Text('Hata: ${snap.error}'),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Kapat'),
                            ),
                          ],
                        ),
                      );
                    }

                    final list = snap.data ?? [];
                    if (list.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Text('Henüz kayıtlı arama yok.'),
                      );
                    }

                    return Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final s = list[i];
                          final subtitle = _filtersSummary(s.filters);

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            await _applySavedSearch(s);
                                          },
                                          icon: const Icon(Icons.play_arrow),
                                          label: const Text('Uygula'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          final ok = await _confirm(
                                            title: 'Silinsin mi?',
                                            message:
                                                'Bu kayıtlı aramayı silmek istiyor musun?',
                                          );
                                          if (ok != true) return;

                                          try {
                                            await _savedSearchService.delete(
                                              s.id,
                                            );
                                            if (!mounted) return;
                                            Navigator.pop(ctx);
                                            _snack('Silindi ✅');
                                          } catch (e) {
                                            if (!mounted) return;
                                            _snack('Silinemedi: $e');
                                          }
                                        },
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Sil'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ KAYITLI ARAMAYI UYGULA
  Future<void> _applySavedSearch(SavedSearch s) async {
    final f = s.filters;

    ListingType? newType;
    PricePeriod? newPeriod;
    ItemCategory? newItemCat;

    final typeStr = (f['type'] ?? '').toString().trim();
    if (typeStr.isNotEmpty) {
      try {
        newType = ListingType.values.byName(typeStr);
      } catch (_) {}
    }

    final itemCatStr = (f['item_category'] ?? '').toString().trim();
    if (itemCatStr.isNotEmpty) newItemCat = ItemCategoryX.fromDb(itemCatStr);

    final periodStr = (f['period'] ?? '').toString().trim();
    if (periodStr.isNotEmpty) {
      try {
        newPeriod = PricePeriod.values.byName(periodStr);
      } catch (_) {}
    }

    final q = (f['q'] ?? '').toString();

    if (newType == ListingType.item) newPeriod = null;
    if (newType != ListingType.item) newItemCat = null;

    final city = (f['city'] ?? '').toString();
    final district = (f['district'] ?? '').toString();

    setState(() {
      _type = newType;
      _period = newPeriod;
      _itemCategory = newItemCat;

      _cityCtrl.text = city;
      _districtCtrl.text = district;
      _qCtrl.text = q;

      _selectedCityId = null;
      _selectedDistrictId = null;
    });

    await _ensureCitiesLoaded();
    await _loadCities(); // text->id eşleşsin
    await _load();

    if (!mounted) return;
    _snack('Kayıtlı arama uygulandı ✅');
  }

  // ✅ ARAMAYI KAYDET (DB'ye)
  Future<void> _saveSearch() async {
    final user = _sb.auth.currentUser;
    if (user == null) {
      _snack('Önce giriş yapmalısın.');
      return;
    }

    final city = _clean(_cityCtrl.text);
    final district = _clean(_districtCtrl.text);
    final q = _clean(_qCtrl.text);

    final typeLabel = _type?.label ?? 'Hepsi';

    final periodOrCatLabel = _isItemTypeSelected
        ? (_itemCategory?.label ?? 'Hepsi')
        : (_period?.label ?? 'Hepsi');

    final suggestedName = _isItemTypeSelected
        ? 'Tür: $typeLabel, Kategori: $periodOrCatLabel'
        : 'Tür: $typeLabel, Periyot: $periodOrCatLabel';

    final nameCtrl = TextEditingController(text: suggestedName);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Aramayı Kaydet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kayıt adı',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _filtersSummary({
                  'type': _type?.name,
                  'period': _isItemTypeSelected ? null : _period?.name,
                  'item_category': _isItemTypeSelected
                      ? _itemCategory?.db
                      : null,
                  'city': city,
                  'district': district,
                  'q': q,
                }),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final filters = <String, dynamic>{
      'type': _type?.name,
      'period': _isItemTypeSelected ? null : _period?.name,
      'item_category': _isItemTypeSelected ? _itemCategory?.db : null,
      'city': city,
      'district': district,
      'q': q,
    };

    try {
      await _savedSearchService.create(
        name: nameCtrl.text.trim(),
        filters: filters,
      );
      if (!mounted) return;
      _snack('Arama kaydedildi ✅');
    } catch (e) {
      if (!mounted) return;
      _snack('Kaydedilemedi: $e');
    }
  }

  // ---------------------- HELPERS ----------------------

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool?> _confirm({required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet'),
          ),
        ],
      ),
    );
  }

  String _filtersSummary(Map<String, dynamic> f) {
    ListingType? t;
    PricePeriod? p;
    ItemCategory? ic;

    final typeStr = (f['type'] ?? '').toString().trim();
    if (typeStr.isNotEmpty) {
      try {
        t = ListingType.values.byName(typeStr);
      } catch (_) {}
    }

    final itemCatStr = (f['item_category'] ?? '').toString().trim();
    if (itemCatStr.isNotEmpty) ic = ItemCategoryX.fromDb(itemCatStr);

    final periodStr = (f['period'] ?? '').toString().trim();
    if (periodStr.isNotEmpty) {
      try {
        p = PricePeriod.values.byName(periodStr);
      } catch (_) {}
    }

    final city = _clean((f['city'] ?? '').toString());
    final district = _clean((f['district'] ?? '').toString());
    final q = _clean((f['q'] ?? '').toString());

    final typeLabel = t?.label ?? 'Hepsi';
    final loc = [
      if (city.isNotEmpty) city,
      if (district.isNotEmpty) district,
    ].join(' / ');

    final qPart = q.isEmpty ? '' : ' • "$q"';

    if (t == ListingType.item) {
      final catLabel = ic?.label ?? 'Hepsi';
      return 'Tür: $typeLabel • Kategori: $catLabel • ${loc.isEmpty ? "-" : loc}$qPart';
    } else {
      final periodLabel = p?.label ?? 'Hepsi';
      return 'Tür: $typeLabel • Periyot: $periodLabel • ${loc.isEmpty ? "-" : loc}$qPart';
    }
  }

  String _clean(String s) {
    var x = s.trim();
    while (x.endsWith('.') || x.endsWith(',') || x.endsWith('-')) {
      x = x.substring(0, x.length - 1).trim();
    }
    return x;
  }

  // ✅ ÜSTTE AKTİF FİLTRE CHIP
  String get _activeFilterChipText {
    final typeLabel = _type?.label ?? 'Hepsi';
    final city = _clean(_cityCtrl.text);
    final district = _clean(_districtCtrl.text);
    final loc = [
      if (city.isNotEmpty) city,
      if (district.isNotEmpty) district,
    ].join(' / ');

    if (_isItemTypeSelected) {
      final cat = _itemCategory?.label ?? 'Hepsi';
      return '🔎 Filtre: $typeLabel • $cat${loc.isNotEmpty ? " • $loc" : ""}';
    } else {
      final per = _period?.label ?? 'Hepsi';
      return '🔎 Filtre: $typeLabel • $per${loc.isNotEmpty ? " • $loc" : ""}';
    }
  }

  String _fmtPrice(Map<String, dynamic> it) {
    final price = it['price'];
    final period = (it['price_period'] ?? '').toString();
    final currency = (it['currency'] ?? 'TRY').toString();

    if (price == null) return 'Fiyat yok';

    final numPrice = (price is num)
        ? price.toDouble()
        : double.tryParse('$price');
    if (numPrice == null) return 'Fiyat yok';

    final cur = currency.toUpperCase() == 'TRY' ? '₺' : currency.toUpperCase();

    String periodLabel = period;
    try {
      periodLabel = pricePeriodFromDb(period).label;
    } catch (_) {}

    final priceStr = (numPrice % 1 == 0)
        ? numPrice.toStringAsFixed(0)
        : numPrice.toStringAsFixed(2);

    return '$cur$priceStr / $periodLabel';
  }

  String _fmtType(Map<String, dynamic> it) {
    final typeStr = (it['type'] ?? '').toString();
    try {
      return listingTypeFromDb(typeStr).label;
    } catch (_) {
      return typeStr.isEmpty ? '-' : typeStr;
    }
  }

  String _fmtLocation(Map<String, dynamic> it) {
    final city = _clean((it['city'] ?? '').toString());
    final district = _clean((it['district'] ?? '').toString());
    final loc = [
      if (city.isNotEmpty) city,
      if (district.isNotEmpty) district,
    ].join(' / ');
    return loc;
  }

  bool _isUrgent(Map<String, dynamic> it) => it['is_urgent'] == true;

  Future<String?> _getFirstImageSignedUrl(Map<String, dynamic> it) async {
    try {
      final paths = _service.extractImagePaths(it);
      if (paths.isEmpty) return null;
      return await _service.createSignedListingImageUrl(path: paths.first);
    } catch (_) {
      return null;
    }
  }

  // ✅ küçük chip (kompakt)
  Widget _miniChip(String text, {Color? bg, Color? fg}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: fg ?? theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ✅ SABİT ARAMA + FİLTRE
  Widget _topSearchAndFilterBar() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _openFilterSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _activeFilterChipText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _qCtrl,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _load(),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Ara (başlık / açıklama / tür)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            suffixIcon: _clean(_qCtrl.text).isEmpty
                ? null
                : IconButton(
                    tooltip: 'Temizle',
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      setState(() => _qCtrl.text = '');
                      await _load();
                    },
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // ---------------------- UI: CARD (KOMPAKT) ----------------------

  Widget _listingCard(Map<String, dynamic> it) {
    final id = (it['id'] ?? '').toString();
    final firstUrl = _firstImageUrlCache[id];

    final title = _clean((it['title'] ?? '').toString());
    final urgent = _isUrgent(it);

    final typeLabel = _fmtType(it);
    final priceLabel = _fmtPrice(it);
    final loc = _fmtLocation(it);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        final copy = Map<String, dynamic>.from(it);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ListingDetailPage(listing: copy)),
        );
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: (firstUrl == null || firstUrl.trim().isEmpty)
                            ? Container(
                                color: Colors.grey.shade100,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.image_outlined,
                                  color: Colors.grey.shade500,
                                  size: 30,
                                ),
                              )
                            : Image.network(
                                firstUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: Colors.grey.shade100,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.grey.shade500,
                                    size: 30,
                                  ),
                                ),
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: Colors.grey.shade100,
                                    alignment: Alignment.center,
                                    child: const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      Positioned(left: 6, top: 6, child: _boostStarBadge(it)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? '(Başlıksız ilan)' : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _miniChip(typeLabel),
                        _miniChip(priceLabel),
                        _miniChip(loc.isNotEmpty ? loc : 'Konum yok'),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------- UI ----------------------

  @override
  Widget build(BuildContext context) {
    const maxW = 560.0;

    final dynamicTitle = (_type == null)
        ? 'İlanlar'
        : '${_type!.label} İlanları';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        title: Text(dynamicTitle),
        actions: [
          IconButton(
            tooltip: 'Filtrele',
            icon: const Icon(Icons.tune),
            onPressed: _openFilterSheet,
          ),
          PopupMenuButton<SortOption>(
            tooltip: 'Sırala',
            icon: const Icon(Icons.sort),
            onSelected: _onSortSelected,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: SortOption.newest,
                child: Text('Yeni → Eski'),
              ),
              PopupMenuItem(
                value: SortOption.priceAsc,
                child: Text('Fiyat (Artan)'),
              ),
              PopupMenuItem(
                value: SortOption.priceDesc,
                child: Text('Fiyat (Azalan)'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Kayıtlı aramalar',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: _openSavedSearchesSheet,
          ),
          IconButton(
            tooltip: 'Aramayı kaydet',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _saveSearch,
          ),
          IconButton(
            tooltip: 'Yenile',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxW),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _topSearchAndFilterBar(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? ListView(
                      children: const [
                        SizedBox(height: 220),
                        Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : (_error != null)
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                'Hata: $_error',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _load,
                                child: const Text('Tekrar dene'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, c) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: [
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: maxW,
                                ),
                                child: _items.isEmpty
                                    ? Column(
                                        children: const [
                                          SizedBox(height: 120),
                                          Icon(
                                            Icons.inbox_outlined,
                                            size: 48,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(height: 10),
                                          Text('Henüz ilan yok.'),
                                        ],
                                      )
                                    : Column(
                                        children: _items
                                            .map(_listingCard)
                                            .toList(),
                                      ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// ✅ Saved Searches (Supabase)
// ======================================================

class SavedSearch {
  final String id;
  final String? name;
  final Map<String, dynamic> filters;
  final DateTime? createdAt;

  SavedSearch({
    required this.id,
    required this.filters,
    this.name,
    this.createdAt,
  });

  factory SavedSearch.fromMap(Map<String, dynamic> m) {
    DateTime? dt;
    try {
      final s = (m['created_at'] ?? '').toString();
      if (s.isNotEmpty) dt = DateTime.tryParse(s);
    } catch (_) {}

    final rawFilters = m['filters'];
    final filters = (rawFilters is Map)
        ? Map<String, dynamic>.from(rawFilters as Map)
        : <String, dynamic>{};

    final nameRaw = m['name'];
    final nm = (nameRaw == null) ? null : nameRaw.toString().trim();

    return SavedSearch(
      id: (m['id'] ?? '').toString(),
      name: (nm == null || nm.isEmpty) ? null : nm,
      filters: filters,
      createdAt: dt,
    );
  }
}

class SavedSearchesService {
  final SupabaseClient _sb = Supabase.instance.client;

  Future<void> create({
    required String name,
    required Map<String, dynamic> filters,
  }) async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _sb.from('saved_searches').insert({
      'user_id': user.id,
      'name': name.trim().isEmpty ? null : name.trim(),
      'filters': filters,
    });
  }

  Future<List<SavedSearch>> fetch() async {
    final user = _sb.auth.currentUser;
    if (user == null) return [];

    final res = await _sb
        .from('saved_searches')
        .select('id,name,filters,created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (res as List)
        .map((e) => SavedSearch.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> delete(String id) async {
    await _sb.from('saved_searches').delete().eq('id', id);
  }
}
