import 'package:dio/dio.dart';

/// AppException คือ error รูปแบบเดียวที่ UI ต้องรู้จัก
///
/// backend ตอบรูปแบบเดียวกันหมด:
///   {"error": {"code": "...", "message": "...", "details": {...}}}
///
/// `message` เป็นภาษาไทยที่แสดงให้ผู้ใช้เห็นได้เลย
/// `code` ให้หน้าจอตัดสินใจ เช่น CONNECTION_NEEDS_REAUTH → พาไปหน้า Connections
class AppException implements Exception {
  const AppException({
    required this.code,
    required this.message,
    this.details = const {},
    this.statusCode,
  });

  final String code;
  final String message;
  final Map<String, dynamic> details;
  final int? statusCode;

  /// ผู้ใช้ต้องไปเชื่อมบัญชีใหม่
  bool get needsReauth => code == 'CONNECTION_NEEDS_REAUTH';

  /// เซสชันของระบบเราหมดอายุ ต้องล็อกอินใหม่
  bool get sessionExpired =>
      code == 'UNAUTHORIZED' ||
      code == 'REFRESH_TOKEN_INVALID' ||
      code == 'REFRESH_TOKEN_REUSED';

  /// ฟีเจอร์นี้ยังไม่ได้ตั้งค่าฝั่งเซิร์ฟเวอร์
  bool get notConfigured => code == 'PROVIDER_NOT_CONFIGURED';

  /// เหตุผลละเอียดจาก backend เช่น "รหัสผ่านต้องยาวอย่างน้อย 8 ตัวอักษร"
  String? get reason => details['reason'] as String?;

  /// ข้อความที่ควรโชว์ให้ผู้ใช้ — ใช้เหตุผลละเอียดถ้ามี
  String get displayMessage => reason ?? message;

  @override
  String toString() => 'AppException($code): $message';

  /// แปลง DioException เป็น AppException
  ///
  /// ทุกกรณีต้องได้ข้อความภาษาไทยที่บอกว่าให้ทำอะไรต่อ
  /// ห้ามปล่อยให้ผู้ใช้เห็น "SocketException" หรือ "status code 500"
  factory AppException.from(Object error) {
    if (error is AppException) return error;

    if (error is! DioException) {
      return const AppException(
        code: 'UNKNOWN',
        message: 'เกิดข้อผิดพลาดที่ไม่คาดคิด กรุณาลองใหม่',
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppException(
          code: 'TIMEOUT',
          message: 'เชื่อมต่อช้าเกินไป กรุณาลองใหม่',
        );
      case DioExceptionType.connectionError:
        return const AppException(
          code: 'NETWORK_ERROR',
          message: 'เชื่อมต่อไม่ได้ ตรวจสอบอินเทอร์เน็ตของคุณ',
        );
      case DioExceptionType.cancel:
        return const AppException(code: 'CANCELLED', message: 'ยกเลิกแล้ว');
      default:
        break;
    }

    final status = error.response?.statusCode;
    final body = error.response?.data;

    if (body is Map && body['error'] is Map) {
      final e = Map<String, dynamic>.from(body['error'] as Map);
      return AppException(
        code: (e['code'] as String?) ?? 'UNKNOWN',
        message: (e['message'] as String?) ?? 'เกิดข้อผิดพลาด',
        details: e['details'] is Map
            ? Map<String, dynamic>.from(e['details'] as Map)
            : const {},
        statusCode: status,
      );
    }

    // เซิร์ฟเวอร์ตอบมาในรูปแบบที่เราไม่รู้จัก — ยังต้องบอกผู้ใช้เป็นภาษาคน
    return AppException(
      code: 'HTTP_$status',
      message: status != null && status >= 500
          ? 'ระบบขัดข้องชั่วคราว กรุณาลองใหม่'
          : 'คำขอไม่สำเร็จ กรุณาลองใหม่',
      statusCode: status,
    );
  }
}
