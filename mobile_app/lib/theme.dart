import 'package:flutter/material.dart';

class LedgerColors {
  static const inkBg = Color(0xFF14181F);
  static const inkPanel = Color(0xFF1C212C);
  static const parchment = Color(0xFFEDE7D9);
  static const brass = Color(0xFFB08D57);
  static const slate = Color(0xFFA0AABF); // Lightened for better contrast
  static const hairline = Color(0xFF2B3140);
}

ThemeData buildLedgerTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: LedgerColors.inkBg,
    colorScheme: const ColorScheme.dark(
      primary: LedgerColors.brass,
      secondary: LedgerColors.brass,
      surface: LedgerColors.inkPanel,
      onSurface: LedgerColors.parchment,
      outline: LedgerColors.hairline,
      onSecondary: LedgerColors.inkBg,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: LedgerColors.inkBg,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: LedgerColors.parchment,
        fontFamily: 'Georgia',
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: LedgerColors.inkPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: LedgerColors.hairline),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LedgerColors.inkBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: LedgerColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: LedgerColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: LedgerColors.brass),
      ),
      labelStyle: const TextStyle(color: LedgerColors.slate),
      hintStyle: const TextStyle(color: LedgerColors.slate, fontSize: 13),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: LedgerColors.brass,
        foregroundColor: LedgerColors.inkBg,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: LedgerColors.brass,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: LedgerColors.parchment,
        fontFamily: 'Georgia',
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: LedgerColors.parchment,
        fontFamily: 'Georgia',
        fontSize: 16,
      ),
      bodyLarge: TextStyle(color: LedgerColors.parchment),
      bodyMedium: TextStyle(color: LedgerColors.parchment),
      bodySmall: TextStyle(color: LedgerColors.slate),
      labelLarge: TextStyle(color: LedgerColors.slate, fontSize: 12),
    ),
    dividerTheme: const DividerThemeData(
      color: LedgerColors.hairline,
      thickness: 1,
      space: 1,
    ),
  );
}
