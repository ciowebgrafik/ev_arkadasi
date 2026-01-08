import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/widgets/app_theme.dart';
import 'splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

      // ✅ Splash bozulmaz
      home: const SplashPage(),
    );
  }
}
