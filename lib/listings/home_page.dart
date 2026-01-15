import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/widgets/app_ui.dart';
import '../features/auth/auth_gate.dart';
import '../features/profile/profil_sayfasi.dart';
import 'admin_panel_page.dart';
import 'favorites_page.dart';
import 'listing_create_page.dart';
import 'listing_enums.dart';
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

  // ✅ Admin kontrol
  bool _isAdmin = false;
  bool _loadingAdmin = true;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (mounted) {
      setState(() {
        _loading = true;
        _loadingAdmin = true;
      });
    }

    try {
      final data = await supabase
          .from('profiles')
          .select('full_name, avatar_path, is_admin')
          .eq('id', user.id)
          .maybeSingle();

      final name = (data?['full_name'] ?? '').toString().trim();
      final path = (data?['avatar_path'] ?? '').toString().trim();

      displayName = name.isNotEmpty ? name : 'Kullanıcı';
      avatarPath = path;

      _isAdmin = data?['is_admin'] == true;

      avatarUrl = await _createSignedAvatarUrl(path);
    } catch (e) {
      if (!mounted) return;
      _snack('Profil okunamadı: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingAdmin = false;
        });
      }
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  // ================= NAVIGATION =================

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
      MaterialPageRoute(
        builder: (_) =>
            const ListingListPage(initialType: ListingType.roommate),
      ),
    );
  }

  Future<void> _openItemListings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ListingListPage(initialType: ListingType.item),
      ),
    );
  }

  Future<void> _openMovingServices() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ListingListPage(initialType: ListingType.transport),
      ),
    );
  }

  Future<void> _openRepair() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ListingListPage(initialType: ListingType.repair),
      ),
    );
  }

  Future<void> _openNearbyTrades() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ListingListPage(initialType: ListingType.local),
      ),
    );
  }

  Future<void> _openCleaning() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ListingListPage(initialType: ListingType.cleaning),
      ),
    );
  }

  Future<void> _openPetAdoption() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ListingListPage(initialType: ListingType.pet),
      ),
    );
  }

  Future<void> _openDailyJobs() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ListingListPage(initialType: ListingType.daily_job),
      ),
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

  // ✅ Admin Panel aç
  Future<void> _openAdminPanel() async {
    if (_loadingAdmin) {
      _snack('Admin kontrol ediliyor...');
      return;
    }
    if (!_isAdmin) {
      _snack('Bu sayfaya erişimin yok.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminPanelPage()),
    );

    if (!mounted) return;
    await _loadMe();
  }

  // ================= DRAWER =================

  Drawer _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: Text(
                'Menü',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppUI.fs(context, 16),
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(
                'Ana Sayfa',
                style: TextStyle(fontSize: AppUI.fs(context, 14)),
              ),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: Text(
                'İlan Yayınla',
                style: TextStyle(fontSize: AppUI.fs(context, 14)),
              ),
              onTap: () {
                Navigator.pop(context);
                Future.microtask(_openCreateListing);
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt_outlined),
              title: Text(
                'Tüm İlanlar',
                style: TextStyle(fontSize: AppUI.fs(context, 14)),
              ),
              onTap: () {
                Navigator.pop(context);
                Future.microtask(_openListingsAll);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_outlined),
              title: Text(
                'Ev Arkadaşı İlanları',
                style: TextStyle(fontSize: AppUI.fs(context, 14)),
              ),
              onTap: () {
                Navigator.pop(context);
                Future.microtask(_openRoommateListings);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chair_alt_outlined),
              title: Text(
                'Ev Eşyaları İlanları',
                style: TextStyle(fontSize: AppUI.fs(context, 14)),
              ),
              onTap: () {
                Navigator.pop(context);
                Future.microtask(_openItemListings);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(
                'İlanlarım',
                style: TextStyle(fontSize: AppUI.fs(context, 14)),
              ),
              onTap: () {
                Navigator.pop(context);
                Future.microtask(_openMyListings);
              },
            ),
            if (!_loadingAdmin && _isAdmin) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(
                  'Admin Panel',
                  style: TextStyle(fontSize: AppUI.fs(context, 14)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Future.microtask(_openAdminPanel);
                },
              ),
            ],
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: Text(
                'Çıkış',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: AppUI.fs(context, 14),
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: _signOut,
            ),
            SizedBox(height: AppUI.gap(context, 8)),
          ],
        ),
      ),
    );
  }

  // ================= UI HELPERS =================

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
        height: AppUI.gap(context, 56),
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            side: const BorderSide(color: kTurkuaz, width: 1.6),
            shape: const StadiumBorder(),
            padding: EdgeInsets.symmetric(horizontal: AppUI.gap(context, 18)),
          ),
          child: Row(
            children: [
              Icon(icon, size: AppUI.fs(context, 20), color: kTurkuaz),
              SizedBox(width: AppUI.gap(context, 10)),
              Expanded(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppUI.fs(context, 16),
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
        height: AppUI.gap(context, 110),
        decoration: const ShapeDecoration(
          color: Colors.white,
          shape: StadiumBorder(side: BorderSide(color: kTurkuaz, width: 1.6)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Google Reklamları',
                style: TextStyle(
                  fontSize: AppUI.fs(context, 16),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: AppUI.gap(context, 6)),
              Text(
                'Reklam alanı (Banner)',
                style: TextStyle(
                  fontSize: AppUI.fs(context, 12),
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= BUILD =================

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
        titleSpacing: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menü',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          'Ev Arkadaşım',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppUI.fs(context, 18),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _openProfile,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppUI.gap(context, 8)),
              child: CircleAvatar(
                radius: AppUI.r(context, 16),
                backgroundColor: Colors.white.withAlpha((0.25 * 255).round()),
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: avatarUrl == null
                    ? Icon(
                        Icons.person,
                        size: AppUI.fs(context, 18),
                        color: Colors.white,
                      )
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
              } else if (v == 'admin') {
                await _openAdminPanel();
              } else if (v == 'logout') {
                await _signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'favorites', child: Text('Favoriler')),
              const PopupMenuItem(
                value: 'my_listings',
                child: Text('İlanlarım'),
              ),
              if (!_loadingAdmin && _isAdmin) ...const [
                PopupMenuDivider(),
                PopupMenuItem(value: 'admin', child: Text('Admin Panel')),
              ],
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Çıkış')),
            ],
          ),
          SizedBox(width: AppUI.gap(context, 6)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMe,
        child: _loading
            ? ListView(
                children: [
                  SizedBox(height: AppUI.gap(context, 220)),
                  const Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                padding: EdgeInsets.only(
                  top: AppUI.gap(context, 16),
                  bottom: AppUI.gap(context, 16),
                ),
                children: [
                  SizedBox(height: AppUI.gap(context, 22)),

                  // ✅ Zigzag sıralama: 1) İlan Yayınla  2) Tüm İlanlar
                  _menuPill(
                    width: safeWidth,
                    alignRight: true,
                    text: 'İlan Yayınla',
                    icon: Icons.add_circle_outline,
                    onTap: _openCreateListing,
                  ),
                  SizedBox(height: AppUI.gap(context, 16)),
                  _menuPill(
                    width: safeWidth,
                    alignRight: false,
                    text: 'Tüm İlanlar',
                    icon: Icons.list_alt_outlined,
                    onTap: _openListingsAll,
                  ),
                  SizedBox(height: AppUI.gap(context, 16)),
                  _menuPill(
                    width: safeWidth,
                    alignRight: true,
                    text: 'Ev Arkadaşı İlanları',
                    icon: Icons.people_alt_outlined,
                    onTap: _openRoommateListings,
                  ),
                  SizedBox(height: AppUI.gap(context, 16)),
                  _menuPill(
                    width: safeWidth,
                    alignRight: false,
                    text: 'Ev Eşyaları İlanları',
                    icon: Icons.chair_alt_outlined,
                    onTap: _openItemListings,
                  ),

                  SizedBox(height: AppUI.gap(context, 16)),
                  _menuPill(
                    width: safeWidth,
                    alignRight: true,
                    text: 'Nakliye Hizmetleri',
                    icon: Icons.local_shipping_outlined,
                    onTap: _openMovingServices,
                  ),
                  SizedBox(height: AppUI.gap(context, 16)),
                  _menuPill(
                    width: safeWidth,
                    alignRight: false,
                    text: 'Dekorasyon / Onarım',
                    icon: Icons.handyman_outlined,
                    onTap: _openRepair,
                  ),
                  SizedBox(height: AppUI.gap(context, 16)),
                  _menuPill(
                    width: safeWidth,
                    alignRight: true,
                    text: 'Yakınımdaki Küçük Esnaf',
                    icon: Icons.storefront_outlined,
                    onTap: _openNearbyTrades,
                  ),
                  SizedBox(height: AppUI.gap(context, 16)),
                  _menuPill(
                    width: safeWidth,
                    alignRight: false,
                    text: 'Temizlik',
                    icon: Icons.cleaning_services_outlined,
                    onTap: _openCleaning,
                  ),
                  SizedBox(height: AppUI.gap(context, 16)),
                  _menuPill(
                    width: safeWidth,
                    alignRight: true,
                    text: 'Evcil Hayvan Sahiplendirme',
                    icon: Icons.pets_outlined,
                    onTap: _openPetAdoption,
                  ),
                  SizedBox(height: AppUI.gap(context, 16)),
                  _menuPill(
                    width: safeWidth,
                    alignRight: false,
                    text: 'Günlük İş',
                    icon: Icons.work_outline,
                    onTap: _openDailyJobs,
                  ),

                  SizedBox(height: AppUI.gap(context, 18)),
                  _adSlot(width: safeWidth, alignRight: false),
                  SizedBox(height: AppUI.gap(context, 18)),
                  Center(
                    child: Text(
                      'Aşağı çekerek yenileyebilirsin.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: AppUI.fs(context, 12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
