import 'package:flutter/material.dart';

class AppTheme {
  static const Color kTurkuaz = Color(0xFF00B8D4);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kTurkuaz,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      // ✅ APPBAR
      appBarTheme: const AppBarTheme(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
      ),

      // ✅ CHECKBOX
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return kTurkuaz;
          return Colors.grey.shade400;
        }),
      ),

      // ✅ SWITCH
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return kTurkuaz;
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return kTurkuaz.withOpacity(0.45);
          }
          return Colors.grey.shade300;
        }),
      ),

      // ✅ FLOATING BUTTON
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kTurkuaz,
        foregroundColor: Colors.white,
      ),

      // ✅ ELEVATED BUTTON
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kTurkuaz,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      // ✅ OUTLINED BUTTON
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kTurkuaz,
          side: const BorderSide(color: kTurkuaz),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      // ✅ CHIP
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: kTurkuaz.withOpacity(0.08),
        selectedColor: kTurkuaz.withOpacity(0.2),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
