import 'dart:ui';

import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

class AuthBrandedScaffold extends StatelessWidget {
  const AuthBrandedScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    return Scaffold(
      backgroundColor: tokens.colors.surfacePrimary,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tokens.colors.surfacePrimary,
                      Color.alphaBlend(
                        tokens.colors.accentPrimary.withAlpha(18),
                        tokens.colors.surfacePrimary,
                      ),
                      Color.alphaBlend(
                        tokens.colors.accentCitation.withAlpha(14),
                        tokens.colors.surfacePrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -90,
              right: -60,
              child: IgnorePointer(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.colors.accentCitation.withAlpha(28),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -80,
              bottom: -120,
              child: IgnorePointer(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.colors.accentPrimary.withAlpha(22),
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.x2l,
                  AppSpacing.xl,
                  AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _AuthWordmark(),
                      const SizedBox(height: AppSpacing.xl),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color.alphaBlend(
                                tokens.colors.surfaceSecondary.withAlpha(140),
                                tokens.colors.surfacePrimary,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: tokens.colors.borderDefault.withAlpha(
                                  180,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    title,
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          color: tokens.colors.textPrimary,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    subtitle,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: tokens.colors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  child,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthWordmark extends StatelessWidget {
  const _AuthWordmark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    return Semantics(
      label: 'DocuMind AI brand header',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DocuMind AI',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: tokens.colors.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Read smarter. Decide faster.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.colors.accentCitation,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
