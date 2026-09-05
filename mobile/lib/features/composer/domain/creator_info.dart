/// ระดับความเป็นส่วนตัวของโพสต์ตามที่ TikTok กำหนด
///
/// ตัวเลือกที่แสดงได้ **ต้องมาจาก creator_info เท่านั้น** ห้าม hardcode
/// บัญชีสาธารณะกับบัญชีส่วนตัวได้ตัวเลือกคนละชุด
enum PrivacyLevel {
  publicToEveryone('PUBLIC_TO_EVERYONE', 'ทุกคน'),
  mutualFollowFriends('MUTUAL_FOLLOW_FRIENDS', 'เพื่อนที่ติดตามกัน'),
  followerOfCreator('FOLLOWER_OF_CREATOR', 'ผู้ติดตาม'),
  selfOnly('SELF_ONLY', 'เฉพาะฉัน');

  const PrivacyLevel(this.wire, this.label);

  /// ค่าที่ส่งให้ backend — ต้องตรงกับที่ TikTok กำหนดเป๊ะ
  final String wire;

  /// ข้อความที่แสดงให้ผู้ใช้เห็น
  final String label;

  static PrivacyLevel? parse(String raw) {
    for (final v in values) {
      if (v.wire == raw) return v;
    }
    // ค่าที่ไม่รู้จักต้องไม่แสดงเป็นตัวเลือก ดีกว่าเดาแล้วส่งค่าผิดไป TikTok
    return null;
  }

  bool get isSelfOnly => this == PrivacyLevel.selfOnly;
}

/// ข้อมูลสดของเจ้าของบัญชี จาก POST /v2/post/publish/creator_info/query/
///
/// ⚠️ TikTok ตรวจตอน audit ว่าแอปแสดงค่าพวกนี้ตรงกับสถานะจริงของบัญชี
/// ต้องดึงใหม่ทุกครั้งที่เปิดหน้า Composer ห้าม cache ข้ามรอบ
class CreatorInfo {
  const CreatorInfo({
    required this.username,
    required this.nickname,
    required this.avatarUrl,
    required this.privacyLevelOptions,
    required this.commentDisabled,
    required this.duetDisabled,
    required this.stitchDisabled,
    required this.maxVideoDurationSec,
  });

  final String username;
  final String nickname;

  /// avatar มี TTL 2 ชั่วโมงจากฝั่ง TikTok — ห้ามเก็บถาวร
  final String avatarUrl;

  /// ตัวเลือก privacy ที่ dropdown แสดงได้ (แปลงแล้ว ตัดค่าที่ไม่รู้จักทิ้ง)
  final List<PrivacyLevel> privacyLevelOptions;

  /// true = ผู้ใช้ปิดฟีเจอร์นี้ไว้ในบัญชี → ช่องนั้นต้อง **disable** ไม่ใช่แค่ไม่ติ๊ก
  final bool commentDisabled;
  final bool duetDisabled;
  final bool stitchDisabled;

  final int maxVideoDurationSec;

  /// ชื่อที่แสดงคู่กับ avatar — บังคับตามกฎ audit ข้อ R1
  String get handle => username.startsWith('@') ? username : '@$username';

  bool get canPublishPublic =>
      privacyLevelOptions.contains(PrivacyLevel.publicToEveryone);

  factory CreatorInfo.fromJson(Map<String, dynamic> json) {
    final options = <PrivacyLevel>[];
    for (final raw in (json['privacy_level_options'] as List? ?? const [])) {
      final level = PrivacyLevel.parse(raw as String);
      if (level != null) options.add(level);
    }

    return CreatorInfo(
      username: json['creator_username'] as String? ?? '',
      nickname: json['creator_nickname'] as String? ?? '',
      avatarUrl: json['creator_avatar_url'] as String? ?? '',
      privacyLevelOptions: options,
      commentDisabled: json['comment_disabled'] as bool? ?? false,
      duetDisabled: json['duet_disabled'] as bool? ?? false,
      stitchDisabled: json['stitch_disabled'] as bool? ?? false,
      maxVideoDurationSec: switch (json['max_video_post_duration_sec']) {
        int i => i,
        double d => d.toInt(),
        _ => 0,
      },
    );
  }
}
