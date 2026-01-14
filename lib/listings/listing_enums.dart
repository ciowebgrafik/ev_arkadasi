// lib/listings/listing_enums.dart
import 'package:flutter/material.dart';

/// ✅ İlan Türleri (DB'de string olarak saklanır)
enum ListingType {
  roommate, // Ev Arkadaşı
  item, // Ev Eşyası
  // ✅ Hizmet / diğer kategoriler
  transport, // Nakliye Hizmetleri
  repair, // Dekorasyon / Onarım
  local, // Yakınımdaki Küçük Esnaf   (DB: local_shop)
  cleaning, // Temizlik Hizmetleri
  pet, // Evcil Hayvan Sahiplendirme
  daily_job, // Günlük İş            (DB: daily_job)
}

/// ✅ Fiyat periyodu
enum PricePeriod { once, daily, weekly, monthly, yearly }

// ================= DB <-> ENUM (ULTRA SAFE) =================

/// ✅ Her yerden (dynamic/null) güvenle parse etmek için
String _norm(dynamic v) => (v ?? '').toString().trim().toLowerCase();

ListingType listingTypeFromDb(dynamic v) {
  final value = _norm(v);

  if (value.isEmpty) return ListingType.roommate;

  // ✅ DB'de local_shop var -> enum local
  if (value == 'local_shop') return ListingType.local;

  // ✅ eski verilerde job varsa daily_job'a çevir (geriye uyumluluk)
  if (value == 'job') return ListingType.daily_job;

  // ✅ bazen "daily-job" / "daily job" gibi saçma veriler gelebilir
  if (value == 'daily-job' || value == 'daily job')
    return ListingType.daily_job;

  // ✅ güvenli arama
  for (final e in ListingType.values) {
    if (e.name.toLowerCase() == value) return e;
  }

  // ✅ tanınmayan type -> patlamasın
  return ListingType.roommate;
}

PricePeriod pricePeriodFromDb(dynamic v) {
  final value = _norm(v);
  if (value.isEmpty) return PricePeriod.once;

  // ✅ bazen "tek_sefer" gibi gelirse:
  if (value == 'tek_sefer' || value == 'teksefer') return PricePeriod.once;

  for (final e in PricePeriod.values) {
    if (e.name.toLowerCase() == value) return e;
  }

  // ✅ tanınmayan period -> patlamasın
  return PricePeriod.once; // default: Tek Sefer
}

/// ✅ Enum -> DB
/// local enum'u DB'de local_shop olarak saklanacak
String listingTypeToDb(ListingType v) {
  switch (v) {
    case ListingType.local:
      return 'local_shop';
    default:
      // roommate,item,transport,repair,cleaning,pet,daily_job
      return v.name;
  }
}

String pricePeriodToDb(PricePeriod v) => v.name;

// ================= TÜRKÇE LABEL =================

extension ListingTypeLabel on ListingType {
  String get label {
    switch (this) {
      case ListingType.roommate:
        return 'Ev Arkadaşı';
      case ListingType.item:
        return 'Ev Eşyası';
      case ListingType.transport:
        return 'Nakliye Hizmetleri';
      case ListingType.repair:
        return 'Dekorasyon / Onarım';
      case ListingType.local:
        return 'Yakınımdaki Küçük Esnaf';
      case ListingType.cleaning:
        return 'Temizlik Hizmetleri';
      case ListingType.pet:
        return 'Evcil Hayvan Sahiplendirme';
      case ListingType.daily_job:
        return 'Günlük İş';
    }
  }
}

// ✅ Home/İlan türü sıralaması (senin kağıttaki sıraya göre)
extension ListingTypeOrder on ListingType {
  int get order {
    switch (this) {
      case ListingType.roommate:
        return 1;
      case ListingType.item:
        return 2;
      case ListingType.transport:
        return 3;
      case ListingType.repair:
        return 4;
      case ListingType.local:
        return 5;
      case ListingType.cleaning:
        return 6;
      case ListingType.pet:
        return 7;
      case ListingType.daily_job:
        return 8;
    }
  }
}

// ✅ Butonlarda ikon kullanmak istersen (hazır dursun)
extension ListingTypeIcon on ListingType {
  IconData get icon {
    switch (this) {
      case ListingType.roommate:
        return Icons.people_alt_outlined;
      case ListingType.item:
        return Icons.chair_alt_outlined;
      case ListingType.transport:
        return Icons.local_shipping_outlined;
      case ListingType.repair:
        return Icons.handyman_outlined;
      case ListingType.local:
        return Icons.storefront_outlined;
      case ListingType.cleaning:
        return Icons.cleaning_services_outlined;
      case ListingType.pet:
        return Icons.pets_outlined;
      case ListingType.daily_job:
        return Icons.work_outline;
    }
  }
}

extension PricePeriodLabel on PricePeriod {
  String get label {
    switch (this) {
      case PricePeriod.once:
        return 'Tek Sefer';
      case PricePeriod.daily:
        return 'Günlük';
      case PricePeriod.weekly:
        return 'Haftalık';
      case PricePeriod.monthly:
        return 'Aylık';
      case PricePeriod.yearly:
        return 'Yıllık';
    }
  }
}
