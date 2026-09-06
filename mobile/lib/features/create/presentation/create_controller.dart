import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_controller.dart';
import '../../auth/domain/session.dart';
import '../../connections/data/connections_api.dart';
import '../../connections/domain/connection.dart';
import '../data/create_api.dart';
import '../domain/picked_video.dart';

/// ขั้นตอนของหน้าสร้างคอนเทนต์
enum CreateStep {
  /// ยังไม่ได้เลือกวิดีโอ
  pick,

  /// กำลังอัปขึ้น storage
  uploading,

  /// อัปเสร็จแล้ว รอเขียนคำบรรยาย
  describe,

  /// สร้าง content เสร็จ พร้อมไปหน้า Composer
  ready,
}

class CreateController extends ChangeNotifier {
  CreateController({
    required this.auth,
    required this.api,
    required this.connections,
  });

  final AuthController auth;
  final CreateApi api;
  final ConnectionsApi connections;

  CreateStep step = CreateStep.pick;
  PickedVideo? video;
  String? assetId;
  String? previewUrl;
  String? contentId;
  String caption = '';

  /// ความคืบหน้า 0.0–1.0 ระหว่างอัปโหลด
  double progress = 0;

  String? error;
  bool busy = false;

  /// บัญชีที่จะใช้โพสต์ — โหลดพร้อมกันตอนเปิดหน้า
  Connection? target;
  bool connectionsLoaded = false;

  /// พร้อมไปหน้า Composer เมื่อมีทั้งคอนเทนต์และบัญชีที่ใช้ได้
  bool get canContinue =>
      step == CreateStep.ready && contentId != null && target != null;

  Future<void> loadConnections() async {
    try {
      final list = await auth.authorized(connections.list);
      final tiktok = list.tiktok;
      target = (tiktok?.status.isUsable ?? false) ? tiktok : null;
    } on AuthFailure catch (f) {
      error = f.message;
    } catch (_) {
      error = 'โหลดรายการบัญชีไม่ได้';
    } finally {
      connectionsLoaded = true;
      notifyListeners();
    }
  }

  void setCaption(String v) {
    caption = v;
    notifyListeners();
  }

  /// pickAndUpload เลือกไฟล์แล้วอัปทันที
  ///
  /// รวมสองขั้นเป็นปุ่มเดียวเพราะการให้ผู้ใช้เลือกไฟล์แล้วต้องกด "อัปโหลด" อีกที
  /// เป็นขั้นตอนที่ไม่ได้ให้ทางเลือกอะไรเพิ่ม มีแต่ทำให้ช้าลง
  Future<void> pickAndUpload() async {
    if (busy) return;

    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'mov'],
    );
    if (f == null) return; // ผู้ใช้กดยกเลิก

    final size = f.lengthSync() ?? 0;
    if (size <= 0) {
      error = 'อ่านไฟล์ไม่ได้ กรุณาเลือกใหม่';
      notifyListeners();
      return;
    }

    final picked = PickedVideo(
      name: f.name,
      sizeBytes: size,
      mime: PickedVideo.mimeFromName(f.name),
      // readAsByteStream ใช้ได้เหมือนกันทั้งเว็บและมือถือ
      // จึงไม่ต้องแยกโค้ดตามแพลตฟอร์ม
      openRead: f.readAsByteStream,
    );

    video = picked;
    await _upload(picked);
  }

  Future<void> _upload(PickedVideo picked) async {
    busy = true;
    error = null;
    progress = 0;
    step = CreateStep.uploading;
    notifyListeners();

    try {
      final ticket = await auth.authorized(
        (access) => api.requestUpload(access, picked),
      );

      await api.upload(
        ticket,
        picked,
        onProgress: (sent, total) {
          if (total > 0) {
            progress = sent / total;
            notifyListeners();
          }
        },
      );

      // backend จะ HEAD เช็คว่าไฟล์ขึ้นจริงและขนาดตรงก่อนรับ
      previewUrl = await auth.authorized(
        (access) => api.completeUpload(access, ticket.assetId),
      );

      assetId = ticket.assetId;
      step = CreateStep.describe;
    } on AuthFailure catch (f) {
      error = f.message;
      step = CreateStep.pick;
    } catch (_) {
      error = 'อัปโหลดไม่สำเร็จ กรุณาลองใหม่';
      step = CreateStep.pick;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// saveContent สร้าง content จาก caption + วิดีโอที่อัปไว้
  Future<bool> saveContent() async {
    if (busy || assetId == null) return false;

    busy = true;
    error = null;
    notifyListeners();

    try {
      contentId = await auth.authorized(
        (access) => api.createContent(
          access,
          caption: caption.trim(),
          mediaAssetId: assetId!,
        ),
      );
      step = CreateStep.ready;
      return true;
    } on AuthFailure catch (f) {
      error = f.message;
      return false;
    } catch (_) {
      error = 'บันทึกคอนเทนต์ไม่สำเร็จ กรุณาลองใหม่';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// reset ใช้ตอนผู้ใช้อยากเลือกวิดีโอใหม่
  void reset() {
    step = CreateStep.pick;
    video = null;
    assetId = null;
    previewUrl = null;
    contentId = null;
    caption = '';
    progress = 0;
    error = null;
    notifyListeners();
  }
}
