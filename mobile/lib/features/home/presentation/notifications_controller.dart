import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/config/app_config.dart';
import '../../auth/domain/session.dart';
import '../data/notifications_api.dart';
import '../domain/app_notification.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController(this.auth, this.api);

  final AuthController auth;
  final NotificationsApi api;

  List<AppNotification> items = const [];
  String? error;
  bool loading = false;
  Timer? _pollTimer;

  static const pollInterval = Duration(seconds: 30);

  int get unreadCount => items.where((item) => !item.isRead).length;

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

  Future<void> load({bool unreadOnly = false}) async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await auth.authorized(
        (access) => api.list(access, unreadOnly: unreadOnly),
      );
    } on AuthFailure catch (failure) {
      error = failure.message;
    } catch (_) {
      error = 'โหลดการแจ้งเตือนไม่ได้ กรุณาลองใหม่';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void markRead(String id) {
    final index = items.indexWhere((item) => item.id == id);
    if (index < 0 || items[index].isRead) return;
    final next = [...items];
    next[index] = next[index].markRead();
    items = List.unmodifiable(next);
    notifyListeners();
  }

  Future<bool> markAllRead() async {
    if (items.every((item) => item.isRead)) return true;
    try {
      await auth.authorized(api.markAllRead);
      items = List.unmodifiable(items.map((item) => item.markRead()));
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      error = failure.message;
    } catch (_) {
      error = 'ทำเครื่องหมายการแจ้งเตือนไม่สำเร็จ กรุณาลองใหม่';
    }
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
