import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/auth/data/auth_api.dart';
import 'package:documind_ai/features/auth/providers/auth_flash_message_provider.dart';
import 'package:documind_ai/features/auth/providers/auth_provider.dart';
import 'package:documind_ai/features/settings/data/user_api.dart';
import 'package:documind_ai/features/settings/providers/theme_mode_provider.dart';
import 'package:documind_ai/shared/widgets/app_snackbar.dart';
import 'package:documind_ai/shared/widgets/loading_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Main screen ───────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _staggerController;
  late final AnimationController _glowController;

  // Staggered entrance intervals
  late final Animation<double> _headerAnim;
  late final Animation<double> _themeAnim;
  late final Animation<double> _securityAnim;
  late final Animation<double> _dangerAnim;
  late final Animation<double> _logoutAnim;
  late final Animation<double> _footerAnim;

  @override
  void initState() {
    super.initState();

    // Staggered entrance — 600ms total
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _headerAnim = _buildInterval(0.0, 0.35);
    _themeAnim = _buildInterval(0.10, 0.45);
    _securityAnim = _buildInterval(0.20, 0.55);
    _dangerAnim = _buildInterval(0.30, 0.65);
    _logoutAnim = _buildInterval(0.40, 0.75);
    _footerAnim = _buildInterval(0.55, 0.90);

    _staggerController.forward();

    // Pulsing glow behind avatar — infinite loop
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  Animation<double> _buildInterval(double begin, double end) {
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: tokens.colors.surfacePrimary,
      body: CustomScrollView(
        slivers: [
          // ── Frosted SliverAppBar ──
          SliverAppBar(
            floating: true,
            snap: true,
            expandedHeight: 56,
            backgroundColor: tokens.colors.surfacePrimary,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Settings',
              style: theme.textTheme.titleLarge?.copyWith(
                color: tokens.colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          // ── Body ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Profile header ──
                  _StaggeredEntry(
                    animation: _headerAnim,
                    child: _ProfileHeader(
                      authState: authState,
                      glowAnimation: _glowController,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // ── Appearance section ──
                  _StaggeredEntry(
                    animation: _themeAnim,
                    child: _SectionCard(
                      label: 'Theme',
                      child: _SegmentedThemeToggle(
                        themeMode: themeMode,
                        onDark: () =>
                            ref.read(themeModeProvider.notifier).setDark(),
                        onLight: () =>
                            ref.read(themeModeProvider.notifier).setLight(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // ── Security section ──
                  _StaggeredEntry(
                    animation: _securityAnim,
                    child: _SectionCard(
                      label: 'Security',
                      child: _ActionTile(
                        actionKey: const Key('settings-action-reset-password'),
                        label: 'Reset Password',
                        subtitle: 'Send a password reset email',
                        icon: Icons.lock_reset_rounded,
                        iconColor: tokens.colors.accentPrimary,
                        semanticsLabel: 'Reset password',
                        onTap: () => _handleResetPasswordTap(
                          context: context,
                          ref: ref,
                          authState: authState,
                          tokens: tokens,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // ── Danger zone ──
                  _StaggeredEntry(
                    animation: _dangerAnim,
                    child: _DangerZoneCard(
                      child: _ActionTile(
                        actionKey: const Key('settings-action-delete-account'),
                        label: 'Delete Account',
                        subtitle: 'Permanently remove all data',
                        icon: Icons.delete_forever_rounded,
                        iconColor: tokens.colors.accentError,
                        semanticsLabel: 'Delete account',
                        onTap: () => _showDeleteAccountDialog(
                          context: context,
                          ref: ref,
                          tokens: tokens,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Sign Out button ──
                  _StaggeredEntry(
                    animation: _logoutAnim,
                    child: _SignOutButton(
                      onTap: () async {
                        await ref.read(authStateProvider.notifier).logout();
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Footer ──
                  _StaggeredEntry(
                    animation: _footerAnim,
                    child: const _AppInfoFooter(),
                  ),
                  const SizedBox(height: AppSpacing.x2l),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Business logic (preserved exactly) ──────────────────────────────────

  Future<void> _handleResetPasswordTap({
    required BuildContext context,
    required WidgetRef ref,
    required AsyncValue<AuthState> authState,
    required DocuMindTokens tokens,
  }) async {
    if (authState.isLoading || authState.hasError) {
      showWarningSnackBar(
        context,
        tokens,
        'Account details are still loading. Please try again.',
      );
      return;
    }

    final email = authState.value?.userEmail?.trim();
    if (email == null || email.isEmpty) {
      showWarningSnackBar(
        context,
        tokens,
        'No account email is available for password reset.',
      );
      return;
    }

    await _showResetPasswordDialog(
      context: context,
      ref: ref,
      email: email,
      tokens: tokens,
    );
  }

  Future<void> _showResetPasswordDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String email,
    required DocuMindTokens tokens,
  }) async {
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submitResetRequest() async {
              setDialogState(() {
                isSubmitting = true;
              });

              try {
                await ref.read(authApiProvider).resetPassword(email: email);

                if (!dialogContext.mounted || !context.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();
                _showSuccessSnackBar(context, tokens);
              } on AuthApiError catch (error) {
                if (!dialogContext.mounted || !context.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();
                showPersistentErrorSnackBar(context, tokens, error.message);
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    isSubmitting = false;
                  });
                }
              }
            }

            return AlertDialog(
              backgroundColor: tokens.colors.surfaceSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text('Reset Password'),
              content: Text('A password reset email will be sent to $email.'),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  style: TextButton.styleFrom(minimumSize: const Size(80, 44)),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : submitResetRequest,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(90, 44),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteAccountDialog({
    required BuildContext context,
    required WidgetRef ref,
    required DocuMindTokens tokens,
  }) async {
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submitDeletion() async {
              setDialogState(() {
                isSubmitting = true;
              });

              try {
                await ref.read(userApiProvider).deleteMe();

                if (!dialogContext.mounted || !context.mounted) {
                  return;
                }

                ref
                    .read(authFlashMessageProvider.notifier)
                    .setMessage('Your account has been deleted.');
                Navigator.of(dialogContext).pop();
                await ref.read(authStateProvider.notifier).logout();
              } on UserApiError catch (error) {
                if (!dialogContext.mounted || !context.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();
                showPersistentErrorSnackBar(context, tokens, error.message);
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    isSubmitting = false;
                  });
                }
              }
            }

            return AlertDialog(
              backgroundColor: tokens.colors.surfaceSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: tokens.colors.accentError,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Delete Account',
                    style: Theme.of(dialogContext).textTheme.titleLarge
                        ?.copyWith(color: tokens.colors.accentError),
                  ),
                ],
              ),
              content: const Text(
                'This will permanently delete your account. Documents, embeddings, and conversations will also be deleted. This action cannot be undone.',
              ),
              actions: [
                Semantics(
                  button: true,
                  enabled: !isSubmitting,
                  label: 'Cancel account deletion',
                  child: TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                          },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(80, 44),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                Semantics(
                  button: true,
                  enabled: !isSubmitting,
                  label: 'Confirm account deletion',
                  child: FilledButton(
                    onPressed: isSubmitting ? null : submitDeletion,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(90, 44),
                      backgroundColor: tokens.colors.accentError,
                      foregroundColor: tokens.colors.textOnAccent,
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Delete'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSuccessSnackBar(BuildContext context, DocuMindTokens tokens) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          backgroundColor: tokens.colors.accentSecondary,
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'If an account exists, a password reset email has been sent.',
                ),
              ),
            ],
          ),
        ),
      );
  }
}

// ─── Staggered entrance wrapper ────────────────────────────────────────────

class _StaggeredEntry extends StatelessWidget {
  const _StaggeredEntry({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return child;
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final val = animation.value.clamp(0.05, 1.0);
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// ─── Profile header with gradient ring avatar ──────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.authState,
    required this.glowAnimation,
  });

  final AsyncValue<AuthState> authState;
  final Animation<double> glowAnimation;

  String _initials(String? email) {
    if (email == null || email.isEmpty) return '?';
    final parts = email.split('@');
    final name = parts.first;
    if (name.length >= 2) {
      return name.substring(0, 2).toUpperCase();
    }
    return name.toUpperCase();
  }

  String _emailSemanticsLabel() {
    return authState.when(
      data: (value) =>
          'Account email ${value.userEmail?.trim().isNotEmpty == true ? value.userEmail!.trim() : 'not available'}',
      loading: () => 'Loading account email',
      error: (_, _) => 'Account email failed to load',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    return Semantics(
      label: _emailSemanticsLabel(),
      child: Container(
        key: const Key('settings-email-header'),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [
              tokens.colors.accentPrimary.withValues(alpha: 0.08),
              tokens.colors.accentAiGlow.withValues(alpha: 0.03),
              tokens.colors.surfacePrimary.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: authState.when(
          data: (value) {
            final email = value.userEmail?.trim();
            final initials = _initials(email);

            return Column(
              children: [
                // ── Avatar with gradient ring + pulsing glow ──
                AnimatedBuilder(
                  animation: glowAnimation,
                  builder: (context, child) {
                    final glowOpacity =
                        0.15 + (glowAnimation.value * 0.2);
                    final glowSpread = 8.0 + (glowAnimation.value * 12.0);

                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: tokens.colors.accentPrimary
                                .withValues(alpha: glowOpacity),
                            blurRadius: glowSpread * 2,
                            spreadRadius: glowSpread * 0.3,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          tokens.colors.accentPrimary,
                          tokens.colors.accentAiGlow,
                          tokens.colors.accentCitation,
                          tokens.colors.accentPrimary,
                        ],
                        stops: const [0.0, 0.35, 0.7, 1.0],
                      ),
                    ),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tokens.colors.surfaceSecondary,
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: tokens.colors.accentPrimary,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── Email ──
                Text(
                  email?.isNotEmpty == true ? email! : 'No email available',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tokens.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── Verified badge ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: tokens.colors.accentSecondary
                        .withValues(alpha: 0.15),
                    border: Border.all(
                      color: tokens.colors.accentSecondary
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: tokens.colors.accentSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.colors.accentSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: LoadingShimmerBox(width: 220, height: 20),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              'Unable to load account details',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.colors.accentError,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Section card wrapper ──────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tokens.colors.borderDefault.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: tokens.colors.textTertiary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          child,
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

// ─── Danger zone card (red tinted) ─────────────────────────────────────────

class _DangerZoneCard extends StatelessWidget {
  const _DangerZoneCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.accentError.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tokens.colors.accentError.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: tokens.colors.accentError.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  'DANGER ZONE',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tokens.colors.accentError.withValues(alpha: 0.7),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          child,
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

// ─── Segmented theme toggle ────────────────────────────────────────────────

class _SegmentedThemeToggle extends StatelessWidget {
  const _SegmentedThemeToggle({
    required this.themeMode,
    required this.onDark,
    required this.onLight,
  });

  final ThemeMode themeMode;
  final VoidCallback onDark;
  final VoidCallback onLight;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: tokens.colors.surfacePrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tokens.colors.borderDefault.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _ThemeSegment(
                key: const Key('settings-theme-dark-button'),
                icon: Icons.dark_mode_rounded,
                label: 'Dark',
                isSelected: themeMode == ThemeMode.dark,
                semanticsLabel: 'Use dark theme',
                onTap: onDark,
              ),
            ),
            Expanded(
              child: _ThemeSegment(
                key: const Key('settings-theme-light-button'),
                icon: Icons.light_mode_rounded,
                label: 'Light',
                isSelected: themeMode == ThemeMode.light,
                semanticsLabel: 'Use light theme',
                onTap: onLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSegment extends StatelessWidget {
  const _ThemeSegment({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.semanticsLabel,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: isSelected
                ? tokens.colors.accentPrimary
                : Colors.transparent,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: tokens.colors.accentPrimary
                          .withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: -2,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    icon,
                    key: ValueKey('$label-$isSelected'),
                    size: 18,
                    color: isSelected
                        ? tokens.colors.textOnAccent
                        : tokens.colors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? tokens.colors.textOnAccent
                        : tokens.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Action tile with colored icon container ───────────────────────────────

class _ActionTile extends StatefulWidget {
  const _ActionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.semanticsLabel,
    required this.onTap,
    this.actionKey,
  });

  final Key? actionKey;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    return Semantics(
      button: true,
      enabled: true,
      label: widget.semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: widget.actionKey,
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          onHighlightChanged: (pressed) {
            setState(() => _isPressed = pressed);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                // ── Icon container ──
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: widget.iconColor.withValues(alpha: 0.12),
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      size: 20,
                      color: widget.iconColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // ── Label + subtitle ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: tokens.colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: tokens.colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Chevron with press animation ──
                AnimatedPadding(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.only(
                    left: _isPressed ? 4 : 0,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: tokens.colors.textTertiary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sign out button ───────────────────────────────────────────────────────

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return Semantics(
      button: true,
      label: 'Sign out',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('settings-action-logout'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: tokens.colors.borderDefault.withValues(alpha: 0.6),
              ),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: tokens.colors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Logout',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── App info footer ───────────────────────────────────────────────────────

class _AppInfoFooter extends StatelessWidget {
  const _AppInfoFooter();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return Column(
      children: [
        // ── Decorative divider ──
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: [
                tokens.colors.accentPrimary.withValues(alpha: 0.4),
                tokens.colors.accentAiGlow.withValues(alpha: 0.4),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'DocuMind AI',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: tokens.colors.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'v1.0.0',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: tokens.colors.textTertiary.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
