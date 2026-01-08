enum ListingType { roommate, item, job }

enum PricePeriod { once, daily, weekly, monthly, yearly }

// DB <-> ENUM (safe)
ListingType listingTypeFromDb(String v) {
  final value = v.trim();
  return ListingType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => ListingType.roommate,
  );
}

PricePeriod pricePeriodFromDb(String v) {
  final value = v.trim();
  return PricePeriod.values.firstWhere(
    (e) => e.name == value,
    orElse: () => PricePeriod.monthly,
  );
}

String listingTypeToDb(ListingType v) => v.name;

String pricePeriodToDb(PricePeriod v) => v.name;

// ================= TÜRKÇE LABEL =================

extension ListingTypeLabel on ListingType {
  String get label {
    switch (this) {
      case ListingType.roommate:
        return 'Ev Arkadaşı';
      case ListingType.item:
        return 'Ev Eşyası';
      case ListingType.job:
        return 'Acil İş';
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
