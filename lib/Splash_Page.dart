import 'dart:async';

// ✅ APP UI
import 'package:ev_arkadasi/core/widgets/app_ui.dart';
import 'package:flutter/material.dart';

import 'features/auth/auth_gate.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();

    // ⏱️ Splash süresi (2.5 saniye)
    Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // 🎨 FOTOĞRAF HİSSİNİ KIRAN GRADIENT
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9F9F9), Color(0xFFEFEFEF)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppUI.gap(context, 16)),
            child: const _ResponsiveLogo(),
          ),
        ),
      ),
    );
  }
}

class _ResponsiveLogo extends StatelessWidget {
  const _ResponsiveLogo();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // ✅ AppUI ölçeği ile daha stabil logo boyutu
        final base = AppUI.s(context);

        // Ekrana göre hedef: genişliğin %55’i, ama min/max korumalı
        final raw = constraints.maxWidth * 0.55;

        // Min/Max (AppUI scale ile ufak ayar)
        final minSize = 160 * base;
        final maxSize = 260 * base;

        final size = raw.clamp(minSize, maxSize);

        return Image.asset(
          'assets/logo.png',
          width: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
      },
    );
  }
}
