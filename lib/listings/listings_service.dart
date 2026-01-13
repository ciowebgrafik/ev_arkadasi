import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart'; // ✅ debugPrint
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listing_enums.dart';

// ✅ Doping tipleri
enum DopingType { gold, urgent, featured }

class ListingsService {
  final SupabaseClient _db = Supabase.instance.client;

  // ✅ Foto bucket adı (Supabase Storage)
  static const String listingImagesBucket = 'listing-images';

  // ------------------ Helpers (temizlik) ------------------

  String? _cleanNullable(String? v) {
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Map<String, dynamic> _cleanJson(Map<String, dynamic>? v) {
    if (v == null) return {};
    final cleaned = <String, dynamic>{};
    v.forEach((key, value) {
      if (value == null) return;
      cleaned[key] = value;
    });
    return cleaned;
  }

  // ✅ TR normalize: İ/ı/I sorunlarını düzelt + boşlukları toparla
  String _norm(String s) {
    var t = s.trim();
    if (t.isEmpty) return '';

    t = t.replaceAll('İ', 'i').replaceAll('I', 'ı');
    t = t.toLowerCase();

    t = t
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ç', 'c')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ı', 'i');

    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t;
  }

  // ------------------ CRUD ------------------

  Future<String> createListing({
    required ListingType type,
    required String title,
    String? description,
    String? city,
    String? district,
    double? price,
    PricePeriod pricePeriod = PricePeriod.monthly,
    String currency = 'TRY',
    bool billsIncluded = false,
    bool isUrgent = false,
    String? phone,
    String? itemCategory,
    Map<String, dynamic>? details,
    Map<String, dynamic>? rules,
    Map<String, dynamic>? preferences,
    String status = 'draft',
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Giriş yapılmamış.');

    final mergedDetails = <String, dynamic>{
      ..._cleanJson(details),
      if (type == ListingType.item &&
          itemCategory != null &&
          itemCategory.trim().isNotEmpty)
        'category': itemCategory.trim(),
    };

    final payload = <String, dynamic>{
      'owner_id': user.id,
      'type': listingTypeToDb(type),
      'title': title.trim(),
      'description': _cleanNullable(description),
      'city': _cleanNullable(city),
      'district': _cleanNullable(district),
      'price': price,
      'price_period': pricePeriodToDb(pricePeriod),
      'currency': currency,
      'bills_included': billsIncluded,
      'is_urgent': isUrgent,
      'phone': _cleanNullable(phone),
      'details': mergedDetails,
      'rules': _cleanJson(rules),
      'preferences': _cleanJson(preferences),
      'status': status.trim(),
    };

    final res = await _db
        .from('listings')
        .insert(payload)
        .select('id')
        .single();
    return res['id'].toString();
  }

  Future<void> updateListing({
    required String listingId,
    required ListingType type,
    required String title,
    String? description,
    String? city,
    String? district,
    double? price,
    PricePeriod pricePeriod = PricePeriod.monthly,
    String currency = 'TRY',
    bool billsIncluded = false,
    bool isUrgent = false,
    String? phone,
    Map<String, dynamic>? details,
    Map<String, dynamic>? rules,
    Map<String, dynamic>? preferences,
    String? status,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Giriş yapılmamış.');

    final payload = <String, dynamic>{
      'type': listingTypeToDb(type),
      'title': title.trim(),
      'description': _cleanNullable(description),
      'city': _cleanNullable(city),
      'district': _cleanNullable(district),
      'price': price,
      'price_period': pricePeriodToDb(pricePeriod),
      'currency': currency,
      'bills_included': billsIncluded,
      'is_urgent': isUrgent,
      'phone': _cleanNullable(phone),
      'details': _cleanJson(details),
      'rules': _cleanJson(rules),
      'preferences': _cleanJson(preferences),
      if (status != null) 'status': status.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _db
        .from('listings')
        .update(payload)
        .eq('id', listingId)
        .eq('owner_id', user.id);
  }

  Future<void> updateListingJson({
    required String listingId,
    Map<String, dynamic>? details,
    Map<String, dynamic>? rules,
    Map<String, dynamic>? preferences,
  }) async {
    final payload = <String, dynamic>{};
    if (details != null) payload['details'] = _cleanJson(details);
    if (rules != null) payload['rules'] = _cleanJson(rules);
    if (preferences != null) payload['preferences'] = _cleanJson(preferences);
    if (payload.isEmpty) return;

    payload['updated_at'] = DateTime.now().toIso8601String();
    await _db.from('listings').update(payload).eq('id', listingId);
  }

  // ===================== ✅ DOİNG / DOPİNG UYGULA (kolonlarla) =====================
  /// Gold: 30 gün
  /// Urgent: 15 gün
  /// Featured: 7 gün
  Future<void> applyDoping({
    required String listingId,
    required DopingType type,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Giriş yapılmamış.');

    final nowUtc = DateTime.now().toUtc();
    Map<String, dynamic> data = {};

    if (type == DopingType.gold) {
      data = {
        'is_gold': true,
        'gold_until': nowUtc.add(const Duration(days: 30)).toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
    } else if (type == DopingType.urgent) {
      data = {
        'is_urgent': true,
        'urgent_until': nowUtc.add(const Duration(days: 15)).toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
    } else if (type == DopingType.featured) {
      data = {
        'is_featured': true,
        'featured_until': nowUtc.add(const Duration(days: 7)).toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
    }

    await _db
        .from('listings')
        .update(data)
        .eq('id', listingId)
        .eq('owner_id', user.id);
  }

  // ===================== ✅ APPLY BOOST (details json içine yazar) =====================
  /// MyListingsPage'deki rozet kodun boost_plan + boost_end üzerinden çalışıyor.
  /// Bu fonksiyon mevcut details'ı ezmeden merge eder.
  ///
  /// plan örnekleri:
  /// - "featured" / "gold" / "urgent"  (senin badge switch'ine uygun)
  /// - istersen "featured_7" gibi de yazarsın ama badge kodunda plan eşleşmesini ona göre değiştirmen gerekir.
  Future<void> applyBoost({
    required String listingId,
    required String plan, // featured | gold | urgent | bronze | silver
    required int days,
    required int priceTry,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Giriş yapılmamış.');

    final now = DateTime.now();
    final end = now.add(Duration(days: days));

    // ✅ mevcut details + owner kontrol
    final cur = await _db
        .from('listings')
        .select('details, owner_id')
        .eq('id', listingId)
        .maybeSingle();

    if (cur == null) throw Exception('İlan bulunamadı.');
    if ((cur['owner_id'] ?? '').toString() != user.id) {
      throw Exception('Bu ilan sana ait değil.');
    }

    final existing = cur['details'];
    Map<String, dynamic> details = {};
    if (existing is Map<String, dynamic>)
      details = Map<String, dynamic>.from(existing);
    if (existing is Map) details = existing.map((k, v) => MapEntry('$k', v));

    details['boost_plan'] = plan; // ✅ MyListingsPage bunu okuyor
    details['boost_start'] = now.toIso8601String();
    details['boost_end'] = end.toIso8601String();
    details['boost_days'] = days;
    details['boost_price'] = priceTry;
    details['boosted'] = true;

    await _db
        .from('listings')
        .update({
          'details': details,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', listingId)
        .eq('owner_id', user.id);
  }

  // ===================== ✅ İLANI KALDIR (soft remove) =====================
  /// “kaldır” = paused
  Future<void> removeListing({required String listingId}) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Giriş yapılmamış.');

    await _db
        .from('listings')
        .update({
          'status': 'paused',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', listingId)
        .eq('owner_id', user.id);
  }

  // ===================== Photos =====================

  Future<List<String>> uploadListingImages({
    required String listingId,
    required List<XFile> images,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Giriş yapılmamış.');
    if (images.isEmpty) return [];

    final List<String> paths = [];
    final rnd = Random();

    for (final img in images) {
      final bytes = await img.readAsBytes();

      final ext = _guessExt(img.name);
      final contentType = _contentType(ext);

      final filename =
          '${DateTime.now().millisecondsSinceEpoch}${user.id}${rnd.nextInt(999999)}.$ext';

      final path = 'listings/$listingId/$filename';

      await _db.storage
          .from(listingImagesBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: false, contentType: contentType),
          );

      paths.add(path);
    }

    return paths;
  }

  /// REPLACE
  Future<void> attachListingImages({
    required String listingId,
    required List<String> imagePaths,
  }) async {
    await _db
        .from('listings')
        .update({
          'image_paths': imagePaths,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', listingId);
  }

  /// Storage'dan path sil (Private bucket)
  Future<void> deleteListingImagesFromStorage(List<String> paths) async {
    final cleaned = paths
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((p) => p.startsWith('listings/') ? p : 'listings/$p')
        .toList();
    if (cleaned.isEmpty) return;

    try {
      await _db.storage.from(listingImagesBucket).remove(cleaned);
    } catch (e) {
      debugPrint('deleteListingImagesFromStorage ERROR: $e');
    }
  }

  // ===================== image_paths read =====================

  List<String> extractImagePaths(Map<String, dynamic> listing) {
    final v = listing['image_paths'];
    if (v == null) return [];

    if (v is List) {
      return v
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }

    if (v is String) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString())
              .where((s) => s.trim().isNotEmpty)
              .toList();
        }
      } catch (_) {
        return [];
      }
    }

    return [];
  }

  Future<String?> createSignedListingImageUrl({
    required String path,
    int expiresInSeconds = 3600,
  }) async {
    var p = path.trim();
    if (p.isEmpty) return null;
    if (!p.startsWith('listings/')) p = 'listings/$p';

    try {
      final url = await _db.storage
          .from(listingImagesBucket)
          .createSignedUrl(p, expiresInSeconds);

      final bust = DateTime.now().millisecondsSinceEpoch;
      return '$url${url.contains('?') ? '&' : '?'}cb=$bust';
    } catch (e) {
      debugPrint('createSignedUrl ERROR: $e | path=$p');
      return null;
    }
  }

  Future<List<String?>> createSignedListingImageUrls(
    List<String> paths, {
    int expiresInSeconds = 3600,
  }) async {
    final out = <String?>[];
    for (final p in paths) {
      out.add(
        await createSignedListingImageUrl(
          path: p,
          expiresInSeconds: expiresInSeconds,
        ),
      );
    }
    return out;
  }

  Future<String?> signedFirstImageUrlFromListing(
    Map<String, dynamic> listing, {
    int expiresInSeconds = 3600,
  }) async {
    final paths = extractImagePaths(listing);
    if (paths.isEmpty) return null;
    return createSignedListingImageUrl(
      path: paths.first,
      expiresInSeconds: expiresInSeconds,
    );
  }

  // ===================== Select =====================

  Future<List<Map<String, dynamic>>> fetchListings({
    ListingType? type,
    PricePeriod? pricePeriod,
    String? city,
    String? district,
    String? searchQuery,
    String? itemCategory,
    int limit = 30,
    String? status = 'published',
  }) async {
    var q = _db
        .from('listings')
        .select('*, profiles!listings_owner_id_fkey(full_name, phone)');

    final st = (status ?? '').trim();

    if (st.isNotEmpty) {
      q = q.eq('status', st);
    } else {
      q = q
          .neq('status', 'paused')
          .neq('status', 'deleted')
          .neq('status', 'closed')
          .neq('status', 'sold')
          .neq('status', 'draft')
          .neq('status', 'pending')
          .neq('status', 'rejected');
    }

    if (type != null) q = q.eq('type', listingTypeToDb(type));
    if (pricePeriod != null) {
      q = q.eq('price_period', pricePeriodToDb(pricePeriod));
    }

    if (city != null && city.trim().isNotEmpty) {
      final c = _norm(city);
      q = q.ilike('city', '%$c%');
    }

    if (district != null && district.trim().isNotEmpty) {
      final d = _norm(district);
      q = q.ilike('district', '%$d%');
    }

    if (itemCategory != null && itemCategory.trim().isNotEmpty) {
      final cat = _norm(itemCategory);
      q = q.eq('details->>category', cat);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final s = _norm(searchQuery);
      q = q.or('title.ilike.%$s%,description.ilike.%$s%');
    }

    final res = await q.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchMyListings({int limit = 100}) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Giriş yapılmamış.');

    final res = await _db
        .from('listings')
        .select('*')
        .eq('owner_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(res);
  }

  // ✅ DEĞİŞİKLİK: republishListing artık published yapmaz -> pending (admin onay)
  Future<void> republishListing(String listingId) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Giriş yapılmamış.');

    try {
      final cur = await _db
          .from('listings')
          .select('status')
          .eq('id', listingId)
          .eq('owner_id', user.id)
          .maybeSingle();

      final st = (cur?['status'] ?? '').toString().toLowerCase().trim();
      if (st == 'pending') return;
    } catch (_) {}

    await _db
        .from('listings')
        .update({
          'status': 'pending',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', listingId)
        .eq('owner_id', user.id);
  }

  Future<void> deleteListing(String listingId) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Giriş yapılmamış.');

    await _db
        .from('listings')
        .delete()
        .eq('id', listingId)
        .eq('owner_id', user.id);
  }

  // ================= Helpers =================

  String _guessExt(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.jpeg')) return 'jpg';
    if (lower.endsWith('.jpg')) return 'jpg';
    return 'jpg';
  }

  String _contentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}
