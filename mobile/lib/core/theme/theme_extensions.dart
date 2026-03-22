import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
class DocuMindTokens extends ThemeExtension<DocuMindTokens> {
  const DocuMindTokens({required this.colors});

  final AppColorPalette colors;

  @override
  DocuMindTokens copyWith({AppColorPalette? colors}) {
    return DocuMindTokens(colors: colors ?? this.colors);
  }

  @override
  DocuMindTokens lerp(
    covariant ThemeExtension<DocuMindTokens>? other,
    double t,
  ) {
    if (other is! DocuMindTokens) {
      return this;
    }

    return DocuMindTokens(
      colors: AppColorPalette(
        surfacePrimary:
            Color.lerp(colors.surfacePrimary, other.colors.surfacePrimary, t) ??
            colors.surfacePrimary,
        surfaceSecondary:
            Color.lerp(
              colors.surfaceSecondary,
              other.colors.surfaceSecondary,
              t,
            ) ??
            colors.surfaceSecondary,
        surfaceTertiary:
            Color.lerp(
              colors.surfaceTertiary,
              other.colors.surfaceTertiary,
              t,
            ) ??
            colors.surfaceTertiary,
        surfaceInput:
            Color.lerp(colors.surfaceInput, other.colors.surfaceInput, t) ??
            colors.surfaceInput,
        borderDefault:
            Color.lerp(colors.borderDefault, other.colors.borderDefault, t) ??
            colors.borderDefault,
        borderEmphasis:
            Color.lerp(colors.borderEmphasis, other.colors.borderEmphasis, t) ??
            colors.borderEmphasis,
        accentPrimary:
            Color.lerp(colors.accentPrimary, other.colors.accentPrimary, t) ??
            colors.accentPrimary,
        accentSecondary:
            Color.lerp(
              colors.accentSecondary,
              other.colors.accentSecondary,
              t,
            ) ??
            colors.accentSecondary,
        accentCitation:
            Color.lerp(colors.accentCitation, other.colors.accentCitation, t) ??
            colors.accentCitation,
        accentWarning:
            Color.lerp(colors.accentWarning, other.colors.accentWarning, t) ??
            colors.accentWarning,
        accentError:
            Color.lerp(colors.accentError, other.colors.accentError, t) ??
            colors.accentError,
        accentAiGlow:
            Color.lerp(colors.accentAiGlow, other.colors.accentAiGlow, t) ??
            colors.accentAiGlow,
        textPrimary:
            Color.lerp(colors.textPrimary, other.colors.textPrimary, t) ??
            colors.textPrimary,
        textSecondary:
            Color.lerp(colors.textSecondary, other.colors.textSecondary, t) ??
            colors.textSecondary,
        textTertiary:
            Color.lerp(colors.textTertiary, other.colors.textTertiary, t) ??
            colors.textTertiary,
        textOnAccent:
            Color.lerp(colors.textOnAccent, other.colors.textOnAccent, t) ??
            colors.textOnAccent,
      ),
    );
  }
}
