import 'package:flutter/foundation.dart';

import '../../connections/domain/connection.dart';
import 'home_data.dart';

/// จำนวนออเดอร์จำลองต่อคลิปที่โพสต์แล้ว — คงที่ต่อ id เดียวกัน
/// มาแทนด้วยเลขจริงจาก TikTok เมื่อต่อ backend
int mockOrdersFor(PublishJob job) =>
    job.status == JobStatus.published ? (job.id.hashCode.abs() % 34) + 12 : 0;

/// แหล่งข้อมูล "งานคอนเทนต์" ตัวเดียวของทั้งแอปในโหมด prototype
///
/// ก่อนหน้านี้งานกระจายอยู่สามที่และไม่ตรงกัน: backend (`homeProvider`),
/// fixture คงที่ (`demoContentJobs`) และ local state ในหน้า publish ที่ไม่มีใครอ่านต่อ
/// [ContentStore] รวมทุกอย่างเป็นรายการเดียว หน้า Home / Content / Notifications
/// อ่านชุดเดียวกัน และการกดเผยแพร่จะเพิ่มงานเข้ามาจริง
///
/// backend repository มาแทนที่ seed ภายหลังได้โดยไม่แตะ UI
class ContentStore extends ChangeNotifier {
  ContentStore({List<PublishJob>? jobs})
    : _jobs = jobs != null ? List.of(jobs) : seedJobs();

  final List<PublishJob> _jobs;

  List<PublishJob> get jobs => List.unmodifiable(_jobs);

  bool get isEmpty => _jobs.isEmpty;

  /// Replaces the in-memory snapshot with the latest repository response.
  /// Keeping this operation at the store boundary lets existing screens share
  /// one source while the API-backed repository is introduced incrementally.
  void replaceAll(Iterable<PublishJob> jobs) {
    final next = List<PublishJob>.of(jobs);
    if (_sameIdsAndStates(next)) return;
    _jobs
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  /// Replaces one item after a server mutation, preserving the rest of the
  /// current snapshot. Also useful for rolling back an optimistic update.
  void replace(PublishJob job) {
    final index = _jobs.indexWhere((item) => item.id == job.id);
    if (index < 0 || _sameJob(_jobs[index], job)) return;
    _jobs[index] = job;
    notifyListeners();
  }

  bool _sameIdsAndStates(List<PublishJob> next) {
    if (_jobs.length != next.length) return false;
    for (var i = 0; i < _jobs.length; i++) {
      final current = _jobs[i];
      final incoming = next[i];
      if (!_sameJob(current, incoming)) return false;
    }
    return true;
  }

  bool _sameJob(PublishJob a, PublishJob b) =>
      a.id == b.id &&
      a.status == b.status &&
      a.scheduledAt == b.scheduledAt &&
      a.caption == b.caption &&
      a.errorMessage == b.errorMessage &&
      a.permalink == b.permalink;

  PublishJob? byId(String id) {
    for (final j in _jobs) {
      if (j.id == id) return j;
    }
    return null;
  }

  /// งานทั้งหมดที่ปักตะกร้ากับสินค้าชิ้นนี้ ใหม่สุดก่อน — ใช้ในหน้า product detail
  List<PublishJob> byProduct(String productId) =>
      _jobs.where((j) => j.productId == productId).toList()
        ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

  /// งานที่รอตรวจ ป้อนคิว Swipe Review เรียงจากใกล้ถึงเวลาที่สุด
  List<PublishJob> get reviewQueue =>
      _jobs.where((j) => j.status == JobStatus.awaitingReview).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  /// อนุมัติงานที่รอตรวจ → เข้าคิวตั้งเวลา
  void approveReview(String id) => updateStatus(id, JobStatus.scheduled);

  /// ส่งกลับไปเป็นฉบับร่างเพื่อแก้
  void sendBackToDraft(String id) => updateStatus(id, JobStatus.draft);

  /// มุมมองจัดกลุ่มตามความเร่งด่วน สำหรับหน้าหลัก
  HomeData homeData({List<Connection> connections = const []}) =>
      HomeData.build(jobs: _jobs, connections: connections);

  /// เพิ่มงานใหม่ — หน้า publish เรียกตอนกดยืนยัน
  void add(PublishJob job) {
    _jobs.insert(0, job);
    notifyListeners();
  }

  void reschedule(String id, DateTime at) => _mutate(
    id,
    (j) => j.copyWith(scheduledAt: at, status: JobStatus.scheduled),
  );

  void cancel(String id) =>
      _mutate(id, (j) => j.copyWith(status: JobStatus.cancelled));

  void restore(String id) =>
      _mutate(id, (j) => j.copyWith(status: JobStatus.scheduled));

  void retry(String id) => _mutate(
    id,
    (j) => j.copyWith(status: JobStatus.queued, errorMessage: ''),
  );

  void updateStatus(String id, JobStatus status) =>
      _mutate(id, (j) => j.copyWith(status: status));

  void remove(String id) {
    final before = _jobs.length;
    _jobs.removeWhere((j) => j.id == id);
    if (_jobs.length != before) notifyListeners();
  }

  void _mutate(String id, PublishJob Function(PublishJob) change) {
    final index = _jobs.indexWhere((j) => j.id == id);
    if (index < 0) return;
    _jobs[index] = change(_jobs[index]);
    notifyListeners();
  }

  /// fixture เริ่มต้น — คำนวณวันเวลาสัมพันธ์กับ "ตอนนี้" เสมอ
  /// เปิดแอปวันไหนงานก็ยังดูสมเหตุสมผล ไม่ตรึงไว้ที่วันใดวันหนึ่ง
  static List<PublishJob> seedJobs() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      PublishJob(
        id: 'demo-draft',
        contentId: 'content-draft',
        productId: 'mock-1',
        platform: 'tiktok',
        status: JobStatus.draft,
        scheduledAt: today.add(const Duration(hours: 11, minutes: 30)),
        caption: 'รีวิวเซรั่มวิตามินซี ฉบับร่างจาก AI Content Inbox',
        sourceLabel: 'AI Content Inbox · Google Flow',
      ),
      PublishJob(
        id: 'demo-review-1',
        contentId: 'content-review-1',
        productId: 'mock-2',
        platform: 'tiktok',
        status: JobStatus.awaitingReview,
        scheduledAt: DateTime(now.year, now.month, now.day + 2, 19, 30),
        caption: 'ไมค์ไร้สายตัวนี้เปลี่ยนคุณภาพเสียงคลิปไปเลย กดที่ตะกร้าดูโปร',
        sourceLabel: 'AI Content Inbox · Google Flow',
      ),
      PublishJob(
        id: 'demo-review-2',
        contentId: 'content-review-2',
        productId: 'mock-1',
        platform: 'tiktok',
        status: JobStatus.awaitingReview,
        scheduledAt: DateTime(now.year, now.month, now.day + 3, 12, 0),
        caption: 'เซรั่มขวดนี้ใช้หมดไป 3 ขวดแล้ว มาเล่าให้ฟัง',
        sourceLabel: 'อัปโหลดเอง',
      ),
      PublishJob(
        id: 'demo-review-3',
        contentId: 'content-review-3',
        productId: 'mock-3',
        platform: 'tiktok',
        status: JobStatus.awaitingReview,
        scheduledAt: DateTime(now.year, now.month, now.day + 4, 21, 0),
        caption: 'แก้วเก็บความเย็นใบนี้พกไปทำงานทุกวัน',
        sourceLabel: 'AI Content Inbox · Runway',
      ),
      PublishJob(
        id: 'demo-processing',
        contentId: 'content-processing',
        productId: 'mock-2',
        platform: 'tiktok',
        status: JobStatus.processing,
        scheduledAt: now.add(const Duration(hours: 2)),
        caption: 'คลิปแกะกล่องไมโครโฟนไร้สายสำหรับ Creator',
        sourceLabel: 'อัปโหลดเอง',
      ),
      PublishJob(
        id: 'demo-scheduled',
        contentId: 'content-scheduled',
        productId: 'mock-3',
        platform: 'tiktok',
        status: JobStatus.scheduled,
        scheduledAt: DateTime(now.year, now.month, now.day + 1, 19, 30),
        caption: 'ป้ายยาแก้วเก็บความเย็น พร้อมโปรประจำสัปดาห์',
        sourceLabel: 'AI Content Inbox · Sora',
      ),
      PublishJob(
        id: 'demo-published',
        contentId: 'content-published',
        productId: 'mock-1',
        platform: 'tiktok',
        status: JobStatus.published,
        scheduledAt: now.subtract(const Duration(hours: 3)),
        caption: '3 เหตุผลที่ควรลองเซรั่มตัวนี้ก่อนโปรหมด',
        permalink: 'https://www.tiktok.com/',
        sourceLabel: 'อัปโหลดเอง',
      ),
      PublishJob(
        id: 'demo-failed',
        contentId: 'content-failed',
        productId: 'mock-1',
        platform: 'tiktok',
        status: JobStatus.failed,
        scheduledAt: now.subtract(const Duration(hours: 6)),
        caption: 'คลิปรีวิวสินค้าเวอร์ชัน Hook เร็ว',
        errorMessage: 'สินค้าที่ผูกไว้หมดสต็อกก่อนถึงเวลาเผยแพร่',
        sourceLabel: 'AI Content Inbox · Google Flow',
      ),
    ];
  }
}
