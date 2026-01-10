import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_page.dart'; // ✅ ChatPage(chatId, otherUserId, otherUserName, listingTitle)
import 'chat_service.dart'; // ✅ getOrCreateConversation
import 'listing_enums.dart';
import 'listing_preferences_section.dart';
import 'listing_rules_section.dart';
import 'listings_service.dart';

class ListingDetailPage extends StatefulWidget {
  final Map<String, dynamic> listing;

  const ListingDetailPage({super.key, required this.listing});

  @override
  State<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends State<ListingDetailPage> {
  static const Color kTurkuaz = Color(0xFF00B8D4);

  final _service = ListingsService();
  final _pageCtrl = PageController();

  // ✅ Chat service (YENİ)
  final _chatService = ChatService();

  int _index = 0;
  bool _loadingImages = true;
  String? _imgError;

  bool _isFav = false;
  bool _favLoading = true;

  // ✅ Chat loading
  bool _chatLoading = false;

  List<String> _paths = [];
  List<String> _signedUrls = [];

  // ✅ Şikayet (report)
  bool _reportLoading = false;
  final TextEditingController _reportTextCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadImages();
    _loadFavoriteStatus();
  }

  @override
  void didUpdateWidget(covariant ListingDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldId = (oldWidget.listing['id'] ?? '').toString();
    final newId = _listingId();

    if (oldId != newId) {
      _isFav = false;
      _favLoading = true;
      _index = 0;

      _reportLoading = false;
      _reportTextCtrl.clear();

      _chatLoading = false;

      _loadFavoriteStatus();
      _loadImages();
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _reportTextCtrl.dispose();
    super.dispose();
  }

  String _listingId() => (widget.listing['id'] ?? '').toString();

  // ---------------------- WhatsApp ----------------------

  String _normalizeTrPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    if (digits.startsWith('0') && digits.length == 11) {
      return '90${digits.substring(1)}';
    }
    if (digits.startsWith('90') && digits.length >= 12) {
      return digits;
    }
    if (digits.length == 10 && digits.startsWith('5')) {
      return '90$digits';
    }
    return digits;
  }

  bool _isValidWhatsappPhone(String raw) {
    final p = _normalizeTrPhone(raw);
    if (p.isEmpty) return false;

    if (!p.startsWith('90') || p.length != 12) return false;

    final local = p.substring(2);
    final allSame = local.split('').every((c) => c == local[0]);
    if (allSame) return false;

    return true;
  }

  Future<void> _openWhatsApp({
    required String phone,
    required String message,
  }) async {
    final p = _normalizeTrPhone(phone);
    if (p.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp için telefon numarası yok.')),
      );
      return;
    }

    final text = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$p?text=$text');

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('WhatsApp açılamadı.')));
    }
  }

  // ---------------------- ✅ Uygulama içi Chat ----------------------

  String _ownerIdOfListing(Map<String, dynamic> it) {
    // ✅ en sağlam alan: owner_id
    final a = (it['owner_id'] ?? '').toString().trim();
    if (a.isNotEmpty) return a;

    // ✅ bazen user_id olur
    final b = (it['user_id'] ?? '').toString().trim();
    if (b.isNotEmpty) return b;

    // ✅ profiles join varsa
    final p = it['profiles'];
    if (p is Map) {
      final pid = (p['id'] ?? '').toString().trim();
      if (pid.isNotEmpty) return pid;
    }
    if (p is List && p.isNotEmpty && p.first is Map) {
      final pid = ((p.first as Map)['id'] ?? '').toString().trim();
      if (pid.isNotEmpty) return pid;
    }

    return '';
  }

  Future<void> _openChat() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesaj için giriş yapmalısın.')),
      );
      return;
    }

    final listingId = _listingId();
    final otherId = _ownerIdOfListing(widget.listing);

    if (listingId.isEmpty || otherId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat açılamadı: listing/owner id yok.')),
      );
      return;
    }

    if (otherId == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kendi ilanına mesaj atamazsın 😄')),
      );
      return;
    }

    if (_chatLoading) return;
    setState(() => _chatLoading = true);

    try {
      // ✅ YENİ: getOrCreateConversation
      final convId = await _chatService.getOrCreateConversation(
        listingId: listingId,
        otherUserId: otherId,
      );

      final otherName = _profileName(widget.listing);
      final title = (widget.listing['title'] ?? '').toString().trim();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            chatId: convId, // ✅ conversation id
            otherUserId: otherId,
            otherUserName: otherName.isEmpty ? 'Kullanıcı' : otherName,
            listingTitle: title.isEmpty ? 'İlan' : title,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Chat açılamadı: $e')));
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  // ---------------------- Favori / Harita / Şikayet ----------------------

  Future<void> _loadFavoriteStatus() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (mounted) {
      setState(() => _favLoading = true);
    }

    try {
      if (user == null) {
        _isFav = false;
        return;
      }

      final id = _listingId();
      if (id.isEmpty) {
        _isFav = false;
        return;
      }

      final res = await Supabase.instance.client
          .from('favorites')
          .select('id')
          .eq('user_id', user.id)
          .eq('listing_id', id)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));

      _isFav = (res != null);
    } catch (_) {
      _isFav = false;
    } finally {
      if (mounted) setState(() => _favLoading = false);
    }
  }

  Future<void> _toggleFav() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Favori için giriş yapmalısın.')),
      );
      return;
    }

    final id = _listingId();
    if (id.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İlan ID bulunamadı.')));
      return;
    }

    if (_favLoading) return;

    setState(() => _favLoading = true);

    try {
      if (_isFav) {
        await Supabase.instance.client
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('listing_id', id);

        if (!mounted) return;
        setState(() => _isFav = false);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Favoriden çıkarıldı ❌')));
      } else {
        await Supabase.instance.client.from('favorites').upsert({
          'user_id': user.id,
          'listing_id': id,
        });

        if (!mounted) return;
        setState(() => _isFav = true);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Favorilere eklendi ✅')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Favori işlemi hata: $e')));
    } finally {
      if (mounted) setState(() => _favLoading = false);
    }
  }

  Future<void> _openMap({
    required String title,
    required String locationText,
  }) async {
    final q = Uri.encodeComponent(
      locationText.isNotEmpty ? locationText : title,
    );
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Harita açılamadı.')));
    }
  }

  Future<void> _submitReport({
    required String reason,
    required String details,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şikayet için giriş yapmalısın.')),
      );
      return;
    }

    final listingId = _listingId();
    if (listingId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İlan ID bulunamadı.')));
      return;
    }

    if (_reportLoading) return;
    setState(() => _reportLoading = true);

    try {
      await Supabase.instance.client.from('listing_reports').insert({
        'listing_id': listingId,
        'reporter_id': user.id,
        'reason': reason,
        'details': details.trim().isEmpty ? null : details.trim(),
        'status': 'new',
      });

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şikayet gönderildi ✅'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _reportTextCtrl.clear();
    } on PostgrestException catch (e) {
      final code = (e.code ?? '').toString();
      if (!mounted) return;

      Navigator.pop(context);

      if (code == '23505') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu ilanı zaten şikayet ettin.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Şikayet hatası: ${e.message}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Şikayet hatası: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  void _reportListing() {
    _reportTextCtrl.clear();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Şikayet Et',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _reportTextCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Kısaca detay yaz (opsiyonel)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _reportTile(
                  icon: Icons.report_gmailerrorred_outlined,
                  title: 'Sahte ilan / dolandırıcılık',
                  reason: 'scam',
                ),
                _reportTile(
                  icon: Icons.block_outlined,
                  title: 'Uygunsuz içerik',
                  reason: 'inappropriate',
                ),
                _reportTile(
                  icon: Icons.help_outline,
                  title: 'Diğer',
                  reason: 'other',
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _reportTile({
    required IconData icon,
    required String title,
    required String reason,
  }) {
    void send() => _submitReport(reason: reason, details: _reportTextCtrl.text);

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: _reportLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _reportLoading ? null : send,
            ),
      onTap: _reportLoading ? null : send,
    );
  }

  Widget _underAppBarActions({
    required String title,
    required String locationText,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _favLoading ? null : _toggleFav,
                icon: Icon(_isFav ? Icons.favorite : Icons.favorite_border),
                label: Text(
                  _favLoading
                      ? 'Yükleniyor...'
                      : (_isFav ? 'Favoride' : 'Favori Ekle'),
                ),
              ),
            ),
            Container(width: 1, height: 26, color: Colors.grey.shade300),
            Expanded(
              child: TextButton.icon(
                onPressed: () =>
                    _openMap(title: title, locationText: locationText),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Haritada'),
              ),
            ),
            Container(width: 1, height: 26, color: Colors.grey.shade300),
            Expanded(
              child: TextButton.icon(
                onPressed: _reportListing,
                icon: const Icon(Icons.report_gmailerrorred_outlined),
                label: const Text('Şikayet'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------- images ----------------------

  Future<void> _loadImages() async {
    if (mounted) {
      setState(() {
        _loadingImages = true;
        _imgError = null;
      });
    }

    try {
      _paths = _service.extractImagePaths(widget.listing);

      if (_paths.isEmpty) {
        if (!mounted) return;
        setState(() {
          _signedUrls = [];
          _loadingImages = false;
        });
        return;
      }

      final List<String> urls = [];
      for (final p in _paths) {
        final u = await _service.createSignedListingImageUrl(path: p);
        if (u != null && u.trim().isNotEmpty) urls.add(u.trim());
      }

      if (!mounted) return;
      setState(() {
        _signedUrls = urls;
        _loadingImages = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _imgError = e.toString();
        _loadingImages = false;
      });
    }
  }

  // ---------------------- helpers ----------------------

  String _clean(String s) => s.toString().trim();

  Map<String, dynamic> _safeMap(dynamic v) {
    if (v == null) return {};
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry('$k', val));
    return {};
  }

  Map<String, dynamic> _profile(Map<String, dynamic> it) {
    final p = it['profiles'];
    if (p is Map) return Map<String, dynamic>.from(p);

    if (p is List && p.isNotEmpty && p.first is Map) {
      return Map<String, dynamic>.from(p.first as Map);
    }

    return const <String, dynamic>{};
  }

  String _profilePhone(Map<String, dynamic> it) {
    final p = _profile(it);
    final fromProfile = _clean((p['phone'] ?? '').toString());
    if (fromProfile.isNotEmpty) return fromProfile;
    return _clean((it['phone'] ?? '').toString());
  }

  String _profileName(Map<String, dynamic> it) {
    final p = _profile(it);
    final fromProfile = _clean((p['full_name'] ?? '').toString());
    if (fromProfile.isNotEmpty) return fromProfile;
    return _clean((it['owner_name'] ?? '').toString());
  }

  String _fmtPrice(Map<String, dynamic> it) {
    final price = it['price'];
    final currency = (it['currency'] ?? 'TRY').toString();

    if (price == null) return 'Fiyat belirtilmemiş';

    final numPrice = (price is num)
        ? price.toDouble()
        : double.tryParse('$price');
    if (numPrice == null) return 'Fiyat belirtilmemiş';

    final cur = currency.toUpperCase() == 'TRY' ? '₺' : currency.toUpperCase();

    final typeStr = _clean(it['type'] ?? '');
    ListingType t = ListingType.roommate;
    try {
      t = listingTypeFromDb(typeStr);
    } catch (_) {}

    final priceStr = numPrice % 1 == 0
        ? numPrice.toStringAsFixed(0)
        : numPrice.toStringAsFixed(2);

    if (t == ListingType.roommate) {
      final periodRaw = (it['price_period'] ?? '').toString();
      String periodLabel;
      try {
        periodLabel = pricePeriodFromDb(periodRaw).label;
      } catch (_) {
        periodLabel = periodRaw.isEmpty ? 'Aylık' : periodRaw;
      }
      return '$cur$priceStr / $periodLabel';
    }

    return '$cur$priceStr (Tek Sefer)';
  }

  String? _fmtCreatedAt(Map<String, dynamic> it) {
    final raw = (it['created_at'] ?? it['inserted_at'] ?? it['createdAt']);
    if (raw == null) return null;

    DateTime? dt;
    if (raw is DateTime) {
      dt = raw;
    } else {
      dt = DateTime.tryParse(raw.toString());
    }
    if (dt == null) return null;

    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year}';
  }

  int? _views(Map<String, dynamic> it) {
    final v = it['views'] ?? it['view_count'] ?? it['viewCount'];
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Widget _chip(String text, {Color? bg, Color? fg}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: fg ?? theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _iconChip(IconData icon, String text, {Color? bg, Color? fg}) {
    final theme = Theme.of(context);
    final c = fg ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: c,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageArea() {
    if (_loadingImages) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_imgError != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(12),
            child: Text('Foto yüklenemedi: $_imgError'),
          ),
        ),
      );
    }

    if (_signedUrls.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: _signedUrls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final url = _signedUrls[i];
                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey,
                      ),
                    );
                  },
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.grey.shade100,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.55 * 255).round()),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_index + 1}/${_signedUrls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------- owner card ----------------------

  Widget _ownerCard({
    required String? ownerName,
    required String phone,
    required String? ownerCity,
  }) {
    final name = _clean(ownerName ?? '');
    final city = _clean(ownerCity ?? '');

    if (name.isEmpty && city.isEmpty && phone.isEmpty) return const SizedBox();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade100,
              child: Icon(Icons.person, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'İlan Sahibi' : name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (city.isNotEmpty) city,
                      if (phone.isNotEmpty) phone,
                    ].join(' • '),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (_isValidWhatsappPhone(phone))
              IconButton(
                tooltip: 'WhatsApp',
                onPressed: () => _openWhatsApp(
                  phone: phone,
                  message:
                      'Merhaba, ilanınızı uygulamada gördüm. Müsait misiniz?',
                ),
                icon: const FaIcon(FontAwesomeIcons.whatsapp),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------- BUILD ----------------------

  @override
  Widget build(BuildContext context) {
    final it = widget.listing;

    final title = _clean(it['title'] ?? '');
    final desc = _clean(it['description'] ?? '');

    final typeStr = _clean(it['type'] ?? '');
    ListingType typeEnum = ListingType.roommate;
    String typeLabel = typeStr;

    try {
      typeEnum = listingTypeFromDb(typeStr);
      typeLabel = typeEnum.label;
    } catch (_) {}

    final city = _clean(it['city'] ?? '');
    final district = _clean(it['district'] ?? '');
    final location = [
      if (city.isNotEmpty) city,
      if (district.isNotEmpty) district,
    ].join(' / ');

    final urgent = (it['is_urgent'] == true);
    final status = _clean(it['status'] ?? '');

    final phone = _profilePhone(it);
    final ownerName = _profileName(it);

    String? ownerCity;
    final p = _profile(it);
    if ((p['city'] ?? '').toString().trim().isNotEmpty) {
      ownerCity = p['city'].toString();
    } else {
      ownerCity =
          it['owner_city']?.toString() ??
          it['user_city']?.toString() ??
          it['city']?.toString();
    }

    final createdAt = _fmtCreatedAt(it);
    final views = _views(it);

    final rules = _safeMap(it['rules']);
    final preferences = _safeMap(it['preferences']);

    final showRoommateExtras = (typeEnum == ListingType.roommate);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        title: const Text('İlan Detayı'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Şikayet Et',
            onPressed: _reportListing,
            icon: const Icon(Icons.report_outlined),
          ),
          IconButton(
            tooltip: 'Foto yenile',
            onPressed: _loadImages,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Paylaş',
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              final shareText =
                  '${title.isEmpty ? "İlan" : title}\n\n'
                  '${_fmtPrice(it)}\n'
                  '${location.isNotEmpty ? location : "Konum belirtilmemiş"}';
              Share.share(shareText);
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(
              height: 72,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: _underAppBarActions(
                  title: title.isEmpty ? 'İlan' : title,
                  locationText: location,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _imageArea(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title.isEmpty ? '(Başlıksız)' : title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (urgent) ...[
                      const SizedBox(width: 10),
                      _chip('ACİL', bg: Colors.red, fg: Colors.white),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(typeLabel),
                    _chip(_fmtPrice(it)),
                    _chip(
                      location.isNotEmpty ? location : 'Konum belirtilmemiş',
                    ),
                    if (createdAt != null)
                      _iconChip(Icons.calendar_today, createdAt),
                    if (views != null)
                      _iconChip(Icons.remove_red_eye, '$views görüntüleme'),
                    if (status.isNotEmpty) _chip(status),
                    if (phone.isNotEmpty) _chip('Tel: $phone'),
                  ],
                ),
                const SizedBox(height: 14),
                _ownerCard(
                  ownerName: ownerName,
                  phone: phone,
                  ownerCity: ownerCity,
                ),
                const SizedBox(height: 10),
                if (showRoommateExtras) ...[
                  ListingRulesSection(rules: rules),
                  const SizedBox(height: 10),
                  ListingPreferencesSection(preferences: preferences),
                  const SizedBox(height: 10),
                ],
                if (desc.isNotEmpty) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        desc,
                        style: const TextStyle(fontSize: 15, height: 1.35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ✅ WhatsApp (kalsın)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isValidWhatsappPhone(phone)
                          ? () => _openWhatsApp(
                              phone: phone,
                              message:
                                  'Merhaba, "${title.isEmpty ? "ilan" : title}" ilanınızı uygulamada gördüm. Detay alabilir miyim?',
                            )
                          : null,
                      icon: const FaIcon(
                        FontAwesomeIcons.whatsapp,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'WhatsApp ile İletişime Geç',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ✅ Mesaj Gönder → UYGULAMA İÇİ CHAT
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _chatLoading ? null : _openChat,
                      icon: _chatLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chat_bubble_outline),
                      label: const Text(
                        'Mesaj Gönder',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: child);
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
