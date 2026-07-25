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

  // ── Dark palette ─ inspired by the drone camera image ──
  // Deep charcoal surfaces with bold orange-red & metallic silver accents.
  static const AppColorPalette dark = AppColorPalette(
    surfacePrimary: Color(0xFF121212),    // deep charcoal (camera body)
    surfaceSecondary: Color(0xFF1C1C1E),  // gunmetal dark layer
    surfaceTertiary: Color(0xFF2C2C2E),   // elevated metallic surface
    surfaceInput: Color(0xFF161618),      // near-black input field
    borderDefault: Color(0xFF3A3A3C),     // brushed metal border
    borderEmphasis: Color(0xFF5A5A5E),    // polished metal focus ring
    accentPrimary: Color(0xFFFF5B2E),     // bold orange-red (background gradient)
    accentSecondary: Color(0xFF8E9AAB),   // cool metallic silver-blue
    accentCitation: Color(0xFFFF9A76),    // soft warm coral
    accentWarning: Color(0xFFFFAB40),     // amber-gold
    accentError: Color(0xFFFF3B30),       // vivid red (lens accent)
    accentAiGlow: Color(0xFFFF6D00),      // vibrant orange glow
    textPrimary: Color(0xFFF2F2F7),       // bright silver-white
    textSecondary: Color(0xFF98989D),     // brushed aluminium grey
    textTertiary: Color(0xFF636366),      // muted steel grey
    textOnAccent: Color(0xFFFFFFFF),
  );

  // ── Light palette ─ clean white/silver surfaces, same accent system ──
  static const AppColorPalette light = AppColorPalette(
    surfacePrimary: Color(0xFFFAFAFA),    // clean white (image bg)
    surfaceSecondary: Color(0xFFF0F0F2),  // light aluminium grey
    surfaceTertiary: Color(0xFFE5E5EA),   // slightly deeper silver
    surfaceInput: Color(0xFFFFFFFF),      // pure white inputs
    borderDefault: Color(0xFFD1D1D6),     // soft metallic border
    borderEmphasis: Color(0xFFA0A0A8),    // polished silver focus
    accentPrimary: Color(0xFFE04820),     // deeper orange for light contrast
    accentSecondary: Color(0xFF6B7685),   // steel grey-blue
    accentCitation: Color(0xFFD4643B),    // muted warm coral
    accentWarning: Color(0xFFE88A00),     // deep amber
    accentError: Color(0xFFD42020),       // strong red
    accentAiGlow: Color(0xFFE05500),      // deep orange glow
    textPrimary: Color(0xFF1C1C1E),       // near-black (camera body tone)
    textSecondary: Color(0xFF48484A),     // dark steel grey
    textTertiary: Color(0xFF6C6C70),      // mid steel grey
    textOnAccent: Color(0xFFFFFFFF),
  );
}
