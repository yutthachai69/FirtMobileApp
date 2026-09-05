import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/features/connections/domain/connection.dart';

void main() {
  group('ConnectionCapabilities', () {
    test('อ่านค่าจริงที่ backend ส่งมาได้ครบ', () {
      final caps = ConnectionCapabilities.fromJson({
        'can_publish_public': true,
        'privacy_level_options': ['PUBLIC_TO_EVERYONE', 'SELF_ONLY'],
        'comment_disabled': true,
        'duet_disabled': false,
        'stitch_disabled': true,
        'max_video_duration_sec': 600,
        'max_posts_per_day': 15,
      });

      expect(caps.canPublishPublic, isTrue);
      expect(caps.privacyLevelOptions, hasLength(2));
      expect(caps.commentDisabled, isTrue);
      expect(caps.duetDisabled, isFalse);
      expect(caps.maxVideoDurationSec, 600);
      expect(caps.maxPostsPerDay, 15);
    });

    // ก่อนแอปผ่าน TikTok audit backend จะส่ง can_publish_public = false
    // หน้าจอต้องอ่านค่านี้ไปเตือนผู้ใช้ ไม่ใช่ hardcode ว่าโพสต์สาธารณะได้
    test('ก่อนผ่าน audit ต้องรู้ว่าโพสต์สาธารณะไม่ได้', () {
      final caps = ConnectionCapabilities.fromJson({
        'can_publish_public': false,
        'privacy_level_options': ['SELF_ONLY'],
      });

      expect(caps.canPublishPublic, isFalse);
      expect(caps.privacyLevelOptions, ['SELF_ONLY']);
    });

    // ถ้าเดาว่าโพสต์สาธารณะได้แล้วจริง ๆ ไม่ได้ ผู้ใช้จะโพสต์แล้วไม่มีใครเห็น
    // เดาผิดทางนี้เสียหายน้อยกว่า
    test('ไม่มีข้อมูล = ถือว่าโพสต์สาธารณะไม่ได้ไว้ก่อน', () {
      final caps = ConnectionCapabilities.fromJson(null);

      expect(caps.canPublishPublic, isFalse);
      expect(caps.isEmpty, isTrue);
    });

    // jsonb ที่ผ่าน JSON มาอาจได้ตัวเลขเป็น double
    test('ตัวเลขที่มาเป็น double ต้องอ่านได้', () {
      final caps = ConnectionCapabilities.fromJson({
        'max_video_duration_sec': 600.0,
        'max_posts_per_day': 15.0,
      });

      expect(caps.maxVideoDurationSec, 600);
      expect(caps.maxPostsPerDay, 15);
    });
  });

  group('ConnectionStatus', () {
    test('แปลงค่าจาก backend ได้ถูกต้อง', () {
      expect(ConnectionStatus.parse('active'), ConnectionStatus.active);
      expect(
        ConnectionStatus.parse('needs_reauth'),
        ConnectionStatus.needsReauth,
      );
      expect(ConnectionStatus.parse('revoked'), ConnectionStatus.revoked);
    });

    test('สถานะที่ไม่รู้จักต้องไม่ถือว่าใช้งานได้', () {
      // ถ้า backend เพิ่มสถานะใหม่ในอนาคต แอปเวอร์ชันเก่าต้องไม่เผลอ
      // ปล่อยให้ผู้ใช้ตั้งโพสต์กับบัญชีที่ใช้ไม่ได้
      expect(ConnectionStatus.parse('something_new').isUsable, isFalse);
      expect(ConnectionStatus.parse(null).isUsable, isFalse);
    });

    test('มีแค่ active เท่านั้นที่ใช้งานได้', () {
      for (final s in ConnectionStatus.values) {
        expect(s.isUsable, s == ConnectionStatus.active, reason: s.name);
      }
    });

    test('ทุกสถานะมีข้อความบอกผู้ใช้', () {
      for (final s in ConnectionStatus.values) {
        expect(s.label, isNotEmpty, reason: s.name);
      }
    });
  });

  group('ConnectionList', () {
    test('หา TikTok เจอจากรายการที่มีหลายแพลตฟอร์ม', () {
      final list = ConnectionList(
        tiktokEnabled: true,
        items: [
          Connection.fromJson({
            'id': 'c1',
            'provider': 'openai',
            'status': 'active',
          }),
          Connection.fromJson({
            'id': 'c2',
            'provider': 'tiktok',
            'display_name': '@tester',
            'status': 'active',
            'capabilities': {'max_posts_per_day': 15},
          }),
        ],
      );

      expect(list.tiktok?.id, 'c2');
      expect(list.tiktok?.displayName, '@tester');
      expect(list.tiktok?.capabilities.maxPostsPerDay, 15);
    });

    test('ยังไม่ได้เชื่อม TikTok ต้องคืน null ไม่ใช่พัง', () {
      const list = ConnectionList(items: [], tiktokEnabled: false);
      expect(list.tiktok, isNull);
    });
  });
}
