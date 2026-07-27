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
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Center(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.xl,
                              AppSpacing.x2l,
                              AppSpacing.xl,
                              AppSpacing.xl,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const _AuthWordmark(),
                                  const SizedBox(height: AppSpacing.x2l),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: tokens.colors.surfaceSecondary.withAlpha(140),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: tokens.colors.borderDefault.withAlpha(150),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(AppSpacing.x2l),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            title,
                                            style: theme.textTheme.headlineMedium
                                                ?.copyWith(
                                                  color: tokens.colors.textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: AppSpacing.sm),
                                          Text(
                                            subtitle,
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                              color: tokens.colors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.x2l),
                                          child,
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.x3l),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.security_outlined,
                                        size: 16,
                                        color: tokens.colors.textSecondary,
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(
                                        'End-to-End Encrypted Data Processing',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: tokens.colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.xl,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: tokens.colors.borderDefault.withAlpha(100),
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '© 2026 DocuMind AI. Secure Intelligence.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: tokens.colors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: AppSpacing.lg,
                                  runSpacing: AppSpacing.sm,
                                  children: [
                                    Text(
                                      'Privacy Policy',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: tokens.colors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Terms of Service',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: tokens.colors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Security Architecture',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: tokens.colors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(
            Icons.shield,
            color: tokens.colors.accentCitation,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'DocuMind AI',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: tokens.colors.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
