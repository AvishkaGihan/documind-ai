import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'theme_extensions.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get darkTheme =>
      _buildTheme(brightness: Brightness.dark, palette: AppColors.dark);

  static ThemeData get lightTheme =>
      _buildTheme(brightness: Brightness.light, palette: AppColors.light);

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppColorPalette palette,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.accentPrimary,
      onPrimary: palette.textOnAccent,
      secondary: palette.accentSecondary,
      onSecondary: palette.textOnAccent,
      error: palette.accentError,
      onError: palette.textOnAccent,
      surface: palette.surfacePrimary,
      onSurface: palette.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.surfacePrimary,
      textTheme: AppTypography.buildTextTheme(palette),
      extensions: <ThemeExtension<dynamic>>[DocuMindTokens(colors: palette)],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surfacePrimary,
        foregroundColor: palette.textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: palette.surfaceSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.borderDefault),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.borderEmphasis),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accentPrimary,
          foregroundColor: palette.textOnAccent,
        ),
      ),
    );
  }
}
