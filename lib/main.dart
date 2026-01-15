import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // ✅ EKLENDİ
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/widgets/app_theme.dart';
import 'splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ AdMob init (banner için şart)
  await MobileAds.instance.initialize(); // ✅ EKLENDİ

  await Supabase.initialize(
    url: 'https://hulpynxdlpdljiyiebgn.supabase.co',
    anonKey: 'sb_publishable_Pr0fOJd7EzkSJ6lwkC87Ow_OoFNeqLz',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ev Arkadaşım',
      theme: AppTheme.light(),

      builder: (context, child) {
        final base = MediaQueryData.fromView(View.of(context));
        return MediaQuery(
          data: base.copyWith(
            textScaler: const TextScaler.linear(1.0),
            // ✅ sistem font büyütmeyi kapatır
            boldText: false,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },

      home: const SplashPage(),
    );
  }
}
