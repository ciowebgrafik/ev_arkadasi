import 'package:flutter/material.dart';

import 'listing_create_page.dart';

class ListingEditPage extends StatelessWidget {
  const ListingEditPage({super.key, required this.listing});

  /// listings tablosundan gelen satır (Map)
  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) {
    return ListingCreatePage(editListing: listing);
  }
}
