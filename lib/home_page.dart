import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Sende hangi dosya isimleri ise burayı ona göre düzelt
import 'auth_gate.dart';
import 'profil_sayfasi.dart';

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
      final url =
      await supabase.storage.from('avatars').createSignedUrl(path, 60 * 60);

      // cache bust (foto güncelleince anında değişsin)
      final bust = DateTime.now().millisecondsSinceEpoch;
      return '$url${url.contains('?') ? '&' : '?'}cb=$bust';
    } catch (_) {
      return null;
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
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

  // Drawer şimdilik placeholder (İlanlar menüsü buradan açılacak)
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
              leading: const Icon(Icons.list_alt_outlined),
              title: const Text('İlanlar'),
              onTap: () {
                Navigator.pop(context);
                _notReady('İlanlar');
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Mesajlar'),
              onTap: () {
                Navigator.pop(context);
                _notReady('Mesajlar');
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Çıkış', style: TextStyle(color: Colors.redAccent)),
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
    final user = supabase.auth.currentUser;

    return Scaffold(
      drawer: _buildDrawer(),

      // ✅ ÜST BAR: sol menü - orta başlık - sağda mesaj/profil/çıkış
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.indigo),
        ),

        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'İlanlar',
            icon: const Icon(Icons.list_alt_outlined,
                size: 22, color: Colors.black87),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),

        title: const Text(
          'Ev arkadaşım',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Mesajlar',
            icon: const Icon(Icons.chat_bubble_outline,
                size: 20, color: Colors.black87),
            onPressed: () => _notReady('Mesajlar'),
          ),

          // 👤 Profil (foto)
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilSayfasi()),
              );
              _loadMe(); // geri dönünce yenile
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: Colors.grey.shade200,
                backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person,
                    size: 16, color: Colors.grey)
                    : null,
              ),
            ),
          ),

          IconButton(
            tooltip: 'Çıkış',
            icon: const Icon(Icons.logout,
                size: 20, color: Colors.redAccent),
            onPressed: _signOut,
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadMe,
        child: _loading
            ? ListView(
          // RefreshIndicator çalışsın diye ListView bıraktık
          children: const [
            SizedBox(height: 220),
            Center(child: CircularProgressIndicator()),
          ],
        )
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ✅ Kullanıcı kartı (Gmail yok, sadece isim)
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
                        ? const Icon(Icons.person,
                        color: Colors.grey, size: 20)
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

            // İstersen burada içeriği büyütürüz (ilan listesi, mesajlar vs.)
            // Şimdilik boş bırakıyorum.
          ],
        ),
      ),
    );
  }
}