import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/config/app_config.dart';
import '../../auth/domain/session.dart';
import '../data/connections_api.dart';
import '../domain/connection.dart';

class ConnectionsController extends ChangeNotifier {
  ConnectionsController(this.auth, this.api);

  final AuthController auth;
  final ConnectionsApi api;

  ConnectionList? list;
  String? error;
  bool loading = false;
  bool connecting = false;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      list = await auth.authorized(api.list);
    } on AuthFailure catch (f) {
      error = f.message;
    } catch (_) {
      error = 'โหลดรายการบัญชีไม่ได้ กรุณาลองใหม่';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// connectTikTok เปิดหน้าอนุญาตของ TikTok แล้วรอ deep link กลับ
  ///
  /// backend เป็นคนแลก code เป็น token — แอปไม่เคยเห็น access token ของ TikTok
  /// สิ่งที่กลับมาที่นี่มีแค่ผลลัพธ์ว่าสำเร็จหรือไม่
  Future<void> connectTikTok() async {
    if (connecting) return;
    connecting = true;
    error = null;
    notifyListeners();

    try {
      final url = await auth.authorized(api.startTikTokOAuth);

      final callback = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: AppConfig.appScheme,
      );

      final params = Uri.parse(callback).queryParameters;
      if (params['status'] != 'success') {
        error = _explain(params['code']);
      }
    } on AuthFailure catch (f) {
      error = f.message;
    } on PlatformException {
      // ผู้ใช้กดปิดหน้าต่างเอง — ไม่ใช่ความผิดพลาด ไม่ต้องขึ้น error
    } catch (_) {
      error = 'เชื่อมต่อ TikTok ไม่สำเร็จ กรุณาลองใหม่';
    } finally {
      connecting = false;
      notifyListeners();
    }

    // โหลดใหม่เสมอ แม้จะ error — ผู้ใช้อาจเชื่อมสำเร็จแล้วแต่ deep link มีปัญหา
    await load();
  }

  Future<void> disconnect(String connectionId) async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await auth.authorized((access) => api.remove(access, connectionId));
    } on AuthFailure catch (f) {
      error = f.message;
    } catch (_) {
      error = 'ยกเลิกการเชื่อมต่อไม่สำเร็จ กรุณาลองใหม่';
    } finally {
      loading = false;
      notifyListeners();
    }
    await load();
  }

  /// _explain แปลง error code จาก backend เป็นข้อความที่บอกว่าต้องทำอะไรต่อ
  String _explain(String? code) => switch (code) {
        'OAUTH_CANCELLED' => 'คุณยกเลิกการอนุญาตบน TikTok',
        'OAUTH_STATE_INVALID' =>
          'ลิงก์เชื่อมต่อหมดอายุแล้ว กรุณากดเชื่อมต่อใหม่',
        'PROVIDER_NOT_CONFIGURED' =>
          'ระบบยังไม่ได้ตั้งค่า TikTok กรุณาติดต่อผู้ดูแล',
        'UPSTREAM_ERROR' => 'TikTok ไม่ตอบสนอง กรุณาลองใหม่อีกครั้ง',
        _ => 'เชื่อมต่อ TikTok ไม่สำเร็จ กรุณาลองใหม่',
      };
}
