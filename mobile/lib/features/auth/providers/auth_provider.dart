import 'dart:async';
import 'dart:convert';

import 'package:documind_ai/features/auth/data/auth_api.dart';
import 'package:documind_ai/features/auth/data/token_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class AuthState {
  const AuthState({required this.isAuthenticated, this.userEmail});

  final bool isAuthenticated;
  final String? userEmail;

  const AuthState.unauthenticated() : this(isAuthenticated: false);

  const AuthState.authenticated({required String? email})
    : this(isAuthenticated: true, userEmail: email);
}

@immutable
class AuthFormErrors {
  const AuthFormErrors({this.email, this.password, this.form});

  final String? email;
  final String? password;
  final String? form;
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  FutureOr<AuthState> build() async {
    final tokenStorage = ref.read(tokenStorageProvider);
    final session = await tokenStorage.readSession();

    if (session == null || _isJwtExpired(session.accessToken)) {
      await tokenStorage.clear();
      return const AuthState.unauthenticated();
    }

    return AuthState.authenticated(email: session.email);
  }

  Future<AuthFormErrors?> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading<AuthState>();
    final tokenStorage = ref.read(tokenStorageProvider);
    final authApi = ref.read(authApiProvider);

    try {
      final response = await authApi.login(email: email, password: password);
      await tokenStorage.writeSession(
        accessToken: response.tokens.accessToken,
        refreshToken: response.tokens.refreshToken,
        userId: response.user.id,
        email: response.user.email,
      );
      state = AsyncData(AuthState.authenticated(email: response.user.email));
      return null;
    } on AuthApiError catch (error) {
      final authErrors = _mapAuthError(error);
      state = const AsyncData(AuthState.unauthenticated());
      return authErrors;
    }
  }

  Future<AuthFormErrors?> signup({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading<AuthState>();
    final tokenStorage = ref.read(tokenStorageProvider);
    final authApi = ref.read(authApiProvider);

    try {
      final response = await authApi.signup(email: email, password: password);
      await tokenStorage.writeSession(
        accessToken: response.tokens.accessToken,
        refreshToken: response.tokens.refreshToken,
        userId: response.user.id,
        email: response.user.email,
      );
      state = AsyncData(AuthState.authenticated(email: response.user.email));
      return null;
    } on AuthApiError catch (error) {
      final authErrors = _mapAuthError(error);
      state = const AsyncData(AuthState.unauthenticated());
      return authErrors;
    }
  }

  Future<void> logout() async {
    state = const AsyncLoading<AuthState>();
    final tokenStorage = ref.read(tokenStorageProvider);
    await tokenStorage.clear();
    state = const AsyncData(AuthState.unauthenticated());
  }

  AuthFormErrors _mapAuthError(AuthApiError error) {
    if (error.code == 'EMAIL_ALREADY_EXISTS') {
      return AuthFormErrors(email: error.message);
    }
    if (error.code == 'INVALID_CREDENTIALS') {
      return AuthFormErrors(password: error.message);
    }
    if (error.code == 'VALIDATION_ERROR' && error.field == 'email') {
      return AuthFormErrors(email: error.message);
    }
    if (error.code == 'VALIDATION_ERROR' && error.field == 'password') {
      return AuthFormErrors(password: error.message);
    }

    return AuthFormErrors(form: error.message);
  }

  bool _isJwtExpired(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return true;
    }

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final payloadMap = jsonDecode(payload) as Map<String, dynamic>;
      final exp = payloadMap['exp'];
      if (exp is! int) {
        return true;
      }

      final expiry = DateTime.fromMillisecondsSinceEpoch(
        exp * 1000,
        isUtc: true,
      );
      return DateTime.now().toUtc().isAfter(expiry);
    } catch (_) {
      return true;
    }
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
