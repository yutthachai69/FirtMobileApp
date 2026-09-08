import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/ai_source.dart';

/// สถานะของ AI Content Inbox แบบ local fixtures
///
/// ยังไม่มี OAuth หรือ share extension จริง — คลาสนี้จำลองการเชื่อมบัญชี
/// การตรวจ capability และการนำเข้าเบื้องหลังที่คืบหน้าเองแล้วอาจล้มเหลว
/// เพื่อให้หน้าจอมีสถานะครบก่อนต่อ backend
class AiSourcesController extends ChangeNotifier {
  AiSourcesController({this.autoAdvance = true}) {
    _sources = [...AiSource.seed];
    _inbox = _seedInbox();
    if (autoAdvance) {
      _timer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _advanceImports(0.25),
      );
    }
  }

  /// ปิดตัวจับเวลาในเทสเพื่อให้ผลลัพธ์คงที่ แล้วเรียก [debugAdvance] เอง
  final bool autoAdvance;

  late List<AiSource> _sources;
  late List<InboxItem> _inbox;
  Timer? _timer;
  bool _disposed = false;

  bool syncing = false;
  String? busySourceId;

  List<AiSource> get sources => List.unmodifiable(_sources);
  List<InboxItem> get inbox => List.unmodifiable(_inbox);

  List<InboxItem> get readyItems =>
      _inbox.where((i) => i.status == InboxStatus.ready).toList();
  List<InboxItem> get importingItems =>
      _inbox.where((i) => i.status == InboxStatus.importing).toList();
  List<InboxItem> get failedItems =>
      _inbox.where((i) => i.status == InboxStatus.failed).toList();

  int get connectedCount => _sources.where((s) => s.isConnected).length;
  bool get isEmpty => _inbox.isEmpty;

  AiSource sourceById(String id) => _sources.firstWhere((s) => s.id == id);

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  /// เชื่อมบัญชี AI — จำลอง handshake สั้น ๆ แล้วตรวจ capability
  Future<void> connect(String id) async {
    final index = _sources.indexWhere((s) => s.id == id);
    if (index < 0 || _sources[index].isConnected) return;

    busySourceId = id;
    notifyListeners();

    if (autoAdvance) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (_disposed) return;

    final source = _sources[index];
    // แหล่งที่มีข้อจำกัด (ครอปแนวตั้ง / ยังเชื่อมตรงไม่ได้) เชื่อมได้แต่ต้องเตือน
    final nextStatus = source.note == null
        ? SourceStatus.connected
        : SourceStatus.needsAttention;
    _sources[index] = source.copyWith(status: nextStatus);

    // การเชื่อมสำเร็จมักดึงงานที่ค้างอยู่เข้ามาให้เห็นทันทีหนึ่งชิ้น
    _inbox.insert(
      0,
      InboxItem(
        id: 'inbox-${DateTime.now().microsecondsSinceEpoch}',
        title: '${source.name} · งานล่าสุดจากบัญชี',
        sourceId: source.id,
        sourceName: source.name,
        status: InboxStatus.ready,
        durationSec: 24,
        updatedAt: DateTime.now(),
        vertical: source.supportsVerticalVideo,
      ),
    );

    busySourceId = null;
    notifyListeners();
  }

  void disconnect(String id) {
    final index = _sources.indexWhere((s) => s.id == id);
    if (index < 0) return;
    // งานที่นำเข้ามาแล้วยังอยู่ใน Inbox แค่หยุดรับของใหม่
    _sources[index] = _sources[index].copyWith(
      status: SourceStatus.disconnected,
    );
    notifyListeners();
  }

  /// ดึง Inbox ใหม่ — ผลักงานที่กำลังนำเข้าให้คืบหน้าและอาจได้งานใหม่
  Future<void> sync() async {
    if (syncing) return;
    syncing = true;
    notifyListeners();

    if (autoAdvance) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (_disposed) return;

    _advanceImports(0.5, silent: true);

    syncing = false;
    notifyListeners();
  }

  /// ลองนำเข้าใหม่หลังจากล้มเหลว
  void retry(String itemId) {
    final index = _inbox.indexWhere((i) => i.id == itemId);
    if (index < 0 || _inbox[index].status != InboxStatus.failed) return;
    _inbox[index] = _inbox[index].copyWith(
      status: InboxStatus.importing,
      progress: 0.05,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void dismiss(String itemId) {
    _inbox.removeWhere((i) => i.id == itemId);
    notifyListeners();
  }

  /// ให้เทสเดินเวลาเองเมื่อปิด [autoAdvance]
  @visibleForTesting
  void debugAdvance([double step = 0.5]) => _advanceImports(step);

  void _advanceImports(double step, {bool silent = false}) {
    var changed = false;
    for (var i = 0; i < _inbox.length; i++) {
      final item = _inbox[i];
      if (item.status != InboxStatus.importing) continue;
      final next = item.progress + step;
      if (next >= 1) {
        _inbox[i] = item.copyWith(
          status: InboxStatus.ready,
          progress: 1,
          updatedAt: DateTime.now(),
        );
      } else {
        _inbox[i] = item.copyWith(progress: next);
      }
      changed = true;
    }
    if (changed && !silent) notifyListeners();
  }

  List<InboxItem> _seedInbox() {
    final now = DateTime.now();
    return [
      InboxItem(
        id: 'inbox-ready-1',
        title: 'Serum close-up · Golden hour',
        sourceId: 'google-flow',
        sourceName: 'Google Flow',
        status: InboxStatus.ready,
        durationSec: 30,
        updatedAt: now.subtract(const Duration(minutes: 4)),
      ),
      InboxItem(
        id: 'inbox-importing-1',
        title: 'Lifestyle product montage',
        sourceId: 'google-flow',
        sourceName: 'Google Flow',
        status: InboxStatus.importing,
        durationSec: 22,
        progress: 0.35,
        updatedAt: now.subtract(const Duration(minutes: 1)),
      ),
      InboxItem(
        id: 'inbox-failed-1',
        title: 'Unboxing vertical product shot',
        sourceId: 'google-flow',
        sourceName: 'Google Flow',
        status: InboxStatus.failed,
        durationSec: 18,
        updatedAt: now.subtract(const Duration(minutes: 12)),
        failureReason: 'ไฟล์ต้นทางถูกลบก่อนดึงเสร็จ',
      ),
    ];
  }
}
