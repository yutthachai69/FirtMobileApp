import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/auth/auth_controller.dart';
import '../core/config/app_config.dart';
import '../core/storage/token_store.dart';
import '../features/auth/data/auth_api.dart';

final authProvider = Provider<AuthController>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ),
  );
  final controller = AuthController(
    HttpAuthApi(dio),
    SecureTokenStore(const FlutterSecureStorage()),
  );
  ref.onDispose(() {
    controller.dispose();
    dio.close();
  });
  return controller;
});
