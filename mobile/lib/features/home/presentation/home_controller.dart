import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_controller.dart';
import '../../auth/domain/session.dart';
import '../data/home_api.dart';
import '../domain/home_data.dart';

class HomeController extends ChangeNotifier {
  HomeController(this.auth, this.api);

  final AuthController auth;
  final HomeApi api;

  HomeData? data;
  String? error;
  bool loading = false;

  /// loaded บอกว่าเคยโหลดสำเร็จอย่างน้อยหนึ่งครั้งหรือยัง
  /// ใช้แยกระหว่าง "ยังไม่เคยโหลด" กับ "โหลดแล้วแต่ไม่มีงาน"
  bool get loaded => data != null;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();

    try {
      data = await auth.authorized(api.load);
    } on AuthFailure catch (f) {
      error = f.message;
    } catch (_) {
      error = 'โหลดข้อมูลไม่ได้ กรุณาลองใหม่';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
