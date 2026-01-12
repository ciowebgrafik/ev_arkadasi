import 'package:flutter/material.dart';

import 'listing_create_page.dart';
import 'listing_enums.dart';
import 'listings_service.dart';

class MyListingsPage extends StatefulWidget {
  const MyListingsPage({super.key});

  @override
  State<MyListingsPage> createState() => _MyListingsPageState();
}

class _MyListingsPageState extends State<MyListingsPage> {
  static const Color kTurkuaz = Color(0xFF00B8D4);

  final _service = ListingsService();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _items = [];

  // listingId -> signed first image url
  final Map<String, String?> _firstImageUrlCache = {};

  // ✅ kaldırma loading: listingId -> bool
  final Map<String, bool> _removeLoadingById = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final res = await _service.fetchMyListings(limit: 200);

      // ✅ DEĞİŞİKLİK:
      // "İlanlarım" sayfasında KALDIRILAN (paused) ilanlar DA görünsün.
      // (artık filtrelemiyoruz)
      _items = List<Map<String, dynamic>>.from(res);

      // ✅ first image signed url cache
      _firstImageUrlCache.clear();
      for (final l in _items) {
        final id = (l['id'] ?? '').toString();
        final url = await _service.signedFirstImageUrlFromListing(l);
        _firstImageUrlCache[id] = url;
      }
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEdit(Map<String, dynamic> listing) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListingCreatePage(editListing: listing),
      ),
    );

    if (!mounted) return;
    if (changed == true) await _load();
  }

  Future<void> _republish(String listingId) async {
    try {
      await _service.republishListing(listingId);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tekrar yayınlandı ✅')));

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  // ✅ İLANI KALDIR (Service: status = paused)
  bool _isRemovedStatus(String status) {
    final s = status.toLowerCase().trim();
    return s == 'paused';
  }

  bool _isPublished(String status) {
    final s = status.toLowerCase().trim();
    return s == 'published';
  }

  Future<void> _removeListing(Map<String, dynamic> listing) async {
    final id = (listing['id'] ?? '').toString();
    if (id.isEmpty) return;

    final status = (listing['status'] ?? '').toString();

    if (_isRemovedStatus(status)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu ilan zaten kaldırılmış.')),
      );
      return;
    }

    // ✅ sadece yayında olan kaldırılabilsin
    if (!_isPublished(status)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sadece yayındaki ilan kaldırılabilir.')),
      );
      return;
    }

    if (_removeLoadingById[id] == true) return;

    final ok = await _confirm(
      title: 'İlan kaldırılsın mı?',
      message:
          'Bu ilan artık listelerde görünmez.\n\nDaha sonra istersen "Tekrar Yayınla" ile yeniden yayına alabilirsin.',
      confirmText: 'Kaldır',
      danger: true,
    );
    if (ok != true) return;

    setState(() => _removeLoadingById[id] = true);

    try {
      // ✅ Service: status=paused
      await _service.removeListing(listingId: id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İlan yayından kaldırıldı ✅')),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kaldırılamadı: $e')));
    } finally {
      if (mounted) setState(() => _removeLoadingById[id] = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    String confirmText = 'Evet',
    bool danger = false,
  }) {
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
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? Colors.red : null,
              foregroundColor: danger ? Colors.white : null,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String s) {
    final v = s.toLowerCase().trim();
    if (v == 'published') return 'Yayında';
    if (v == 'paused') return 'Kaldırıldı';
    return s;
  }

  Color _statusBg(String s) {
    final v = s.toLowerCase().trim();
    if (v == 'published') return Colors.green.shade50;
    if (v == 'paused') return Colors.red.shade50;
    return Colors.blue.shade50;
  }

  Color _statusFg(String s) {
    final v = s.toLowerCase().trim();
    if (v == 'published') return Colors.green.shade800;
    if (v == 'paused') return Colors.red.shade800;
    return Colors.blue.shade800;
  }

  ListingType _parseType(dynamic v) {
    final s = (v ?? '').toString().trim();
    return listingTypeFromDb(s);
  }

  // ======================================================
  // ✅ DOPING HELPERS (boost_end aktifse rozet)
  // ======================================================

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

  String _boostLabel(Map<String, dynamic> item) {
    final details = _detailsOf(item);
    final plan = (details['boost_plan'] ?? '').toString().toLowerCase().trim();

    switch (plan) {
      case 'bronze':
        return 'BRONZ';
      case 'silver':
        return 'GÜMÜŞ';
      case 'gold':
        return 'ALTIN';
    }

    final boosted = details['boosted'] == true;
    return boosted ? 'BRONZ' : '';
  }

  Color _boostColor(String label) {
    switch (label) {
      case 'ALTIN':
        return const Color(0xFFFFC107);
      case 'GÜMÜŞ':
        return const Color(0xFFB0BEC5);
      case 'BRONZ':
        return const Color(0xFFB87333);
      default:
        return const Color(0xFF00B8D4);
    }
  }

  Widget _boostBadge(Map<String, dynamic> item) {
    if (!_isBoostActive(item)) return const SizedBox.shrink();

    final label = _boostLabel(item);
    if (label.isEmpty) return const SizedBox.shrink();

    final bg = _boostColor(label);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x33000000),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ======================================================
  // UI
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        title: const Text('İlanlarım'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Hata: $_error'))
          : _items.isEmpty
          ? const Center(child: Text('Henüz ilanın yok.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final l = _items[i];
                  final id = (l['id'] ?? '').toString();
                  final title = (l['title'] ?? '').toString().trim();
                  final city = (l['city'] ?? '').toString().trim();
                  final district = (l['district'] ?? '').toString().trim();
                  final status = (l['status'] ?? '').toString().trim();

                  final type = _parseType(l['type']);
                  final url = _firstImageUrlCache[id];

                  final loc = [
                    if (city.isNotEmpty) city,
                    if (district.isNotEmpty) district,
                  ].join(' / ');

                  final removed = _isRemovedStatus(status); // paused
                  final published = _isPublished(status);
                  final removing = _removeLoadingById[id] == true;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Container(
                                          color: Colors.grey.shade200,
                                          child: (url != null && url.isNotEmpty)
                                              ? Image.network(
                                                  url,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (context, error, stack) {
                                                        return const Center(
                                                          child: Icon(
                                                            Icons
                                                                .broken_image_outlined,
                                                            color: Colors.grey,
                                                          ),
                                                        );
                                                      },
                                                )
                                              : const Center(
                                                  child: Icon(
                                                    Icons.image_outlined,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 6,
                                        top: 6,
                                        child: _boostBadge(l),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title.isEmpty ? '(Başlıksız)' : title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _chip(type.label),
                                        if (loc.isNotEmpty) _chip(loc),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _statusBg(status),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            _statusLabel(status),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _statusFg(status),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'ID: $id',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // ✅ Düzenle / Tekrar Yayınla
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _openEdit(l),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Düzenle'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kTurkuaz,
                                    foregroundColor: Colors.white,
                                  ),
                                  // ✅ DEĞİŞİKLİK:
                                  // "Tekrar Yayınla" sadece kaldırılmış (paused) iken aktif olsun.
                                  onPressed: removed
                                      ? () => _republish(id)
                                      : null,
                                  icon: const Icon(Icons.publish_outlined),
                                  label: const Text('Tekrar Yayınla'),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // ✅ İlanı Kaldır (sadece published iken aktif)
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: (!published || removed || removing)
                                  ? null
                                  : () => _removeListing(l),
                              icon: removing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.visibility_off_outlined),
                              label: Text(
                                removed ? 'Kaldırıldı' : 'İlanı Kaldır',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade200),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
