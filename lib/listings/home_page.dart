import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/auth_gate.dart';
import '../features/profile/profil_sayfasi.dart';
import 'favorites_page.dart';
import 'listing_create_page.dart';
import 'listing_list_page.dart';
import 'my_listings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color kTurkuaz = Color(0xFF00B8D4);
  final supabase = Supabase.instance.client;

  bool _loading = true;

  String displayName = '';
  String? avatarUrl; // signed url
  String avatarPath = '';

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      final data = await supabase
          .from('profiles')
          .select('full_name, avatar_path')
          .eq('id', user.id)
          .maybeSingle();

      final name = (data?['full_name'] ?? '').toString().trim();
      final path = (data?['avatar_path'] ?? '').toString().trim();

      displayName = name.isNotEmpty ? name : 'Kullanıcı';
      avatarPath = path;

      avatarUrl = await _createSignedAvatarUrl(path);
    } catch (e) {
      if (!mounted) return;
      _snack('Profil okunamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _createSignedAvatarUrl(String path) async {
    if (path.isEmpty) return null;

    try {
      final url = await supabase.storage
          .from('avatars')
          .createSignedUrl(path, 60 * 60);

      final bust = DateTime.now().millisecondsSinceEpoch;
      return '$url${url.contains('?') ? '&' : '?'}cb=$bust';
    } catch (_) {
      return null;
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _notReady(String title) {
    _snack('$title yakında 🙂');
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilSayfasi()),
    );

    if (!mounted) return;
    await _loadMe();
  }

  Future<void> _openCreateListing() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ListingCreatePage()),
    );

    if (!mounted) return;

    if (changed == true) {
      _snack('İlan kaydedildi ✅');
      await _openListingsAll();
    }
  }

  Future<void> _openListingsAll() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ListingListPage()),
    );
  }

  Future<void> _openRoommateListings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ListingListPage()),
    );
  }

  Future<void> _openItemListings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ListingListPage()),
    );
  }

  Future<void> _openFavorites() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesPage()),
    );
  }

  Future<void> _openMyListings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyListingsPage()),
    );
  }

  // ---- Yeni aksiyonlar (şimdilik "yakında") ----
  void _openFindBestRoommate() => _notReady('Bana Uygun Ev Arkadaşı Bul');

  void _openMovingServices() => _notReady('Nakliye Hizmetleri');

  void _openRepair() => _notReady('Dekorasyon / Onarım');

  void _openNearbyTrades() => _notReady('Yakınımdaki Küçük Esnaf');

  void _openCleaning() => _notReady('Temizlik');

  void _openPetAdoption() => _notReady('Evcil Hayvan Sahiplendirme');

  void _openDailyJobs() => _notReady('Günlük İş');

  Drawer _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const ListTile(
              title: Text(
                'Menü',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Ana Sayfa'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('İlan Yayınla'),
              onTap: () {
                Navigator.pop(context);
                Future.microtask(_openCreateListing);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_outlined),
              title: const Text('Ev Arkadaşı İlanları'),
              onTap: () {
                Navigator.pop(context);
                Future.microtask(_openRoommateListings);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chair_alt_outlined),
              title: const Text('Ev Eşyaları İlanları'),
              onTap: () {
                Navigator.pop(context);
                Future.microtask(_openItemListings);
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt_outlined),
              title: const Text('Tüm İlanlar'),
              onTap: () {
                Navigator.pop(context);
                Future.microtask(_openListingsAll);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('İlanlarım'),
              onTap: () {
                Navigator.pop(context);
                Future.microtask(_openMyListings);
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Çıkış',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: _signOut,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------------- UI ----------------

  Widget _menuPill({
    required double width,
    required bool alignRight,
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: SizedBox(
        width: width,
        height: 56,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            side: const BorderSide(color: kTurkuaz, width: 1.6),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: kTurkuaz),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adSlot({required double width, required bool alignRight}) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: width,
        height: 110,
        decoration: const ShapeDecoration(
          color: Colors.white,
          shape: StadiumBorder(side: BorderSide(color: kTurkuaz, width: 1.6)),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Google Reklamları',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 6),
              Text(
                'Reklam alanı (Banner)',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final w70 = screenW * 0.70;
    final safeWidth = w70.clamp(240.0, screenW);

    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menü',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Ev Arkadaşım',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          GestureDetector(
            onTap: _openProfile,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withAlpha((0.25 * 255).round()),
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person, size: 18, color: Colors.white)
                    : null,
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menü',
            icon: const Icon(Icons.more_vert),
            onSelected: (v) async {
              if (v == 'favorites') {
                await _openFavorites();
              } else if (v == 'my_listings') {
                await _openMyListings();
              } else if (v == 'saved_searches') {
                _notReady('Kayıtlı Aramalar');
              } else if (v == 'boost') {
                _notReady('Doping / Öne Çıkar');
              } else if (v == 'logout') {
                await _signOut();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'favorites', child: Text('Favoriler')),
              PopupMenuItem(value: 'my_listings', child: Text('İlanlarım')),
              PopupMenuItem(
                value: 'saved_searches',
                child: Text('Kayıtlı Aramalar'),
              ),
              PopupMenuItem(value: 'boost', child: Text('Doping / Öne Çıkar')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Çıkış')),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMe,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                children: [
                  // Profil kutusu
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl!)
                                : null,
                            child: avatarUrl == null
                                ? const Icon(
                                    Icons.person,
                                    color: Colors.grey,
                                    size: 20,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              displayName.isNotEmpty
                                  ? displayName
                                  : 'Kullanıcı',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ✅ SIRALAMA (notunla birebir)
                  _menuPill(
                    width: safeWidth,
                    alignRight: false,
                    text: 'İlan Yayınla',
                    icon: Icons.add_circle_outline,
                    onTap: _openCreateListing,
                  ),
                  const SizedBox(height: 16),

                  _menuPill(
                    width: safeWidth,
                    alignRight: true,
                    text: 'Ev Arkadaşı İlanları',
                    icon: Icons.people_alt_outlined,
                    onTap: _openRoommateListings,
                  ),
                  const SizedBox(height: 16),

                  _menuPill(
                    width: safeWidth,
                    alignRight: false,
                    text: 'Ev Eşyaları İlanları',
                    icon: Icons.chair_alt_outlined,
                    onTap: _openItemListings,
                  ),
                  const SizedBox(height: 16),

                  _menuPill(
                    width: safeWidth,
                    alignRight: true,
                    text: 'Bana Uygun Ev Arkadaşı Bul',
                    icon: Icons.search_outlined,
                    onTap: _openFindBestRoommate,
                  ),
                  const SizedBox(height: 16),

                  _menuPill(
                    width: safeWidth,
                    alignRight: false,
                    text: 'Nakliye Hizmetleri',
                    icon: Icons.local_shipping_outlined,
                    onTap: _openMovingServices,
                  ),
                  const SizedBox(height: 16),

                  _menuPill(
                    width: safeWidth,
                    alignRight: true,
                    text: 'Dekorasyon / Onarım',
                    icon: Icons.handyman_outlined,
                    onTap: _openRepair,
                  ),
                  const SizedBox(height: 16),

                  _menuPill(
                    width: safeWidth,
                    alignRight: false,
                    text: 'Yakınımdaki Küçük Esnaf',
                    icon: Icons.storefront_outlined,
                    onTap: _openNearbyTrades,
                  ),
                  const SizedBox(height: 16),

                  _menuPill(
                    width: safeWidth,
                    alignRight: true,
                    text: 'Temizlik',
                    icon: Icons.cleaning_services_outlined,
                    onTap: _openCleaning,
                  ),
                  const SizedBox(height: 16),

                  _menuPill(
                    width: safeWidth,
                    alignRight: false,
                    text: 'Evcil Hayvan Sahiplendirme',
                    icon: Icons.pets_outlined,
                    onTap: _openPetAdoption,
                  ),
                  const SizedBox(height: 16),

                  _menuPill(
                    width: safeWidth,
                    alignRight: true,
                    text: 'Günlük İş',
                    icon: Icons.work_outline,
                    onTap: _openDailyJobs,
                  ),

                  const SizedBox(height: 18),

                  // Reklam alanı
                  _adSlot(width: safeWidth, alignRight: false),

                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      'Aşağı çekerek yenileyebilirsin.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
