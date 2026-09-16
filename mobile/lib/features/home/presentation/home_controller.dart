import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/config/app_config.dart';
import '../../auth/domain/session.dart';
import '../data/home_api.dart';
import '../domain/content_store.dart';
import '../domain/home_data.dart';

class HomeController extends ChangeNotifier {
  HomeController(this.auth, this.api, {this.store});

  final AuthController auth;
  final HomeApi api;
  final ContentStore? store;

  HomeData? data;
  String? error;
  bool loading = false;
  Timer? _pollTimer;

  /// Jobs are asynchronous (TikTok may take minutes), so a signed-in live
  /// session refreshes the same repository snapshot while Home is visible.
  static const pollInterval = Duration(seconds: 15);

  /// loaded บอกว่าเคยโหลดสำเร็จอย่างน้อยหนึ่งครั้งหรือยัง
  /// ใช้แยกระหว่าง "ยังไม่เคยโหลด" กับ "โหลดแล้วแต่ไม่มีงาน"
  bool get loaded => data != null;

  void startPolling() {
    if (!AppConfig.isLive || _pollTimer != null) return;
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (auth.phase == SessionPhase.signedIn) unawaited(load());
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();

    try {
      final next = await auth.authorized(api.load);
      data = next;
      // Keep one shared snapshot for Home, Content, review queue and product
      // detail. The store is optional so isolated widget tests can still use
      // HomeController with a fake API and no provider graph.
      store?.replaceAll(next.jobs);
    } on AuthFailure catch (f) {
      error = f.message;
    } catch (_) {
      error = 'โหลดข้อมูลไม่ได้ กรุณาลองใหม่';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
