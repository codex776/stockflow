import 'package:flutter/material.dart';

// ====================================================================
// StockFlow design system — tokens ported from styles/main.css.
// ====================================================================

abstract final class C {
  static const navy = Color(0xFF1E3A5F);
  static const navy2 = Color(0xFF2C5282);
  static const blue = Color(0xFF3182CE);
  static const blueD = Color(0xFF2563EB);
  static const green = Color(0xFF059669);
  static const amber = Color(0xFFD97706);
  static const red = Color(0xFFDC2626);
  static const bg = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);

  static const blueBg = Color(0xFFEFF6FF);
  static const blueSoft = Color(0xFFDBEAFE);
  static const greenBg = Color(0xFFECFDF5);
  static const greenSoft = Color(0xFFD1FAE5);
  static const amberBg = Color(0xFFFFFBEB);
  static const amberSoft = Color(0xFFFEF3C7);
  static const redBg = Color(0xFFFEF2F2);
  static const redSoft = Color(0xFFFEE2E2);
  static const navyBg = Color(0xFFF1F5F9);
  static const sheetOverlay = Color(0x99011B33);

  static const amps = <String, Color>{
    'blue': blue,
    'green': green,
    'amber': amber,
    'red': red,
    'navy': navy,
  };
}

abstract final class R {
  static const lg = 18.0;
  static const md = 14.0;
  static const sm = 10.0;
  static const pill = 999.0;
}

const appbarH = 60.0;
const tabbarH = 64.0;

Color amp(String key) => C.amps[key] ?? C.blue;

Color chipBg(String key) => switch (key) {
      'green' => C.greenSoft,
      'amber' => C.amberSoft,
      'red' => C.redSoft,
      'blue' => C.blueSoft,
      'navy' => C.navyBg,
      _ => C.navyBg,
    };

ThemeData sfTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.blue,
      primary: C.blue,
      secondary: C.green,
      surface: C.surface,
      error: C.red,
    ),
    scaffoldBackgroundColor: C.bg,
    fontFamily: null,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: C.surface,
      foregroundColor: C.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 16,
      titleTextStyle: TextStyle(
        color: C.ink,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: C.ink,
      unselectedLabelColor: C.muted,
      indicatorColor: C.blue,
      dividerColor: C.line,
      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.sm)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.ink,
        side: const BorderSide(color: C.line),
        minimumSize: const Size(44, 50),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.sm)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: C.blueD,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: C.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.sm),
        borderSide: const BorderSide(color: C.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.sm),
        borderSide: const BorderSide(color: C.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.sm),
        borderSide: const BorderSide(color: C.blue, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.sm),
        borderSide: const BorderSide(color: C.red),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: C.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(R.md),
        side: const BorderSide(color: C.line),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: C.line, thickness: 1, space: 1),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.pill)),
      side: const BorderSide(color: C.line),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.sm)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.lg)),
      ),
    ),
  );
}

TextStyle tS(double size, {FontWeight w = FontWeight.w400, Color? color, double? height}) =>
    TextStyle(fontSize: size, fontWeight: w, color: color ?? C.ink, height: height);