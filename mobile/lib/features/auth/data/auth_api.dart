import 'package:dio/dio.dart';
import 'package:documind_ai/core/networking/dio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthApiError implements Exception {
  const AuthApiError({required this.code, required this.message, this.field});

  final String code;
  final String message;
  final String? field;
}

class AuthUser {
  const AuthUser({required this.id, required this.email});

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(id: json['id'] as String, email: json['email'] as String);
  }

  final String id;
  final String email;
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String,
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
}

class AuthResponse {
  const AuthResponse({required this.user, required this.tokens});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      tokens: AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>),
    );
  }

  final AuthUser user;
  final AuthTokens tokens;
}

class AuthApi {
  const AuthApi(this._dio);

  final Dio _dio;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {'email': email, 'password': password},
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<AuthResponse> signup({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/signup',
        data: {'email': email, 'password': password},
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/reset-password',
        data: {'email': email},
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  AuthApiError _mapError(DioException error) {
    final dynamic data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is Map<String, dynamic>) {
        return AuthApiError(
          code: detail['code'] as String? ?? 'UNKNOWN_ERROR',
          message: detail['message'] as String? ?? 'Something went wrong.',
          field: detail['field'] as String?,
        );
      }
    }

    return const AuthApiError(
      code: 'NETWORK_ERROR',
      message: 'Unable to reach the server. Please try again.',
    );
  }
}

final authApiProvider = Provider<AuthApi>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthApi(dio);
});
