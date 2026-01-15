// ==========================
// ✅ listing_detail_page.dart
// ✅ PART 1 / 2
// ==========================
import 'package:ev_arkadasi/core/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

  int _index = 0;
  bool _loadingImages = true;
  String? _imgError;

  bool _isFav = false;
  bool _favLoading = true;

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
      _snack('WhatsApp için telefon numarası yok.');
      return;
    }

    final text = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$p?text=$text');

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _snack('WhatsApp açılamadı.');
  }

  // ---------------------- Favori / Harita / Şikayet ----------------------

  Future<void> _loadFavoriteStatus() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (mounted) setState(() => _favLoading = true);

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
      _snack('Favori için giriş yapmalısın.');
      return;
    }

    final id = _listingId();
    if (id.isEmpty) {
      _snack('İlan ID bulunamadı.');
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

        _snack('Favoriden çıkarıldı ❌');
      } else {
        await Supabase.instance.client.from('favorites').upsert({
          'user_id': user.id,
          'listing_id': id,
        });

        if (!mounted) return;
        setState(() => _isFav = true);

        _snack('Favorilere eklendi ✅');
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Favori işlemi hata: $e');
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
    if (!ok && mounted) _snack('Harita açılamadı.');
  }

  Future<void> _submitReport({
    required String reason,
    required String details,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _snack('Şikayet için giriş yapmalısın.');
      return;
    }

    final listingId = _listingId();
    if (listingId.isEmpty) {
      _snack('İlan ID bulunamadı.');
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

      _snack('Şikayet gönderildi ✅');
      _reportTextCtrl.clear();
    } on PostgrestException catch (e) {
      final code = (e.code ?? '').toString();
      if (!mounted) return;

      Navigator.pop(context);

      if (code == '23505') {
        _snack('Bu ilanı zaten şikayet ettin.');
      } else {
        _snack('Şikayet hatası: ${e.message}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Şikayet hatası: $e');
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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppUI.gap(context, 16),
                AppUI.gap(context, 16),
                AppUI.gap(context, 16),
                AppUI.gap(context, 16) + bottom,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Şikayet Et',
                      style: TextStyle(
                        fontSize: AppUI.fs(context, 18),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: AppUI.gap(context, 10)),
                    TextField(
                      controller: _reportTextCtrl,
                      minLines: 2,
                      maxLines: 4,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      decoration: InputDecoration(
                        hintText: 'Kısaca detay yaz (opsiyonel)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppUI.r(context, 12),
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppUI.gap(context, 12),
                          vertical: AppUI.gap(context, 14),
                        ),
                      ),
                    ),
                    SizedBox(height: AppUI.gap(context, 12)),
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
                    SizedBox(height: AppUI.gap(context, 6)),
                  ],
                ),
              ),
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
          ? SizedBox(
              width: AppUI.gap(context, 18),
              height: AppUI.gap(context, 18),
              child: const CircularProgressIndicator(strokeWidth: 2),
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
        borderRadius: BorderRadius.circular(AppUI.r(context, 14)),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppUI.gap(context, 8),
          vertical: AppUI.gap(context, 6),
        ),
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
            Container(
              width: 1,
              height: AppUI.gap(context, 26),
              color: Colors.grey.shade300,
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: () =>
                    _openMap(title: title, locationText: locationText),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Haritada'),
              ),
            ),
            Container(
              width: 1,
              height: AppUI.gap(context, 26),
              color: Colors.grey.shade300,
            ),
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

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
      padding: EdgeInsets.symmetric(
        horizontal: AppUI.gap(context, 10),
        vertical: AppUI.gap(context, 6),
      ),
      decoration: BoxDecoration(
        color: bg ?? theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppUI.r(context, 999)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppUI.fs(context, 12),
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
      padding: EdgeInsets.symmetric(
        horizontal: AppUI.gap(context, 10),
        vertical: AppUI.gap(context, 6),
      ),
      decoration: BoxDecoration(
        color: bg ?? theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppUI.r(context, 999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppUI.fs(context, 14), color: c),
          SizedBox(width: AppUI.gap(context, 6)),
          Text(
            text,
            style: TextStyle(
              fontSize: AppUI.fs(context, 12),
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
        borderRadius: BorderRadius.circular(AppUI.r(context, 16)),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            child: SizedBox(
              width: AppUI.gap(context, 26),
              height: AppUI.gap(context, 26),
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_imgError != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppUI.r(context, 16)),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            padding: EdgeInsets.all(AppUI.gap(context, 12)),
            child: Text('Foto yüklenemedi: $_imgError'),
          ),
        ),
      );
    }

    if (_signedUrls.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppUI.r(context, 16)),
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
      borderRadius: BorderRadius.circular(AppUI.r(context, 16)),
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
                      child: SizedBox(
                        width: AppUI.gap(context, 26),
                        height: AppUI.gap(context, 26),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Positioned(
            left: AppUI.gap(context, 10),
            top: AppUI.gap(context, 10),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppUI.gap(context, 10),
                vertical: AppUI.gap(context, 6),
              ),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.55 * 255).round()),
                borderRadius: BorderRadius.circular(AppUI.r(context, 999)),
              ),
              child: Text(
                '${_index + 1}/${_signedUrls.length}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: AppUI.fs(context, 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================
  // ✅ listing_detail_page.dart
  // ✅ PART 2 / 2
  // ==========================

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
        borderRadius: BorderRadius.circular(AppUI.r(context, 14)),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppUI.gap(context, 12)),
        child: Row(
          children: [
            CircleAvatar(
              radius: AppUI.gap(context, 20),
              backgroundColor: Colors.grey.shade100,
              child: Icon(Icons.person, color: Colors.grey.shade600),
            ),
            SizedBox(width: AppUI.gap(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'İlan Sahibi' : name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: AppUI.fs(context, 14),
                    ),
                  ),
                  SizedBox(height: AppUI.gap(context, 2)),
                  Text(
                    [
                      if (city.isNotEmpty) city,
                      if (phone.isNotEmpty) phone,
                    ].join(' • '),
                    style: TextStyle(
                      fontSize: AppUI.fs(context, 12),
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        title: Text(
          'İlan Detayı',
          style: TextStyle(
            fontSize: AppUI.fs(context, 16),
            fontWeight: FontWeight.w700,
          ),
        ),
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
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeaderDelegate(
                height: AppUI.gap(context, 72),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppUI.gap(context, 12),
                    AppUI.gap(context, 8),
                    AppUI.gap(context, 12),
                    AppUI.gap(context, 8),
                  ),
                  child: _underAppBarActions(
                    title: title.isEmpty ? 'İlan' : title,
                    locationText: location,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.all(AppUI.gap(context, 12)),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _imageArea(),
                  SizedBox(height: AppUI.gap(context, 12)),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.isEmpty ? '(Başlıksız)' : title,
                          style: TextStyle(
                            fontSize: AppUI.fs(context, 20),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (urgent) ...[
                        SizedBox(width: AppUI.gap(context, 10)),
                        _chip('ACİL', bg: Colors.red, fg: Colors.white),
                      ],
                    ],
                  ),
                  SizedBox(height: AppUI.gap(context, 10)),
                  Wrap(
                    spacing: AppUI.gap(context, 8),
                    runSpacing: AppUI.gap(context, 8),
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
                  SizedBox(height: AppUI.gap(context, 14)),
                  _ownerCard(
                    ownerName: ownerName,
                    phone: phone,
                    ownerCity: ownerCity,
                  ),
                  SizedBox(height: AppUI.gap(context, 10)),
                  if (showRoommateExtras) ...[
                    ListingRulesSection(rules: rules),
                    SizedBox(height: AppUI.gap(context, 10)),
                    ListingPreferencesSection(preferences: preferences),
                    SizedBox(height: AppUI.gap(context, 10)),
                  ],
                  if (desc.isNotEmpty) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppUI.r(context, 14),
                        ),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(AppUI.gap(context, 12)),
                        child: Text(
                          desc,
                          style: TextStyle(
                            fontSize: AppUI.fs(context, 15),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: AppUI.gap(context, 14)),
                    SizedBox(
                      width: double.infinity,
                      height: AppUI.gap(context, 48),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppUI.r(context, 12),
                            ),
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
                        label: Text(
                          'WhatsApp ile İletişime Geç',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppUI.fs(context, 15),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: AppUI.gap(context, 18)),
                ]),
              ),
            ),
          ],
        ),
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
