import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_gate.dart';
import '../profile/profil_sayfasi.dart';
// ✅ Favoriler sayfası (dosya yolun farklıysa düzelt)
import 'favorites_page.dart';
// ✅ İlan sayfaları
import 'listing_create_page.dart';
import 'listing_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

      // cache bust (foto güncelleince anında değişsin)
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

    // ✅ Geri dönünce yenile
    if (!mounted) return;
    await _loadMe();
  }

  Future<void> _openListings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ListingListPage()),
    );
  }

  Future<void> _openCreateListing() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ListingCreatePage()),
    );

    if (!mounted) return;

    if (changed == true) {
      _snack('İlan kaydedildi ✅');
      await _openListings();
    }
  }

  // ✅ Favoriler sayfasını aç
  Future<void> _openFavorites() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesPage()),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const ListTile(
              title: Text(
                'İlanlar Menüsü',
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
              title: const Text('İlan Ekle'),
              onTap: () {
                Navigator.pop(context);
                Future.microtask(_openCreateListing);
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt_outlined),
              title: const Text('İlanlar'),
              onTap: () {
                Navigator.pop(context);
                Future.microtask(_openListings);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.indigo),
        ),

        // ✅ Drawer butonu
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menü',
            icon: const Icon(Icons.menu, size: 22, color: Colors.black87),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),

        // ✅ Başlık (taşmasın diye ellipsis)
        title: const Text(
          'Ev Arkadaşım',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),

        // ✅ avatar + 3 nokta menü
        actions: [
          GestureDetector(
            onTap: _openProfile,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person, size: 18, color: Colors.grey)
                    : null,
              ),
            ),
          ),

          // ✅ PROFESYONEL MENÜ (Favoriler aktif)
          PopupMenuButton<String>(
            tooltip: 'Menü',
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (v) async {
              if (v == 'favorites') {
                await _openFavorites(); // ✅ Favoriler açılır
              } else if (v == 'my_listings') {
                _notReady('İlanlarım');
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
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
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
                            displayName.isNotEmpty ? displayName : 'Kullanıcı',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Aşağı çekerek yenileyebilirsin.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }
}
