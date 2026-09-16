import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_controller.dart';
import '../../auth/domain/session.dart';
import '../data/composer_api.dart';
import '../domain/composer_state.dart';
import '../domain/creator_info.dart';

class ComposerController extends ChangeNotifier {
  ComposerController({
    required this.auth,
    required this.api,
    required this.contentId,
    required this.connectionId,
    required int videoDurationSec,
    required bool isAigc,
    String? idempotencyKey,
  }) : _state = ComposerState(
         videoDurationSec: videoDurationSec,
         isAigc: isAigc,
       ),
       _idempotencyKey = idempotencyKey ?? _newKey();

  final AuthController auth;
  final ComposerApi api;
  final String contentId;
  final String connectionId;

  ComposerState _state;
  ComposerState get state => _state;

  String? error;
  bool loading = false;
  PublishJob? result;

  /// idempotencyKey สร้างครั้งเดียวต่อการเปิดหน้านี้
  ///
  /// ถ้าผู้ใช้กดโพสต์แล้วเน็ตหลุด แล้วกดใหม่ — ต้องใช้ key เดิม
  /// backend จะคืนงานเดิมแทนที่จะสร้างโพสต์ซ้ำ
  final String _idempotencyKey;

  void _set(ComposerState next) {
    _state = next;
    notifyListeners();
  }

  /// loadCreatorInfo ดึงข้อมูลสดทุกครั้งที่เปิดหน้า
  ///
  /// ⚠️ ห้ามข้ามขั้นนี้หรือ cache ไว้ — TikTok ตรวจตอน audit ว่าค่าที่แสดง
  /// (avatar, ชื่อบัญชี, ตัวเลือก privacy, ลิมิตความยาว) ตรงกับบัญชีจริง
  Future<void> loadCreatorInfo() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();

    try {
      final info = await auth.authorized(
        (access) => api.creatorInfo(access, connectionId),
      );
      _state = _state.copyWith(creator: info);
    } on AuthFailure catch (f) {
      error = f.message;
    } catch (_) {
      error = 'โหลดข้อมูลบัญชีไม่ได้ กรุณาลองใหม่';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ── ค่าที่ผู้ใช้เปลี่ยนได้ ──────────────────────────────────

  void setCaption(String v) => _set(_state.copyWith(caption: v));

  void setPrivacy(PrivacyLevel? v) {
    if (v == null) return;
    var next = _state.copyWith(privacyLevel: v);

    // R5: เปลี่ยนเป็น "เฉพาะฉัน" แล้ว branded content ใช้ไม่ได้ ต้องปลดให้เอง
    // ถ้าปล่อยค้างไว้ ผู้ใช้จะเห็นปุ่มโพสต์กดไม่ได้โดยไม่รู้ว่าต้องไปแก้ตรงไหน
    if (v.isSelfOnly && next.brandedContent) {
      next = next.copyWith(brandedContent: false);
    }
    _set(next);
  }

  void setAllowComment(bool v) => _set(_state.copyWith(allowComment: v));
  void setAllowDuet(bool v) => _set(_state.copyWith(allowDuet: v));
  void setAllowStitch(bool v) => _set(_state.copyWith(allowStitch: v));

  void setDisclose(bool v) => _set(_state.copyWith(discloseContent: v));
  void setBrandOrganic(bool v) => _set(_state.copyWith(brandOrganic: v));
  void setBrandedContent(bool v) => _set(_state.copyWith(brandedContent: v));

  void setScheduledAt(DateTime? v) => _set(_state.copyWith(scheduledAt: v));

  // ── ส่งงาน ─────────────────────────────────────────────────

  Future<bool> submit() async {
    if (!_state.canPost) return false;

    _set(_state.copyWith(submitting: true));
    error = null;

    try {
      result = await auth.authorized(
        (access) => api.schedule(
          access,
          contentId: contentId,
          connectionId: connectionId,
          platformOptions: _state.toPlatformOptions(),
          idempotencyKey: _idempotencyKey,
          scheduledAt: _state.scheduledAt,
        ),
      );
      return true;
    } on AuthFailure catch (f) {
      error = f.message;
      return false;
    } catch (_) {
      error = 'ตั้งเวลาโพสต์ไม่สำเร็จ กรุณาลองใหม่';
      return false;
    } finally {
      _set(_state.copyWith(submitting: false));
    }
  }

  static String _newKey() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
