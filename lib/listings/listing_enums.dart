// lib/listings/listing_enums.dart
import 'package:flutter/material.dart';

/// ✅ İlan Türleri (DB'de string olarak saklanır)
/// roommate, item bölümleri zaten çalışıyor.
enum ListingType {
  roommate, // Ev Arkadaşı
  item, // Ev Eşyası
  // ✅ Yeni türler
  transport, // Nakliye Hizmetleri
  repair, // Dekorasyon / Onarım
  local, // Yakınımdaki Küçük Esnaf   (DB: local_shop)
  cleaning, // Temizlik Hizmetleri
  pet, // Evcil Hayvan Sahiplendirme
  daily_job, // Günlük İş            (DB: daily_job)
}

/// ✅ Fiyat periyodu (şimdilik sadece Tek Sefer kullanacağız)
enum PricePeriod { once, daily, weekly, monthly, yearly }

// ================= DB <-> ENUM (safe) =================

ListingType listingTypeFromDb(String v) {
  final value = v.trim().toLowerCase();

  // ✅ DB'de local_shop var -> enum local
  if (value == 'local_shop') return ListingType.local;

  // ✅ eski verilerde job varsa daily_job'a çevir
  if (value == 'job') return ListingType.daily_job;

  return ListingType.values.firstWhere(
    (e) => e.name.toLowerCase() == value,
    orElse: () => ListingType.roommate,
  );
}

PricePeriod pricePeriodFromDb(String v) {
  final value = v.trim().toLowerCase();
  return PricePeriod.values.firstWhere(
    (e) => e.name.toLowerCase() == value,
    orElse: () => PricePeriod.once, // ✅ default: Tek Sefer
  );
}

/// ✅ Enum -> DB
/// local enum'u DB'de local_shop olarak saklanacak
String listingTypeToDb(ListingType v) {
  switch (v) {
    case ListingType.local:
      return 'local_shop';
    default:
      return v.name; // roommate,item,transport,repair,cleaning,pet,daily_job
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
