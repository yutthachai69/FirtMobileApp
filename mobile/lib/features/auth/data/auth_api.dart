import 'package:dio/dio.dart';

import '../domain/session.dart';

abstract interface class AuthApi {
  Future<AuthResult> login(String email, String password);
  Future<AuthResult> register(String email, String password, String name);
  Future<SessionTokens> refresh(String token);
  Future<Account> me(String accessToken);
  Future<void> logout(String refreshToken);
}

class HttpAuthApi implements AuthApi {
  HttpAuthApi(this.dio);
  final Dio dio;

  Future<Map<String, dynamic>> _call(
    String path, {
    Map<String, dynamic>? body,
    String? access,
  }) async {
    try {
      final response = await dio.request<Map<String, dynamic>>(
        '/v1/auth/$path',
        data: body,
        options: Options(
          method: body == null ? 'GET' : 'POST',
          headers: access == null ? null : {'Authorization': 'Bearer $access'},
        ),
      );
      return response.data ?? {};
    } on DioException catch (error) {
      final data = error.response?.data;
      final detail = data is Map ? data['error'] : null;
      final code = detail is Map ? detail['code'] as String? : null;
      final status = error.response?.statusCode;
      final message = status == null
          ? 'เชื่อมต่อไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่'
          : status == 429
          ? 'ลองหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่'
          : detail is Map && detail['message'] is String
          ? detail['message'] as String
          : 'ระบบขัดข้องชั่วคราว กรุณาลองใหม่';
      throw AuthFailure(message, status: status, code: code);
    }
  }

  AuthResult _result(Map<String, dynamic> data) => AuthResult(
    Account.fromJson(data['user'] as Map<String, dynamic>),
    SessionTokens.fromJson(data['tokens'] as Map<String, dynamic>),
  );

  @override
  Future<AuthResult> login(String email, String password) async => _result(
    await _call('login', body: {'email': email, 'password': password}),
  );
  @override
  Future<AuthResult> register(
    String email,
    String password,
    String name,
  ) async => _result(
    await _call(
      'register',
      body: {
        'email': email,
        'password': password,
        'display_name': name,
        'timezone': 'Asia/Bangkok',
      },
    ),
  );
  @override
  Future<SessionTokens> refresh(String token) async {
    final data = await _call('refresh', body: {'refresh_token': token});
    return SessionTokens.fromJson(data['tokens'] as Map<String, dynamic>);
  }

  @override
  Future<Account> me(String accessToken) async => Account.fromJson(
    (await _call('me', access: accessToken))['user'] as Map<String, dynamic>,
  );
  @override
  Future<void> logout(String refreshToken) async {
    await _call('logout', body: {'refresh_token': refreshToken});
  }
}
