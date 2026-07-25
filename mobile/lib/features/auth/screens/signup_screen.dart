import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/auth/providers/auth_provider.dart';
import 'package:documind_ai/features/auth/widgets/auth_branded_scaffold.dart';
import 'package:documind_ai/shared/widgets/accessibility_focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _formError;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
      if (_confirmPasswordController.text.isNotEmpty) {
        _validateConfirmPassword(_confirmPasswordController.text);
      }
      _formError = null;
    });
  }

  void _validateConfirmPassword(String value) {
    setState(() {
      _confirmPasswordError = value == _passwordController.text
          ? null
          : 'Passwords do not match';
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
    _validateConfirmPassword(_confirmPasswordController.text);
    if (_emailError != null || _passwordError != null || _confirmPasswordError != null) {
      return;
    }

    final errors = await ref
        .read(authStateProvider.notifier)
        .signup(
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final authState = ref.watch(authStateProvider);
    final isLoading = authState.isLoading;
    final canSubmit =
        _isValidEmail(_emailController.text.trim()) &&
        _passwordController.text.length >= 12 &&
        _confirmPasswordController.text == _passwordController.text &&
        !isLoading;

    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: tokens.colors.textSecondary,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    );

    return AuthBrandedScaffold(
      title: 'Create your account',
      subtitle: 'Sign up to start uploading and chatting with your docs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('EMAIL', style: labelStyle),
          const SizedBox(height: AppSpacing.xs),
          AccessibilityFocusRing(
            borderRadius: 14,
            padding: const EdgeInsets.all(2),
            child: TextField(
              key: const Key('signup-email-field'),
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
          Text('PASSWORD', style: labelStyle),
          const SizedBox(height: AppSpacing.xs),
          AccessibilityFocusRing(
            borderRadius: 14,
            padding: const EdgeInsets.all(2),
            child: TextField(
              key: const Key('signup-password-field'),
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
          const SizedBox(height: AppSpacing.lg),
          Text('CONFIRM PASSWORD', style: labelStyle),
          const SizedBox(height: AppSpacing.xs),
          AccessibilityFocusRing(
            borderRadius: 14,
            padding: const EdgeInsets.all(2),
            child: TextField(
              key: const Key('signup-confirm-password-field'),
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              onChanged: _validateConfirmPassword,
              decoration: _authInputDecoration(
                context,
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                errorText: _confirmPasswordError,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: tokens.colors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
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
              key: const Key('signup-submit-button'),
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
                        const Text('Create Account'),
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
                'Already have an account? ',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.colors.textSecondary,
                ),
              ),
              InkWell(
                onTap: isLoading ? null : () => context.go('/auth/login'),
                child: Text(
                  'Log in',
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
