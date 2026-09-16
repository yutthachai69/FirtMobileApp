import 'package:dio/dio.dart';

import '../../features/auth/domain/session.dart';

/// ApiClient แปลง error ของ dio เป็น [AuthFailure] ให้ทั้งแอปใช้แบบเดียวกัน
///
/// ทำไมต้องเป็น AuthFailure: [AuthController.authorized] ดักชนิดนี้เพื่อรู้ว่า
/// เจอ 401 แล้วต้องต่ออายุ token — ถ้า API แต่ละตัวโยน error คนละชนิด
/// การต่ออายุอัตโนมัติจะไม่ทำงาน
///
/// backend ตอบรูปแบบเดียวกันหมด:
///   {"error": {"code": "...", "message": "...", "details": {"reason": "..."}}}
class ApiClient {
  const ApiClient(this.dio);
  final Dio dio;

  Future<Map<String, dynamic>> get(
    String path, {
    required String access,
    Map<String, dynamic>? query,
  }) => _send(path, method: 'GET', access: access, query: query);

  Future<Map<String, dynamic>> post(
    String path, {
    required String access,
    Object? body,
    Map<String, String>? headers,
  }) =>
      _send(path, method: 'POST', access: access, body: body, headers: headers);

  Future<Map<String, dynamic>> patch(
    String path, {
    required String access,
    Object? body,
  }) => _send(path, method: 'PATCH', access: access, body: body);

  Future<Map<String, dynamic>> delete(
    String path, {
    required String access,
    Object? body,
  }) => _send(path, method: 'DELETE', access: access, body: body);

  Future<Map<String, dynamic>> _send(
    String path, {
    required String method,
    required String access,
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await dio.request<Map<String, dynamic>>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer $access', ...?headers},
        ),
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      throw failureFrom(error);
    }
  }
}

/// failureFrom แปลง DioException เป็นข้อความภาษาไทยที่บอกว่าให้ทำอะไรต่อ
///
/// ห้ามปล่อยให้ผู้ใช้เห็น "SocketException" หรือ "status code 500"
AuthFailure failureFrom(DioException error) {
  final status = error.response?.statusCode;
  final data = error.response?.data;
  final detail = data is Map ? data['error'] : null;

  final code = detail is Map ? detail['code'] as String? : null;

  // เหตุผลละเอียดจาก backend มีประโยชน์กว่าข้อความกลาง ๆ
  // เช่น "วิดีโอยาวเกิน 10 นาที" ดีกว่า "ข้อมูลที่ส่งมาไม่ถูกต้อง"
  final reason = detail is Map && detail['details'] is Map
      ? (detail['details'] as Map)['reason'] as String?
      : null;

  final message = switch (status) {
    null => 'เชื่อมต่อไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
    429 => 'ลองหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่',
    _ =>
      reason ??
          (detail is Map && detail['message'] is String
              ? detail['message'] as String
              : 'ระบบขัดข้องชั่วคราว กรุณาลองใหม่'),
  };

  return AuthFailure(message, status: status, code: code);
}

extension AuthFailureX on AuthFailure {
  /// ผู้ใช้ต้องไปเชื่อมบัญชีแพลตฟอร์มใหม่ (คนละเรื่องกับ session ของแอป)
  bool get needsReauth => code == 'CONNECTION_NEEDS_REAUTH';

  /// เซิร์ฟเวอร์ยังไม่ได้ตั้งค่าแพลตฟอร์มนี้
  bool get notConfigured => code == 'PROVIDER_NOT_CONFIGURED';
}
