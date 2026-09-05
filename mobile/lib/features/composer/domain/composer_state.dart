import 'creator_info.dart';

/// ความยาว caption สูงสุดที่ TikTok รับ (นับเป็นตัวอักษร ไม่ใช่ไบต์)
const kMaxCaptionRunes = 2200;

/// ข้อความบังคับตามสเปกของ TikTok — **ห้ามแปลหรือแก้ถ้อยคำ**
/// TikTok ตรวจข้อความนี้ตอน audit
const kDiscloseRequiredMessage =
    'You need to indicate if your content promotes yourself, '
    'a third party, or both.';

/// สถานะของหน้า Composer
///
/// แยกออกมาเป็น logic ล้วนเพื่อให้เทสได้ครบทุกกฎโดยไม่ต้องเปิดหน้าจอ
/// กฎพวกนี้คือสิ่งที่ TikTok ตรวจตอน audit ผิดข้อเดียวคือไม่ผ่าน
class ComposerState {
  const ComposerState({
    this.creator,
    this.privacyLevel,
    this.caption = '',
    this.allowComment = false,
    this.allowDuet = false,
    this.allowStitch = false,
    this.discloseContent = false,
    this.brandOrganic = false,
    this.brandedContent = false,
    this.isAigc = false,
    this.videoDurationSec = 0,
    this.scheduledAt,
    this.submitting = false,
  });

  /// null = ยังโหลด creator_info ไม่เสร็จ
  final CreatorInfo? creator;

  /// ⚠️ R2: null = ยังไม่ได้เลือก — **ห้ามมีค่าเริ่มต้น**
  final PrivacyLevel? privacyLevel;

  final String caption;

  /// ⚠️ R3: ทั้งสามตัวต้องเริ่มที่ false ห้ามติ๊กไว้ล่วงหน้า
  final bool allowComment;
  final bool allowDuet;
  final bool allowStitch;

  final bool discloseContent;
  final bool brandOrganic;
  final bool brandedContent;

  /// ⚠️ R8: มาจากที่มาของวิดีโอ ผู้ใช้เปลี่ยนเองไม่ได้
  final bool isAigc;

  final int videoDurationSec;
  final DateTime? scheduledAt;
  final bool submitting;

  int get captionLength => caption.runes.length;

  /// R5: Branded content ตั้งเป็น "เฉพาะฉัน" ไม่ได้ตามนโยบาย TikTok
  /// → ต้อง disable ตัวเลือกนี้เมื่อผู้ใช้เลือก SELF_ONLY
  bool get brandedContentBlocked => privacyLevel?.isSelfOnly ?? false;

  /// R3: ปิดจากฝั่งบัญชีแล้ว → widget ต้อง disable ไม่ใช่แค่ปล่อยว่าง
  bool get commentLocked => creator?.commentDisabled ?? false;
  bool get duetLocked => creator?.duetDisabled ?? false;
  bool get stitchLocked => creator?.stitchDisabled ?? false;

  /// R7: วิดีโอยาวเกินที่บัญชีนี้โพสต์ได้
  bool get videoTooLong {
    final max = creator?.maxVideoDurationSec ?? 0;
    return max > 0 && videoDurationSec > max;
  }

  /// canPost เป็น true เมื่อผ่านทุกกฎ — ปุ่ม Post ผูกกับค่านี้
  bool get canPost => postBlockedReason == null && !submitting;

  /// postBlockedReason บอกว่าติดกฎข้อไหน — แสดงใต้ปุ่มเสมอเมื่อกดไม่ได้
  ///
  /// การบอกเหตุผลไม่ใช่แค่ UX ที่ดี แต่เป็นสิ่งที่ TikTok ตรวจ (R4)
  String? get postBlockedReason {
    if (creator == null) return 'กำลังโหลดข้อมูลบัญชี…';

    // R2 — ต้องเลือกเอง ไม่มีค่าตั้งต้นให้
    if (privacyLevel == null) {
      return 'กรุณาเลือกว่าใครดูวิดีโอนี้ได้';
    }

    // R4 — เปิดการเปิดเผยแล้วต้องระบุว่าโปรโมตอะไร
    if (discloseContent && !brandOrganic && !brandedContent) {
      return kDiscloseRequiredMessage;
    }

    // R5 — branded content กับ "เฉพาะฉัน" ใช้ร่วมกันไม่ได้
    if (brandedContent && brandedContentBlocked) {
      return 'Branded content ตั้งเป็น "เฉพาะฉัน" ไม่ได้';
    }

    // R7 — ความยาวเกินที่บัญชีนี้รองรับ
    if (videoTooLong) {
      final max = creator!.maxVideoDurationSec;
      return 'วิดีโอยาวเกิน ${_readable(max)} กรุณาตัดให้สั้นลง';
    }

    if (captionLength > kMaxCaptionRunes) {
      return 'คำบรรยายยาวเกิน $kMaxCaptionRunes ตัวอักษร';
    }

    return null;
  }

  /// options ที่ dropdown แสดงได้ — มาจาก creator_info เท่านั้น
  List<PrivacyLevel> get privacyOptions =>
      creator?.privacyLevelOptions ?? const [];

  /// ค่าที่ส่งไป backend เป็น platform_options ของ publish job
  Map<String, dynamic> toPlatformOptions() => {
        'privacy_level': privacyLevel!.wire,
        // backend รับเป็น disable_* ส่วน UI ถามเป็น allow_* — กลับค่าตรงนี้ที่เดียว
        'disable_comment': !allowComment,
        'disable_duet': !allowDuet,
        'disable_stitch': !allowStitch,
        'brand_organic_toggle': discloseContent && brandOrganic,
        'brand_content_toggle': discloseContent && brandedContent,
        'is_aigc': isAigc,
      };

  ComposerState copyWith({
    CreatorInfo? creator,
    PrivacyLevel? privacyLevel,
    bool clearPrivacyLevel = false,
    String? caption,
    bool? allowComment,
    bool? allowDuet,
    bool? allowStitch,
    bool? discloseContent,
    bool? brandOrganic,
    bool? brandedContent,
    bool? isAigc,
    int? videoDurationSec,
    DateTime? scheduledAt,
    bool? submitting,
  }) {
    return ComposerState(
      creator: creator ?? this.creator,
      privacyLevel:
          clearPrivacyLevel ? null : (privacyLevel ?? this.privacyLevel),
      caption: caption ?? this.caption,
      allowComment: allowComment ?? this.allowComment,
      allowDuet: allowDuet ?? this.allowDuet,
      allowStitch: allowStitch ?? this.allowStitch,
      discloseContent: discloseContent ?? this.discloseContent,
      // ปิดการเปิดเผย = ล้างตัวเลือกย่อยด้วย ไม่งั้นค่าค้างแล้วส่งผิดไป TikTok
      brandOrganic: (discloseContent ?? this.discloseContent)
          ? (brandOrganic ?? this.brandOrganic)
          : false,
      brandedContent: (discloseContent ?? this.discloseContent)
          ? (brandedContent ?? this.brandedContent)
          : false,
      isAigc: isAigc ?? this.isAigc,
      videoDurationSec: videoDurationSec ?? this.videoDurationSec,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      submitting: submitting ?? this.submitting,
    );
  }

  static String _readable(int seconds) =>
      seconds >= 60 ? '${(seconds / 60).round()} นาที' : '$seconds วินาที';
}
