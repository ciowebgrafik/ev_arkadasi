import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listing_create_page.dart';
import 'listing_detail_page.dart';
import 'listing_enums.dart';
import 'listings_service.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  static const Color kTurkuaz = Color(0xFF00B8D4);

  final SupabaseClient _sb = Supabase.instance.client;
  final ListingsService _service = ListingsService();

  late final TabController _tab;

  bool _checkingAdmin = true;
  bool _isAdmin = false;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _rejected = [];
  List<Map<String, dynamic>> _published = [];

  // action loading by listingId
  final Map<String, bool> _actionLoading = {};

  // first photo cache
  final Map<String, String?> _firstImageUrlCache = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _init();
  }

  Future<void> _init() async {
    await _checkAdmin();
    if (!mounted) return;
    if (_isAdmin) {
      await _load();
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  bool _isLoadingId(String id) => _actionLoading[id] == true;

  // ===================== ADMIN CHECK =====================
  Future<void> _checkAdmin() async {
    setState(() {
      _checkingAdmin = true;
      _isAdmin = false;
    });

    try {
      final user = _sb.auth.currentUser;
      if (user == null) {
        _isAdmin = false;
        return;
      }

      final p = await _sb
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .maybeSingle();

      final isAdmin = (p?['is_admin'] == true);

      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
      });
    } catch (e) {
      if (!mounted) return;
      _error = 'Admin kontrolü başarısız: $e';
    } finally {
      if (mounted) {
        setState(() => _checkingAdmin = false);
      }
    }
  }

  // ===================== LOAD LISTINGS =====================
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _sb
          .from('listings')
          .select('*')
          .inFilter('status', ['pending', 'rejected', 'published'])
          .order('created_at', ascending: false);

      final all = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      _pending = all.where((x) => (x['status'] ?? '') == 'pending').toList();
      _rejected = all.where((x) => (x['status'] ?? '') == 'rejected').toList();
      _published = all
          .where((x) => (x['status'] ?? '') == 'published')
          .toList();

      // image cache
      _firstImageUrlCache.clear();
      for (final it in all) {
        final id = (it['id'] ?? '').toString();
        if (id.isEmpty) continue;
        _firstImageUrlCache[id] = await _service.signedFirstImageUrlFromListing(
          it,
        );
      }

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===================== DIALOGS =====================
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

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===================== HELPERS =====================
  ListingType _parseType(dynamic v) {
    final s = (v ?? '').toString().trim();
    return listingTypeFromDb(s);
  }

  String _clean(String s) {
    var x = s.trim();
    while (x.endsWith('.') || x.endsWith(',') || x.endsWith('-')) {
      x = x.substring(0, x.length - 1).trim();
    }
    return x;
  }

  String _fmtLocation(Map<String, dynamic> it) {
    final city = _clean((it['city'] ?? '').toString());
    final district = _clean((it['district'] ?? '').toString());
    return [
      if (city.isNotEmpty) city,
      if (district.isNotEmpty) district,
    ].join(' / ');
  }

  Map<String, dynamic> _detailsOf(Map<String, dynamic> item) {
    final d = item['details'];
    if (d is Map<String, dynamic>) return Map<String, dynamic>.from(d);
    if (d is Map)
      return Map<String, dynamic>.from(d.map((k, v) => MapEntry('$k', v)));
    return {};
  }

  // ===================== ADMIN ACTIONS =====================
  Future<void> _approve(String id) async {
    if (_isLoadingId(id)) return;

    final ok = await _confirm(
      title: 'Onayla?',
      message: 'Bu ilan yayına alınacak (published).',
      confirmText: 'Onayla',
    );
    if (ok != true) return;

    setState(() => _actionLoading[id] = true);

    try {
      await _sb
          .from('listings')
          .update({
            'status': 'published',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      if (!mounted) return;
      _snack('Onaylandı ✅');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Hata: $e');
    } finally {
      if (mounted) setState(() => _actionLoading[id] = false);
    }
  }

  Future<void> _reject(Map<String, dynamic> it) async {
    final id = (it['id'] ?? '').toString();
    if (id.isEmpty) return;
    if (_isLoadingId(id)) return;

    final reasonCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reddet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('İstersen kısa bir not yaz:'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Red nedeni (opsiyonel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _actionLoading[id] = true);

    try {
      final reason = reasonCtrl.text.trim();

      // ✅ details MERGE (ezme yok)
      final oldDetails = _detailsOf(it);
      final newDetails = <String, dynamic>{
        ...oldDetails,
        if (reason.isNotEmpty) 'admin_note': reason,
        'rejected_at': DateTime.now().toIso8601String(),
      };

      await _sb
          .from('listings')
          .update({
            'status': 'rejected',
            'details': newDetails,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      if (!mounted) return;
      _snack('Reddedildi ❌');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Hata: $e');
    } finally {
      if (mounted) setState(() => _actionLoading[id] = false);
    }
  }

  Future<void> _sendBackToPending(String id) async {
    if (_isLoadingId(id)) return;

    final ok = await _confirm(
      title: 'Tekrar onaya al?',
      message: 'Bu ilan tekrar pending yapılacak.',
      confirmText: 'Pending yap',
    );
    if (ok != true) return;

    setState(() => _actionLoading[id] = true);

    try {
      await _sb
          .from('listings')
          .update({
            'status': 'pending',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      if (!mounted) return;
      _snack('Pending ✅');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Hata: $e');
    } finally {
      if (mounted) setState(() => _actionLoading[id] = false);
    }
  }

  Future<void> _openDetail(Map<String, dynamic> it) async {
    final copy = Map<String, dynamic>.from(it);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ListingDetailPage(listing: copy)),
    );
  }

  Future<void> _openEdit(Map<String, dynamic> it) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ListingCreatePage(editListing: it)),
    );
    if (changed == true) await _load();
  }

  // ===================== UI HELPERS =====================
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

  Widget _cardItem(Map<String, dynamic> it) {
    final id = (it['id'] ?? '').toString();
    final title = _clean((it['title'] ?? '').toString());
    final status = (it['status'] ?? '').toString().trim();
    final type = _parseType(it['type']);
    final loc = _fmtLocation(it);
    final url = _firstImageUrlCache[id];

    final isPending = status == 'pending';
    final isRejected = status == 'rejected';
    final isPublished = status == 'published';

    final acting = _isLoadingId(id);

    Color statusBg() {
      if (isPending) return Colors.amber.shade50;
      if (isRejected) return Colors.red.shade50;
      if (isPublished) return Colors.green.shade50;
      return Colors.blue.shade50;
    }

    Color statusFg() {
      if (isPending) return Colors.amber.shade900;
      if (isRejected) return Colors.red.shade800;
      if (isPublished) return Colors.green.shade800;
      return Colors.blue.shade800;
    }

    String statusLabel() {
      if (isPending) return 'PENDING';
      if (isRejected) return 'REJECTED';
      if (isPublished) return 'PUBLISHED';
      return status;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
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
                    child: (url == null || url.isEmpty)
                        ? Container(
                            color: Colors.grey.shade100,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.image_outlined,
                              color: Colors.grey.shade500,
                            ),
                          )
                        : Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.grey.shade100,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.grey.shade500,
                              ),
                            ),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
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
                              color: statusBg(),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusLabel(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: statusFg(),
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openDetail(it),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Detay'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openEdit(it),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ACTIONS
            if (isPending) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: acting ? null : () => _approve(id),
                      icon: acting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Onayla'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: acting ? null : () => _reject(it),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Reddet'),
                    ),
                  ),
                ],
              ),
            ] else if (isRejected) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTurkuaz,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: acting ? null : () => _sendBackToPending(id),
                  icon: acting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restart_alt),
                  label: const Text('Tekrar Pending'),
                ),
              ),
            ] else if (isPublished) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: acting ? null : () => _sendBackToPending(id),
                  icon: const Icon(Icons.undo),
                  label: const Text('Pending’e geri al'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _listOf(List<Map<String, dynamic>> items) {
    if (_checkingAdmin) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isAdmin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 42, color: Colors.grey),
              const SizedBox(height: 10),
              const Text(
                'Bu sayfa sadece admin içindir.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Eğer admin olman gerekiyorsa, Supabase profiles tablosunda kendi kullanıcı kaydında is_admin=true yap.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Hata: $_error'));
    }
    if (items.isEmpty) {
      return const Center(child: Text('Boş.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _cardItem(items[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Rejected'),
            Tab(text: 'Published'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _isAdmin ? _load : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [_listOf(_pending), _listOf(_rejected), _listOf(_published)],
      ),
    );
  }
}
