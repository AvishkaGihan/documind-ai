import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/auth/data/auth_api.dart';
import 'package:documind_ai/features/auth/providers/auth_provider.dart';
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

    return Scaffold(
      backgroundColor: tokens.colors.surfacePrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome back',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: tokens.colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Log in to continue to your document library.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl),
                  TextField(
                    key: const Key('login-email-field'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: _validateEmail,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      errorText: _emailError,
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg),
                  TextField(
                    key: const Key('login-password-field'),
                    controller: _passwordController,
                    obscureText: true,
                    onChanged: _validatePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      errorText: _passwordError,
                    ),
                  ),
                  if (_formError != null) ...[
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      _formError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.colors.accentError,
                      ),
                    ),
                  ],
                  SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      key: const Key('login-submit-button'),
                      onPressed: canSubmit ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Login'),
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 44,
                    child: TextButton(
                      onPressed: isLoading ? null : _showForgotPasswordSheet,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: TextButton(
                      onPressed: isLoading
                          ? null
                          : () => context.go('/auth/signup'),
                      child: const Text('Create an account'),
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
