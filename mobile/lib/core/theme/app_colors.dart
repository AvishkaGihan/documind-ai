import 'package:flutter/material.dart';

@immutable
class AppColorPalette {
  const AppColorPalette({
    required this.surfacePrimary,
    required this.surfaceSecondary,
    required this.surfaceTertiary,
    required this.surfaceInput,
    required this.borderDefault,
    required this.borderEmphasis,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.accentCitation,
    required this.accentWarning,
    required this.accentError,
    required this.accentAiGlow,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnAccent,
  });

  final Color surfacePrimary;
  final Color surfaceSecondary;
  final Color surfaceTertiary;
  final Color surfaceInput;
  final Color borderDefault;
  final Color borderEmphasis;

  final Color accentPrimary;
  final Color accentSecondary;
  final Color accentCitation;
  final Color accentWarning;
  final Color accentError;
  final Color accentAiGlow;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnAccent;

  AppColorPalette copyWith({
    Color? surfacePrimary,
    Color? surfaceSecondary,
    Color? surfaceTertiary,
    Color? surfaceInput,
    Color? borderDefault,
    Color? borderEmphasis,
    Color? accentPrimary,
    Color? accentSecondary,
    Color? accentCitation,
    Color? accentWarning,
    Color? accentError,
    Color? accentAiGlow,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textOnAccent,
  }) {
    return AppColorPalette(
      surfacePrimary: surfacePrimary ?? this.surfacePrimary,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      surfaceTertiary: surfaceTertiary ?? this.surfaceTertiary,
      surfaceInput: surfaceInput ?? this.surfaceInput,
      borderDefault: borderDefault ?? this.borderDefault,
      borderEmphasis: borderEmphasis ?? this.borderEmphasis,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      accentCitation: accentCitation ?? this.accentCitation,
      accentWarning: accentWarning ?? this.accentWarning,
      accentError: accentError ?? this.accentError,
      accentAiGlow: accentAiGlow ?? this.accentAiGlow,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textOnAccent: textOnAccent ?? this.textOnAccent,
    );
  }
}

class AppColors {
  const AppColors._();

  static const AppColorPalette dark = AppColorPalette(
    surfacePrimary: Color(0xFF0D1117),
    surfaceSecondary: Color(0xFF161B22),
    surfaceTertiary: Color(0xFF21262D),
    surfaceInput: Color(0xFF0D1117),
    borderDefault: Color(0xFF30363D),
    borderEmphasis: Color(0xFF484F58),
    accentPrimary: Color(0xFF58A6FF),
    accentSecondary: Color(0xFF3FB950),
    accentCitation: Color(0xFFD2A8FF),
    accentWarning: Color(0xFFD29922),
    accentError: Color(0xFFF85149),
    accentAiGlow: Color(0xFF79C0FF),
    textPrimary: Color(0xFFF0F6FC),
    textSecondary: Color(0xFF8B949E),
    textTertiary: Color(0xFF6E7681),
    textOnAccent: Color(0xFFFFFFFF),
  );

  static const AppColorPalette light = AppColorPalette(
    surfacePrimary: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFF6F8FA),
    surfaceTertiary: Color(0xFFF6F8FA),
    surfaceInput: Color(0xFFFFFFFF),
    borderDefault: Color(0xFF30363D),
    borderEmphasis: Color(0xFF484F58),
    accentPrimary: Color(0xFF58A6FF),
    accentSecondary: Color(0xFF3FB950),
    accentCitation: Color(0xFFD2A8FF),
    accentWarning: Color(0xFFD29922),
    accentError: Color(0xFFF85149),
    accentAiGlow: Color(0xFF79C0FF),
    textPrimary: Color(0xFF1F2328),
    textSecondary: Color(0xFF656D76),
    textTertiary: Color(0xFF656D76),
    textOnAccent: Color(0xFFFFFFFF),
  );
}
