import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/auth/data/auth_api.dart';
import 'package:documind_ai/features/auth/providers/auth_flash_message_provider.dart';
import 'package:documind_ai/features/auth/providers/auth_provider.dart';
import 'package:documind_ai/features/auth/widgets/auth_branded_scaffold.dart';
import 'package:documind_ai/shared/widgets/accessibility_focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _emailError;
  String? _passwordError;
  String? _formError;

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAuthFlashMessageIfPresent();
    });
  }

  void _showAuthFlashMessageIfPresent() {
    if (!mounted) {
      return;
    }

    final message = ref.read(authFlashMessageProvider);
    if (message == null || message.isEmpty) {
      return;
    }

    final tokens = Theme.of(context).extension<DocuMindTokens>()!;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          backgroundColor: tokens.colors.accentSecondary,
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );

    ref.read(authFlashMessageProvider.notifier).clear();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateEmail(String value) {
    setState(() {
      _emailError = _isValidEmail(value) ? null : 'Enter a valid email address';
      _formError = null;
    });
  }

  void _validatePassword(String value) {
    setState(() {
      _passwordError = value.length >= 12
          ? null
          : 'Password must be at least 12 characters';
      _formError = null;
    });
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  InputDecoration _authInputDecoration(
    BuildContext context, {
    String? hintText,
    String? errorText,
    Widget? prefixIcon,
  }) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: tokens.colors.borderDefault),
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: theme.textTheme.bodyMedium?.copyWith(
        color: tokens.colors.textSecondary.withAlpha(120),
      ),
      errorText: errorText,
      prefixIcon: prefixIcon,
      prefixIconColor: tokens.colors.textSecondary,
      filled: true,
      fillColor: Color.alphaBlend(
        tokens.colors.surfaceInput.withAlpha(230),
        tokens.colors.surfaceSecondary,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: tokens.colors.accentPrimary, width: 1.8),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: tokens.colors.accentPrimary, width: 1.8),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: tokens.colors.accentError),
      ),
    );
  }

  ButtonStyle _primaryButtonStyle(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(Size.fromHeight(44)),
      shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) {
          return tokens.colors.accentPrimary.withAlpha(92);
        }
        if (states.contains(WidgetState.hovered)) {
          return tokens.colors.accentPrimary.withAlpha(56);
        }
        if (states.contains(WidgetState.focused)) {
          return tokens.colors.accentPrimary.withAlpha(66);
        }
        return null;
      }),
      elevation: WidgetStateProperty.resolveWith<double?>((states) {
        if (states.contains(WidgetState.pressed)) {
          return 0;
        }
        if (states.contains(WidgetState.hovered)) {
          return 2;
        }
        return 1;
      }),
    );
  }

  Future<void> _submit() async {
    _validateEmail(_emailController.text.trim());
    _validatePassword(_passwordController.text);
    if (_emailError != null || _passwordError != null) {
      return;
    }

    final errors = await ref
        .read(authStateProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    if (errors == null) {
      context.go('/library');
      return;
    }

    setState(() {
      _emailError = errors.email ?? _emailError;
      _passwordError = errors.password ?? _passwordError;
      _formError = errors.form;
    });
  }

  Future<void> _showForgotPasswordSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final emailController = TextEditingController();
        String? emailError;
        String? formMessage;
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submitResetRequest() async {
              final email = emailController.text.trim();
              if (!_isValidEmail(email)) {
                setSheetState(() {
                  emailError = 'Enter a valid email address';
                  formMessage = null;
                });
                return;
              }

              setSheetState(() {
                isSubmitting = true;
                emailError = null;
                formMessage = null;
              });

              try {
                await ref.read(authApiProvider).resetPassword(email: email);
                setSheetState(() {
                  formMessage =
                      'If an account exists, a password reset email has been sent.';
                });
              } on AuthApiError catch (error) {
                setSheetState(() {
                  formMessage = error.message;
                });
              } finally {
                setSheetState(() {
                  isSubmitting = false;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.xl,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Reset Password',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      errorText: emailError,
                    ),
                  ),
                  if (formMessage != null) ...[
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      formMessage!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : submitResetRequest,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send Reset Email'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final authState = ref.watch(authStateProvider);
    final isLoading = authState.isLoading;
    final canSubmit =
        _isValidEmail(_emailController.text.trim()) &&
        _passwordController.text.length >= 12 &&
        !isLoading;

    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: tokens.colors.textSecondary,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    );

    return AuthBrandedScaffold(
      title: 'Welcome back',
      subtitle: 'Log in to continue to your document library',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('EMAIL', style: labelStyle),
          const SizedBox(height: AppSpacing.xs),
          AccessibilityFocusRing(
            borderRadius: 14,
            padding: const EdgeInsets.all(2),
            child: TextField(
              key: const Key('login-email-field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              onChanged: _validateEmail,
              decoration: _authInputDecoration(
                context,
                hintText: 'name@company.com',
                prefixIcon: const Icon(Icons.mail_outline, size: 20),
                errorText: _emailError,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text('PASSWORD', style: labelStyle),
              const Spacer(),
              TextButton(
                onPressed: isLoading ? null : _showForgotPasswordSheet,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Forgot password?',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          AccessibilityFocusRing(
            borderRadius: 14,
            padding: const EdgeInsets.all(2),
            child: TextField(
              key: const Key('login-password-field'),
              controller: _passwordController,
              obscureText: _obscurePassword,
              onChanged: _validatePassword,
              decoration: _authInputDecoration(
                context,
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                errorText: _passwordError,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: tokens.colors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
          ),
          if (_formError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _formError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.colors.accentError,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.x2l),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              key: const Key('login-submit-button'),
              onPressed: canSubmit ? _submit : null,
              style: _primaryButtonStyle(context),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Login to Library'),
                        const SizedBox(width: AppSpacing.sm),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),
          Divider(height: 1, color: tokens.colors.borderDefault.withAlpha(100)),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.colors.textSecondary,
                ),
              ),
              InkWell(
                onTap: isLoading ? null : () => context.go('/auth/signup'),
                child: Text(
                  'Create an account',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
