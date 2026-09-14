import 'package:flutter/material.dart';

class LedgerColors {
  static const inkBg = Color(0xFF14181F);
  static const inkPanel = Color(0xFF1C212C);
  static const parchment = Color(0xFFEDE7D9);
  static const brass = Color(0xFFB08D57);
  static const slate = Color(0xFF8A93A6);
  static const hairline = Color(0xFF2B3140);
}

ThemeData buildLedgerTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: LedgerColors.inkBg,
    colorScheme: const ColorScheme.dark(
      primary: LedgerColors.brass,
      surface: LedgerColors.inkPanel,
      onSurface: LedgerColors.parchment,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: LedgerColors.parchment),
    ),
  );
}
