import 'dart:async';

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
        child: const Center(child: _ResponsiveLogo()),
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
        // 📐 Her telefonda orantılı boyut
        final logoSize = constraints.maxWidth * 0.55;

        return Image.asset(
          'assets/logo.png',
          width: logoSize > 260 ? 260 : logoSize, // 🔒 maksimum sınır
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
      },
    );
  }
}
