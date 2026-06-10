import 'package:flutter/material.dart';

class MindVaultColors {
  static const primary = Color(0xFF4F46E5);
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E7EB);
  static const text = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const selected = Color(0xFFEEF2FF);
  static const hover = Color(0xFFF3F4F6);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
}

ThemeData buildMindVaultTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: MindVaultColors.primary,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: MindVaultColors.background,
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: MindVaultColors.surface,
      foregroundColor: MindVaultColors.text,
      elevation: 0,
      surfaceTintColor: MindVaultColors.surface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(color: MindVaultColors.border, thickness: 1),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: MindVaultColors.text),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: MindVaultColors.text),
      bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: MindVaultColors.text),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: MindVaultColors.text),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: MindVaultColors.muted),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: const CircleBorder(),
        foregroundColor: MindVaultColors.text,
        hoverColor: MindVaultColors.hover,
      ),
    ),
  );
}
