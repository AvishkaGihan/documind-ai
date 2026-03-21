import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/auth/data/auth_api.dart';
import 'package:documind_ai/features/auth/providers/auth_provider.dart';
import 'package:documind_ai/features/settings/providers/theme_mode_provider.dart';
import 'package:documind_ai/shared/widgets/app_snackbar.dart';
import 'package:documind_ai/shared/widgets/loading_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      backgroundColor: tokens.colors.surfacePrimary,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildEmailHeader(
            context: context,
            authState: authState,
            tokens: tokens,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SettingsSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tokens.colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _ThemeChoiceButton(
                        key: const Key('settings-theme-dark-button'),
                        label: 'Dark',
                        isSelected: themeMode == ThemeMode.dark,
                        semanticsLabel: 'Use dark theme',
                        onTap: () {
                          ref.read(themeModeProvider.notifier).setDark();
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _ThemeChoiceButton(
                        key: const Key('settings-theme-light-button'),
                        label: 'Light',
                        isSelected: themeMode == ThemeMode.light,
                        semanticsLabel: 'Use light theme',
                        onTap: () {
                          ref.read(themeModeProvider.notifier).setLight();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsActionRow(
            label: 'Reset Password',
            icon: Icons.lock_reset,
            semanticsLabel: 'Reset password',
            enabled: true,
            onTap: () {
              _handleResetPasswordTap(
                context: context,
                ref: ref,
                authState: authState,
                tokens: tokens,
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsActionRow(
            label: 'Delete Account',
            icon: Icons.delete_outline,
            semanticsLabel: 'Delete account option unavailable in this version',
            enabled: false,
            onTap: null,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsActionRow(
            label: 'Logout',
            icon: Icons.logout,
            semanticsLabel: 'Logout',
            enabled: true,
            onTap: () async {
              await ref.read(authStateProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmailHeader({
    required BuildContext context,
    required AsyncValue<AuthState> authState,
    required DocuMindTokens tokens,
  }) {
    final theme = Theme.of(context);

    return Semantics(
      label: _emailSemanticsLabel(authState),
      child: Container(
        key: const Key('settings-email-header'),
        decoration: BoxDecoration(
          color: tokens.colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.colors.borderDefault),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: authState.when(
          data: (value) {
            final email = value.userEmail?.trim();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: tokens.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  email?.isNotEmpty == true ? email! : 'No email available',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tokens.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
          },
          loading: () => const LoadingShimmerBox(width: 220, height: 20),
          error: (_, _) => Text(
            'Unable to load account details',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.colors.accentError,
            ),
          ),
        ),
      ),
    );
  }

  String _emailSemanticsLabel(AsyncValue<AuthState> authState) {
    return authState.when(
      data: (value) =>
          'Account email ${value.userEmail?.trim().isNotEmpty == true ? value.userEmail!.trim() : 'not available'}',
      loading: () => 'Loading account email',
      error: (_, _) => 'Account email failed to load',
    );
  }

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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.colors.borderDefault),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );
  }
}

class _ThemeChoiceButton extends StatelessWidget {
  const _ThemeChoiceButton({
    required this.label,
    required this.isSelected,
    required this.semanticsLabel,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticsLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: isSelected
                ? tokens.colors.accentPrimary.withValues(alpha: 0.2)
                : tokens.colors.surfacePrimary,
            side: BorderSide(
              color: isSelected
                  ? tokens.colors.accentPrimary
                  : tokens.colors.borderDefault,
            ),
            foregroundColor: isSelected
                ? tokens.colors.textPrimary
                : tokens.colors.textSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.lg,
            ),
          ),
          child: Text(label, style: theme.textTheme.labelLarge),
        ),
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.label,
    required this.icon,
    required this.semanticsLabel,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String semanticsLabel;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final foreground = enabled
        ? tokens.colors.textPrimary
        : tokens.colors.textSecondary;

    return Semantics(
      button: enabled,
      enabled: enabled,
      label: semanticsLabel,
      child: Material(
        color: tokens.colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: Key(
            'settings-action-${label.toLowerCase().replaceAll(' ', '-')}',
          ),
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.colors.borderDefault),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(icon, color: foreground),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: enabled
                      ? tokens.colors.textSecondary
                      : tokens.colors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
