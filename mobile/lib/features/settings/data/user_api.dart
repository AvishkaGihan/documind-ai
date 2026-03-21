import 'package:dio/dio.dart';
import 'package:documind_ai/core/networking/dio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserApiError implements Exception {
  const UserApiError({required this.code, required this.message, this.field});

  final String code;
  final String message;
  final String? field;
}

class UserApi {
  const UserApi(this._dio);

  final Dio _dio;

  Future<void> deleteMe() async {
    try {
      await _dio.delete<void>('/api/v1/user/me');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  UserApiError _mapError(DioException error) {
    final dynamic data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is Map<String, dynamic>) {
        return UserApiError(
          code: detail['code'] as String? ?? 'UNKNOWN_ERROR',
          message: detail['message'] as String? ?? 'Something went wrong.',
          field: detail['field'] as String?,
        );
      }
    }

    return const UserApiError(
      code: 'NETWORK_ERROR',
      message: 'Unable to reach the server. Please try again.',
    );
  }
}

final userApiProvider = Provider<UserApi>((ref) {
  final dio = ref.watch(dioProvider);
  return UserApi(dio);
});
