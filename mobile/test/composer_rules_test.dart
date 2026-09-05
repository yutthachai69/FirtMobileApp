import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/features/composer/domain/composer_state.dart';
import 'package:relaycontent/features/composer/domain/creator_info.dart';

/// เทสชุดนี้คือกฎที่ TikTok ตรวจตอน audit
///
/// ผิดข้อเดียว = แอปไม่ผ่านและต้องยื่นใหม่ (รอบละ 2-4 สัปดาห์)
/// จึงล็อกไว้ด้วยเทสทุกข้อ ไม่ปล่อยให้ขึ้นกับการรีวิวด้วยตา

CreatorInfo _creator({
  List<PrivacyLevel> options = const [
    PrivacyLevel.publicToEveryone,
    PrivacyLevel.mutualFollowFriends,
    PrivacyLevel.selfOnly,
  ],
  bool commentDisabled = false,
  bool duetDisabled = false,
  bool stitchDisabled = false,
  int maxDuration = 600,
}) =>
    CreatorInfo(
      username: 'tester',
      nickname: 'Tester',
      avatarUrl: 'https://example.com/a.jpg',
      privacyLevelOptions: options,
      commentDisabled: commentDisabled,
      duetDisabled: duetDisabled,
      stitchDisabled: stitchDisabled,
      maxVideoDurationSec: maxDuration,
    );

ComposerState _ready() => ComposerState(
      creator: _creator(),
      privacyLevel: PrivacyLevel.selfOnly,
      videoDurationSec: 30,
    );

void main() {
  group('R2 — privacy ห้ามมีค่าเริ่มต้น', () {
    test('สถานะเริ่มต้นต้องไม่มี privacy ถูกเลือกไว้', () {
      const s = ComposerState();
      expect(s.privacyLevel, isNull);
    });

    test('ยังไม่เลือก privacy = โพสต์ไม่ได้', () {
      final s = ComposerState(creator: _creator(), videoDurationSec: 10);

      expect(s.canPost, isFalse);
      expect(s.postBlockedReason, 'กรุณาเลือกว่าใครดูวิดีโอนี้ได้');
    });

    test('ตัวเลือกต้องมาจาก creator_info เท่านั้น', () {
      // บัญชีส่วนตัวไม่มี PUBLIC_TO_EVERYONE ให้เลือก
      final s = ComposerState(
        creator: _creator(options: const [
          PrivacyLevel.followerOfCreator,
          PrivacyLevel.selfOnly,
        ]),
      );

      expect(s.privacyOptions, isNot(contains(PrivacyLevel.publicToEveryone)));
      expect(s.privacyOptions, hasLength(2));
    });

    test('ค่าที่ TikTok ส่งมาแต่เราไม่รู้จักต้องถูกตัดทิ้ง', () {
      final info = CreatorInfo.fromJson({
        'creator_username': 'x',
        'privacy_level_options': ['SELF_ONLY', 'SOMETHING_NEW'],
      });

      expect(info.privacyLevelOptions, [PrivacyLevel.selfOnly]);
    });
  });

  group('R3 — interaction toggle', () {
    test('ทั้งสามตัวต้องเริ่มที่ปิด ห้ามติ๊กไว้ล่วงหน้า', () {
      const s = ComposerState();

      expect(s.allowComment, isFalse);
      expect(s.allowDuet, isFalse);
      expect(s.allowStitch, isFalse);
    });

    test('ถ้าบัญชีปิดไว้ ต้องล็อกช่องนั้น', () {
      final s = ComposerState(
        creator: _creator(
          commentDisabled: true,
          duetDisabled: true,
          stitchDisabled: false,
        ),
      );

      expect(s.commentLocked, isTrue);
      expect(s.duetLocked, isTrue);
      expect(s.stitchLocked, isFalse);
    });
  });

  group('R4 — การเปิดเผยเนื้อหาเชิงพาณิชย์', () {
    test('เปิด disclose แต่ไม่เลือกอะไร = โพสต์ไม่ได้', () {
      final s = _ready().copyWith(discloseContent: true);

      expect(s.canPost, isFalse);
      // ข้อความต้องตรงสเปก TikTok เป๊ะ ห้ามแปล
      expect(s.postBlockedReason, kDiscloseRequiredMessage);
    });

    test('เลือกอย่างน้อยหนึ่งอย่างแล้วโพสต์ได้', () {
      final s = _ready().copyWith(discloseContent: true, brandOrganic: true);
      expect(s.canPost, isTrue);
    });

    test('ปิด disclose ต้องล้างตัวเลือกย่อยด้วย', () {
      // ถ้าไม่ล้าง ค่าจะค้างแล้วถูกส่งไป TikTok ทั้งที่ผู้ใช้ปิดไปแล้ว
      final s = _ready()
          .copyWith(discloseContent: true, brandOrganic: true)
          .copyWith(discloseContent: false);

      expect(s.brandOrganic, isFalse);
      expect(s.brandedContent, isFalse);
      expect(s.toPlatformOptions()['brand_organic_toggle'], isFalse);
    });
  });

  group('R5 — branded content กับ SELF_ONLY', () {
    test('เลือก "เฉพาะฉัน" ต้องล็อก branded content', () {
      final s = _ready().copyWith(privacyLevel: PrivacyLevel.selfOnly);
      expect(s.brandedContentBlocked, isTrue);
    });

    test('ถ้าฝืนเลือกทั้งคู่ต้องโพสต์ไม่ได้', () {
      final s = _ready().copyWith(
        privacyLevel: PrivacyLevel.selfOnly,
        discloseContent: true,
        brandedContent: true,
      );

      expect(s.canPost, isFalse);
      expect(s.postBlockedReason, contains('Branded content'));
    });

    test('เปลี่ยนเป็นสาธารณะแล้วใช้ branded content ได้', () {
      final s = _ready().copyWith(
        privacyLevel: PrivacyLevel.publicToEveryone,
        discloseContent: true,
        brandedContent: true,
      );

      expect(s.brandedContentBlocked, isFalse);
      expect(s.canPost, isTrue);
    });
  });

  group('R7 — ความยาววิดีโอ', () {
    test('ยาวเกินที่บัญชีรองรับ = โพสต์ไม่ได้', () {
      final s = ComposerState(
        creator: _creator(maxDuration: 60),
        privacyLevel: PrivacyLevel.selfOnly,
        videoDurationSec: 90,
      );

      expect(s.videoTooLong, isTrue);
      expect(s.postBlockedReason, contains('ยาวเกิน'));
    });

    test('พอดีขีดจำกัดต้องโพสต์ได้', () {
      final s = ComposerState(
        creator: _creator(maxDuration: 60),
        privacyLevel: PrivacyLevel.selfOnly,
        videoDurationSec: 60,
      );

      expect(s.videoTooLong, isFalse);
      expect(s.canPost, isTrue);
    });
  });

  group('R8 — is_aigc', () {
    test('ส่ง is_aigc ตามที่มาของวิดีโอ', () {
      expect(_ready().copyWith(isAigc: true).toPlatformOptions()['is_aigc'],
          isTrue);
      expect(_ready().toPlatformOptions()['is_aigc'], isFalse);
    });
  });

  group('caption', () {
    test('นับเป็นตัวอักษรไม่ใช่ไบต์ — ภาษาไทยต้องพิมพ์ได้เต็มโควตา', () {
      // ภาษาไทยหนึ่งตัวกิน 3 ไบต์ ถ้านับไบต์คนไทยจะพิมพ์ได้แค่ 1 ใน 3
      final s = _ready().copyWith(caption: 'ก' * kMaxCaptionRunes);

      expect(s.captionLength, kMaxCaptionRunes);
      expect(s.canPost, isTrue);
    });

    test('เกินโควตา = โพสต์ไม่ได้', () {
      final s = _ready().copyWith(caption: 'ก' * (kMaxCaptionRunes + 1));

      expect(s.canPost, isFalse);
      expect(s.postBlockedReason, contains('ยาวเกิน'));
    });
  });

  group('การส่งค่าไป backend', () {
    test('UI ถามเป็น allow แต่ TikTok รับเป็น disable — ต้องกลับค่า', () {
      final opts = _ready()
          .copyWith(allowComment: true, allowDuet: false, allowStitch: true)
          .toPlatformOptions();

      expect(opts['disable_comment'], isFalse);
      expect(opts['disable_duet'], isTrue);
      expect(opts['disable_stitch'], isFalse);
    });

    test('ส่ง privacy_level เป็นค่าที่ TikTok เข้าใจ', () {
      final opts =
          _ready().copyWith(privacyLevel: PrivacyLevel.mutualFollowFriends)
              .toPlatformOptions();

      expect(opts['privacy_level'], 'MUTUAL_FOLLOW_FRIENDS');
    });
  });

  group('สถานะระหว่างโหลด', () {
    test('ยังไม่มี creator_info ต้องโพสต์ไม่ได้', () {
      const s = ComposerState();

      expect(s.canPost, isFalse);
      expect(s.postBlockedReason, contains('กำลังโหลด'));
    });

    test('กำลังส่งอยู่ต้องกดซ้ำไม่ได้', () {
      expect(_ready().copyWith(submitting: true).canPost, isFalse);
    });
  });

  group('CreatorInfo', () {
    test('handle เติม @ ให้เสมอ', () {
      expect(_creator().handle, '@tester');
    });

    test('บัญชีที่โพสต์สาธารณะไม่ได้ต้องรู้ตัว', () {
      // ก่อนแอปผ่าน audit TikTok จะเหลือให้แค่ SELF_ONLY
      final info = _creator(options: const [PrivacyLevel.selfOnly]);
      expect(info.canPublishPublic, isFalse);
    });
  });
}
