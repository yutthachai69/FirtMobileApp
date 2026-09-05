import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/auth/auth_controller.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/storage/token_store.dart';
import '../features/auth/data/auth_api.dart';
import '../features/connections/data/connections_api.dart';
import '../features/connections/presentation/connections_controller.dart';

/// dio ตัวเดียวใช้ร่วมกันทั้งแอป
///
/// แยกออกมาเป็น provider เพราะทุก feature ต้องยิงไป backend ตัวเดียวกัน
/// ถ้าแต่ละ feature สร้าง Dio เอง การตั้งค่า timeout/baseUrl จะหลุดจากกัน
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(dioProvider)),
);

final authProvider = Provider<AuthController>((ref) {
  final controller = AuthController(
    HttpAuthApi(ref.watch(dioProvider)),
    SecureTokenStore(const FlutterSecureStorage()),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final connectionsProvider = Provider<ConnectionsController>((ref) {
  final controller = ConnectionsController(
    ref.watch(authProvider),
    HttpConnectionsApi(ref.watch(apiClientProvider)),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
