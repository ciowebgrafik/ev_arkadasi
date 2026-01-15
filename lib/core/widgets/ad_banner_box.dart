import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdBannerBox extends StatefulWidget {
  const AdBannerBox({super.key, this.backgroundColor, this.padding});

  final Color? backgroundColor;
  final EdgeInsets? padding;

  @override
  State<AdBannerBox> createState() => _AdBannerBoxState();
}

class _AdBannerBoxState extends State<AdBannerBox> {
  BannerAd? _banner;
  bool _loaded = false;
  bool _isLoading = false;

  // ✅ TEST AdUnitId (yayına geçince PROD id koyacağız)
  String get _adUnitId {
    // DEBUG: resmi test id
    if (kDebugMode) {
      if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/6300978111';
      if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
    }

    // ✅ RELEASE (şimdilik test kalsın, canlıya geçince değiştirirsin)
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/6300978111';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';

    return 'ca-app-pub-3940256099942544/6300978111';
  }

  @override
  void initState() {
    super.initState();
    // initState'te MediaQuery yok -> ilk frame sonrası yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadBannerOnce();
    });
  }

  Future<void> _loadBannerOnce() async {
    // ✅ Web’de reklam yok (Platform da yok), patlamasın
    if (kIsWeb) return;

    // zaten yüklediysek / yükleniyorsa tekrar girme
    if (_banner != null || _isLoading) return;

    _isLoading = true;

    try {
      final width = MediaQuery.of(context).size.width.truncate();
      final size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);

      if (!mounted) return;
      if (size == null) {
        _isLoading = false;
        return;
      }

      final banner = BannerAd(
        adUnitId: _adUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted) return;
            setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, err) {
            ad.dispose();
            if (!mounted) return;
            setState(() {
              _banner = null;
              _loaded = false;
            });
          },
        ),
      );

      if (!mounted) return;
      setState(() => _banner = banner);

      await banner.load();
    } finally {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    if (_banner == null || !_loaded) return const SizedBox.shrink();

    final bg = widget.backgroundColor ?? Colors.white;
    final pad = widget.padding ?? EdgeInsets.zero;

    return Container(
      color: bg,
      padding: pad,
      alignment: Alignment.center,
      width: double.infinity,
      height: _banner!.size.height.toDouble(),
      child: AdWidget(ad: _banner!),
    );
  }
}
