import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listing_detail_page.dart'; // sende dosya yolu farklıysa düzelt
// Eğer ListingDetailPage başka klasördeyse import path'i ona göre ayarla.

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  // favorites içinden gelen listing objeleri
  List<Map<String, dynamic>> _listings = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _listings = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ✅ En iyi yöntem: favorites -> listings join (FK varsa çalışır)
      // favorites.listing_id -> listings.id foreign key olmalı
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
          list.add(listing.cast<String, dynamic>());
        }
      }

      if (!mounted) return;
      setState(() {
        _listings = list;
        _loading = false;
      });
    } catch (e) {
      // ❗ Eğer FK yoksa join patlar -> aşağıdaki uyarıyı göstereceğiz
      if (!mounted) return;
      setState(() {
        _error =
            'Favoriler okunamadı. (Muhtemelen favorites.listing_id -> listings.id FK yok)\nHata: $e';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoriler'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loadFavorites,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFavorites,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : (_error != null)
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Çözüm: Supabase’da favorites.listing_id alanını listings.id alanına FOREIGN KEY yap.\n'
                    'Sonra bu sayfa otomatik çalışır.',
                  ),
                ],
              )
            : (_listings.isEmpty)
            ? ListView(
                children: const [
                  SizedBox(height: 140),
                  Center(
                    child: Text(
                      'Favoriler boş 🙂\nBir ilanı favoriye ekleyince burada görünecek.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _listings.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final it = _listings[i];
                  final title = (it['title'] ?? '(Başlıksız)').toString();
                  final city = (it['city'] ?? '').toString();
                  final district = (it['district'] ?? '').toString();
                  final location = [
                    if (city.isNotEmpty) city,
                    if (district.isNotEmpty) district,
                  ].join(' / ');

                  final price = it['price'];
                  final priceText = price == null ? 'Fiyat yok' : '₺$price';

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openDetail(it),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.favorite,
                                color: Colors.redAccent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    location.isEmpty
                                        ? 'Konum belirtilmemiş'
                                        : location,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              priceText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
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
