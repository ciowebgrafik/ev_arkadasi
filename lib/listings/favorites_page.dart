// ✅ APP UI
import 'package:ev_arkadasi/core/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listing_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  static const Color kTurkuaz = AppUI.kTurkuaz;

  final supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _listings = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _listings = [];
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await supabase
          .from('favorites')
          .select('created_at, listing:listing_id(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final rows = (res as List).cast<Map<String, dynamic>>();

      final list = <Map<String, dynamic>>[];
      for (final r in rows) {
        final listing = r['listing'];
        if (listing is Map) {
          list.add(Map<String, dynamic>.from(listing as Map));
        }
      }

      if (!mounted) return;
      setState(() {
        _listings = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            'Favoriler okunamadı.\nMuhtemelen favorites.listing_id → listings.id FK yok.\n\nHata: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openDetail(Map<String, dynamic> listing) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ListingDetailPage(listing: listing)),
    );
  }

  String _clean(dynamic s) => (s ?? '').toString().trim();

  String _fmtPrice(Map<String, dynamic> it) {
    final price = it['price'];
    final currency = (it['currency'] ?? 'TRY').toString();
    if (price == null) return 'Fiyat yok';

    final numPrice = (price is num)
        ? price.toDouble()
        : double.tryParse(price.toString().replaceAll(',', '.'));
    if (numPrice == null) return 'Fiyat yok';

    final cur = currency.toUpperCase() == 'TRY' ? '₺' : currency.toUpperCase();
    final s = (numPrice % 1 == 0)
        ? numPrice.toStringAsFixed(0)
        : numPrice.toStringAsFixed(2);
    return '$cur$s';
  }

  Widget _centerMsg(String text) {
    return ListView(
      padding: EdgeInsets.all(AppUI.g16),
      children: [
        SizedBox(height: AppUI.g140),
        Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.70),
              fontWeight: FontWeight.w600,
              fontSize: AppUI.fs14,
            ),
          ),
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
        title: const Text('Favoriler'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadFavorites,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFavorites,
        child: _loading
            ? ListView(
                children: [
                  SizedBox(height: AppUI.g220),
                  const Center(child: CircularProgressIndicator()),
                ],
              )
            : (_error != null)
            ? ListView(
                padding: EdgeInsets.all(AppUI.g16),
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : (_listings.isEmpty)
            ? _centerMsg(
                'Favoriler boş 🙂\nBir ilanı favoriye ekleyince burada görünecek.',
              )
            : ListView.separated(
                padding: EdgeInsets.all(AppUI.g12),
                itemCount: _listings.length,
                separatorBuilder: (_, _) => SizedBox(height: AppUI.g10),
                itemBuilder: (context, i) {
                  final it = _listings[i];

                  final title = _clean(it['title']);
                  final city = _clean(it['city']);
                  final district = _clean(it['district']);

                  final location = [
                    if (city.isNotEmpty) city,
                    if (district.isNotEmpty) district,
                  ].join(' / ');

                  final priceText = _fmtPrice(it);

                  return InkWell(
                    borderRadius: BorderRadius.circular(AppUI.r14),
                    onTap: () => _openDetail(it),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppUI.r14),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(AppUI.g12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(AppUI.r12),
                              ),
                              child: const Icon(
                                Icons.favorite,
                                color: Colors.redAccent,
                              ),
                            ),
                            SizedBox(width: AppUI.g12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title.isEmpty ? '(Başlıksız)' : title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: AppUI.fs14,
                                    ),
                                  ),
                                  SizedBox(height: AppUI.g4),
                                  Text(
                                    location.isEmpty
                                        ? 'Konum belirtilmemiş'
                                        : location,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: AppUI.fs12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: AppUI.g10),
                            Text(
                              priceText,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: AppUI.fs14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
