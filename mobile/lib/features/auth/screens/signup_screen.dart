import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/auth/providers/auth_provider.dart';
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
                    'Create your account',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: tokens.colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Sign up to start uploading and chatting with your docs.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl),
                  TextField(
                    key: const Key('signup-email-field'),
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
                    key: const Key('signup-password-field'),
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
                      key: const Key('signup-submit-button'),
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
                          : const Text('Sign Up'),
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 44,
                    child: TextButton(
                      onPressed: isLoading
                          ? null
                          : () => context.go('/auth/login'),
                      child: const Text('Already have an account? Log in'),
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
