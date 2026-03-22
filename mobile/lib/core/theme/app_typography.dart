import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTypography {
  const AppTypography._();

  static TextTheme buildTextTheme(AppColorPalette colors) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
        color: colors.textOnAccent,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
      ),
    );
  }

  static TextStyle codeStyle(AppColorPalette colors) {
    return TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w400,
      color: colors.textPrimary,
    );
  }
}
