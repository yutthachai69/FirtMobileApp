/// สถานะการเชื่อมต่อบัญชีแพลตฟอร์ม
enum ConnectionStatus {
  active,
  expired,
  needsReauth,
  revoked,
  unknown;

  static ConnectionStatus parse(String? raw) => switch (raw) {
        'active' => ConnectionStatus.active,
        'expired' => ConnectionStatus.expired,
        'needs_reauth' => ConnectionStatus.needsReauth,
        'revoked' => ConnectionStatus.revoked,
        _ => ConnectionStatus.unknown,
      };

  bool get isUsable => this == ConnectionStatus.active;

  /// ข้อความที่แสดงให้ผู้ใช้เห็น — ต้องบอกว่าต้องทำอะไรต่อ ไม่ใช่แค่บอกสถานะ
  String get label => switch (this) {
        ConnectionStatus.active => 'เชื่อมต่อแล้ว',
        ConnectionStatus.expired => 'หมดอายุ — แตะเพื่อเชื่อมใหม่',
        ConnectionStatus.needsReauth => 'หลุดการเชื่อมต่อ — แตะเพื่อเชื่อมใหม่',
        ConnectionStatus.revoked => 'ถูกถอนสิทธิ์ — แตะเพื่อเชื่อมใหม่',
        ConnectionStatus.unknown => 'ไม่ทราบสถานะ',
      };
}

/// สิ่งที่บัญชีนี้ทำได้ "ตอนนี้" — มาจาก creator_info ของจริง ไม่ใช่ค่าที่เราเดา
///
/// ⚠️ หน้าจอต้องอ่านค่าจากตรงนี้ไป render ห้าม hardcode
/// เพราะ [canPublishPublic] จะเป็น false จนกว่า TikTok app จะผ่าน audit
/// ถ้า hardcode ว่าโพสต์สาธารณะได้ ผู้ใช้จะกดโพสต์แล้วเจอ error โดยไม่รู้สาเหตุ
class ConnectionCapabilities {
  const ConnectionCapabilities({
    this.canPublishPublic = false,
    this.privacyLevelOptions = const [],
    this.commentDisabled = false,
    this.duetDisabled = false,
    this.stitchDisabled = false,
    this.maxVideoDurationSec = 0,
    this.maxPostsPerDay = 0,
  });

  final bool canPublishPublic;
  final List<String> privacyLevelOptions;
  final bool commentDisabled;
  final bool duetDisabled;
  final bool stitchDisabled;
  final int maxVideoDurationSec;
  final int maxPostsPerDay;

  bool get isEmpty => privacyLevelOptions.isEmpty;

  factory ConnectionCapabilities.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ConnectionCapabilities();
    return ConnectionCapabilities(
      canPublishPublic: json['can_publish_public'] as bool? ?? false,
      privacyLevelOptions:
          (json['privacy_level_options'] as List?)?.cast<String>() ?? const [],
      commentDisabled: json['comment_disabled'] as bool? ?? false,
      duetDisabled: json['duet_disabled'] as bool? ?? false,
      stitchDisabled: json['stitch_disabled'] as bool? ?? false,
      maxVideoDurationSec: _int(json['max_video_duration_sec']),
      maxPostsPerDay: _int(json['max_posts_per_day']),
    );
  }
}

class Connection {
  const Connection({
    required this.id,
    required this.provider,
    required this.status,
    required this.capabilities,
    this.displayName = '',
  });

  final String id;
  final String provider;
  final String displayName;
  final ConnectionStatus status;
  final ConnectionCapabilities capabilities;

  bool get isTikTok => provider == 'tiktok';

  factory Connection.fromJson(Map<String, dynamic> json) => Connection(
        id: json['id'] as String,
        provider: json['provider'] as String,
        displayName: json['display_name'] as String? ?? '',
        status: ConnectionStatus.parse(json['status'] as String?),
        capabilities: ConnectionCapabilities.fromJson(
          json['capabilities'] as Map<String, dynamic>?,
        ),
      );
}

/// ผลลัพธ์ของ GET /v1/connections
///
/// [tiktokEnabled] บอกว่าเซิร์ฟเวอร์ตั้งค่า TikTok app ไว้หรือยัง
/// ถ้ายัง ปุ่ม "เชื่อม TikTok" ต้อง disable พร้อมบอกเหตุผล
/// ไม่ใช่ปล่อยให้กดแล้วเจอ 503
class ConnectionList {
  const ConnectionList({required this.items, required this.tiktokEnabled});

  final List<Connection> items;
  final bool tiktokEnabled;

  Connection? get tiktok {
    for (final c in items) {
      if (c.isTikTok) return c;
    }
    return null;
  }
}

int _int(Object? v) => switch (v) {
      int i => i,
      double d => d.toInt(),
      String s => int.tryParse(s) ?? 0,
      _ => 0,
    };
