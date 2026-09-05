import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/features/connections/domain/connection.dart';
import 'package:relaycontent/features/home/domain/home_data.dart';

PublishJob _job(
  String caption,
  JobStatus status, {
  DateTime? at,
  String error = '',
}) =>
    PublishJob(
      id: caption,
      contentId: caption,
      platform: 'tiktok',
      status: status,
      scheduledAt: at ?? DateTime(2026, 9, 5, 12),
      caption: caption,
      errorMessage: error,
    );

Connection _conn(String status) => Connection.fromJson({
      'id': 'c1',
      'provider': 'tiktok',
      'display_name': '@tester',
      'status': status,
    });

void main() {
  final now = DateTime(2026, 9, 5, 15);

  group('การจัดกลุ่มบนหน้าหลัก', () {
    test('งานที่ล้มเหลวต้องขึ้นกลุ่ม "ต้องทำ" ไม่ใช่จมอยู่ในรายการ', () {
      final d = HomeData.build(
        now: now,
        connections: const [],
        jobs: [_job('คลิปเสื้อ', JobStatus.failed, error: 'วิดีโอยาวเกินกำหนด')],
      );

      expect(d.needAction, hasLength(1));
      expect(d.needAction.first.kind, ActionKind.jobFailed);
      // ต้องบอกสาเหตุจริง ไม่ใช่แค่ "ไม่สำเร็จ"
      expect(d.needAction.first.detail, 'วิดีโอยาวเกินกำหนด');
    });

    test('บัญชีที่หลุดการเชื่อมต่อต้องขึ้น "ต้องทำ"', () {
      final d = HomeData.build(
        now: now,
        connections: [_conn('needs_reauth')],
        jobs: const [],
      );

      expect(d.needAction, hasLength(1));
      expect(d.needAction.first.kind, ActionKind.needsReauth);
      expect(d.needAction.first.title, contains('TikTok'));
      expect(d.needAction.first.connectionId, 'c1');
    });

    test('บัญชีปกติต้องไม่ขึ้นเป็นสิ่งที่ต้องทำ', () {
      final d = HomeData.build(
        now: now,
        connections: [_conn('active')],
        jobs: const [],
      );
      expect(d.needAction, isEmpty);
    });

    test('แยกกลุ่มตามสถานะได้ถูกต้อง', () {
      final d = HomeData.build(
        now: now,
        connections: const [],
        jobs: [
          _job('a', JobStatus.uploading),
          _job('b', JobStatus.processing),
          _job('c', JobStatus.scheduled),
          _job('d', JobStatus.published),
        ],
      );

      expect(d.working, hasLength(2));
      expect(d.scheduled, hasLength(1));
      expect(d.publishedToday, hasLength(1));
    });

    test('งานที่ยกเลิกแล้วต้องไม่โผล่ที่ไหนเลย', () {
      final d = HomeData.build(
        now: now,
        connections: const [],
        jobs: [_job('x', JobStatus.cancelled)],
      );
      expect(d.isEmpty, isTrue);
    });

    test('โพสต์ของเมื่อวานต้องไม่นับเป็น "วันนี้"', () {
      final d = HomeData.build(
        now: now,
        connections: const [],
        jobs: [
          _job('เมื่อวาน', JobStatus.published, at: DateTime(2026, 9, 4, 20)),
          _job('วันนี้', JobStatus.published, at: DateTime(2026, 9, 5, 9)),
        ],
      );

      expect(d.publishedToday, hasLength(1));
      expect(d.publishedToday.first.caption, 'วันนี้');
    });

    test('งานที่ตั้งเวลาไว้ต้องเรียงจากใกล้ถึงเวลาที่สุด', () {
      final d = HomeData.build(
        now: now,
        connections: const [],
        jobs: [
          _job('ดึก', JobStatus.scheduled, at: DateTime(2026, 9, 5, 22)),
          _job('เย็น', JobStatus.scheduled, at: DateTime(2026, 9, 5, 18)),
          _job('พรุ่งนี้', JobStatus.scheduled, at: DateTime(2026, 9, 6, 9)),
        ],
      );

      expect(d.scheduled.map((j) => j.caption).toList(),
          ['เย็น', 'ดึก', 'พรุ่งนี้']);
    });

    test('ไม่มีอะไรเลย = หน้าว่าง', () {
      expect(
        HomeData.build(now: now, connections: const [], jobs: const []).isEmpty,
        isTrue,
      );
    });
  });

  group('ชื่อที่แสดงในรายการ', () {
    test('ใช้บรรทัดแรกของ caption', () {
      final j = _job('บรรทัดแรก\nบรรทัดสอง', JobStatus.scheduled);
      expect(j.title, 'บรรทัดแรก');
    });

    test('caption ยาวต้องถูกตัด', () {
      final j = _job('ก' * 100, JobStatus.scheduled);
      expect(j.title.length, lessThan(70));
      expect(j.title, endsWith('…'));
    });

    test('ไม่มี caption ต้องไม่โชว์ช่องว่าง', () {
      final j = _job('', JobStatus.scheduled);
      expect(j.title, 'ไม่มีคำบรรยาย');
    });
  });

  group('สถานะงาน', () {
    test('สถานะที่ไม่รู้จักต้องไม่ถือว่ากำลังทำงาน', () {
      expect(JobStatus.parse('something_new').isWorking, isFalse);
    });

    test('ทุกสถานะมีข้อความภาษาไทย', () {
      for (final s in JobStatus.values) {
        expect(s.label, isNotEmpty, reason: s.name);
      }
    });
  });
}
