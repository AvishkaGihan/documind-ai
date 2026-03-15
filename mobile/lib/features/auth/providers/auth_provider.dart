import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class AuthState {
  const AuthState({required this.isAuthenticated});

  final bool isAuthenticated;
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  FutureOr<AuthState> build() {
    const debugAuthenticated = bool.fromEnvironment(
      'DOCUMIND_DEBUG_AUTH',
      defaultValue: false,
    );
    return const AuthState(isAuthenticated: debugAuthenticated);
  }

  Future<void> setAuthenticated(bool isAuthenticated) async {
    state = AsyncData(AuthState(isAuthenticated: isAuthenticated));
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
