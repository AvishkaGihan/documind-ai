import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:documind_ai/features/auth/data/token_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiBaseUrlProvider = Provider<String>((ref) {
  const configured = String.fromEnvironment(
    'DOCUMIND_API_BASE_URL',
    defaultValue: '',
  );
  if (configured.isNotEmpty) {
    return configured;
  }

  if (!kIsWeb && Platform.isAndroid) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://localhost:8000';
});

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      headers: const {'Accept': 'application/json'},
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final session = await tokenStorage.readSession();
        if (session != null && session.accessToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
        if (options.data is FormData) {
          options.headers.remove(Headers.contentTypeHeader);
        }
        handler.next(options);
      },
    ),
  );

  return dio;
});
