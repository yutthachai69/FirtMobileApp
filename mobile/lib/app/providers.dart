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
import '../features/create/data/create_api.dart';
import '../features/create/presentation/create_controller.dart';
import '../features/home/data/home_api.dart';
import '../features/home/domain/content_store.dart';
import '../features/home/presentation/home_controller.dart';

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

final connectionsApiProvider = Provider<ConnectionsApi>(
  (ref) => HttpConnectionsApi(ref.watch(apiClientProvider)),
);

final connectionsProvider = Provider<ConnectionsController>((ref) {
  final controller = ConnectionsController(
    ref.watch(authProvider),
    ref.watch(connectionsApiProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final createProvider = Provider<CreateController>((ref) {
  // dio แยกสำหรับยิงไฟล์ขึ้น storage โดยตรง
  // ห้ามใช้ตัวเดียวกับ backend เพราะ presigned URL ต้องไม่มี Authorization ของเราติดไป
  final uploadDio = Dio(BaseOptions(
    // ไฟล์ใหญ่ใช้เวลานาน timeout สั้นจะตัดกลางคัน
    sendTimeout: const Duration(minutes: 10),
    receiveTimeout: const Duration(minutes: 2),
  ));
  ref.onDispose(uploadDio.close);

  final controller = CreateController(
    auth: ref.watch(authProvider),
    api: HttpCreateApi(ref.watch(apiClientProvider), uploadDio),
    connections: ref.watch(connectionsApiProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final homeProvider = Provider<HomeController>((ref) {
  final controller = HomeController(
    ref.watch(authProvider),
    HttpHomeApi(
      ref.watch(apiClientProvider),
      ref.watch(connectionsApiProvider),
    ),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// แหล่งงานคอนเทนต์ตัวเดียวของทั้งแอปในโหมด prototype
/// Home / Content / Notifications และการกดเผยแพร่ ใช้ instance เดียวกันนี้
final contentStoreProvider = Provider<ContentStore>((ref) {
  final store = ContentStore();
  ref.onDispose(store.dispose);
  return store;
});
