import 'package:flutter/material.dart';

class AppUI {
  // ✅ Renkler
  static const Color kTurkuaz = Color(0xFF00B8D4);

  // Tasarım referansı (iPhone 13 gibi)
  static const double _designW = 390;
  static const double _designH = 844;

  // Ölçek: aşırı büyümeyi engelle (clamp)
  static double scaleW(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    final s = w / _designW;
    return s.clamp(0.90, 1.15);
  }

  static double scaleH(BuildContext c) {
    final h = MediaQuery.sizeOf(c).height;
    final s = h / _designH;
    return s.clamp(0.90, 1.15);
  }

  // Genel ölçek (w/h ortalama)
  static double s(BuildContext c) {
    final sw = scaleW(c);
    final sh = scaleH(c);
    return ((sw + sh) / 2).clamp(0.90, 1.15);
  }

  // Spacing
  static double gap(BuildContext c, double v) => v * s(c);

  // Radius
  static double r(BuildContext c, double v) => v * s(c);

  // Font size
  static double fs(BuildContext c, double v) => v * s(c);

  // ✅ Sık kullanılan sabit ölçüler (scale’siz, pratik)
  static const double g4 = 4;
  static const double g8 = 8;
  static const double g10 = 10;
  static const double g12 = 12;
  static const double g14 = 14;
  static const double g16 = 16;
  static const double g20 = 20;
  static const double g24 = 24;
  static const double g32 = 32;
  static const double g40 = 40;
  static const double g60 = 60;
  static const double g80 = 80;
  static const double g120 = 120;
  static const double g140 = 140;
  static const double g220 = 220;

  // ✅ Radius sabitleri
  static const double r10 = 10;
  static const double r12 = 12;
  static const double r14 = 14;
  static const double r16 = 16;
  static const double r18 = 18;

  // ✅ Font size sabitleri
  static const double fs12 = 12;
  static const double fs14 = 14;
  static const double fs16 = 16;

  // Paddings
  static EdgeInsets pagePadding(BuildContext c) =>
      EdgeInsets.fromLTRB(gap(c, 16), gap(c, 12), gap(c, 16), gap(c, 16));
}
