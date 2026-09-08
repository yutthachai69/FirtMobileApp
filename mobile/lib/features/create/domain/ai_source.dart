// โมเดลของ AI Content Inbox — ยังเป็น mock-first ไม่มี backend จริง
//
// จำลองสามอย่างที่เส้นทางจริงต้องเจอ: การเชื่อมบัญชี, การตรวจว่าแหล่งนั้น
// ทำอะไรได้บ้าง (capability) และการนำเข้าที่ทำงานอยู่เบื้องหลังแล้วอาจล้มเหลว

enum SourceStatus { connected, disconnected, needsAttention }

class AiSource {
  const AiSource({
    required this.id,
    required this.name,
    required this.status,
    this.supportsVerticalVideo = true,
    this.supportsDirectImport = true,
    this.note,
  });

  final String id;
  final String name;
  final SourceStatus status;

  /// รองรับวิดีโอแนวตั้ง 9:16 ที่ TikTok ต้องการหรือไม่
  final bool supportsVerticalVideo;

  /// ดึงไฟล์เข้ามาได้ตรง ๆ หรือผู้ใช้ต้อง Share เอง
  final bool supportsDirectImport;

  /// ข้อความเตือนเรื่องข้อจำกัดของแหล่งนี้ แสดงใต้ชิปเมื่อ needsAttention
  final String? note;

  bool get isConnected => status != SourceStatus.disconnected;

  AiSource copyWith({SourceStatus? status, String? note}) => AiSource(
    id: id,
    name: name,
    status: status ?? this.status,
    supportsVerticalVideo: supportsVerticalVideo,
    supportsDirectImport: supportsDirectImport,
    note: note ?? this.note,
  );

  static const seed = [
    AiSource(
      id: 'google-flow',
      name: 'Google Flow',
      status: SourceStatus.connected,
    ),
    AiSource(
      id: 'sora',
      name: 'Sora',
      status: SourceStatus.disconnected,
      supportsVerticalVideo: false,
      note: 'ส่งออกเป็น 16:9 — ต้องครอปเป็นแนวตั้งก่อนโพสต์',
    ),
    AiSource(
      id: 'runway',
      name: 'Runway',
      status: SourceStatus.disconnected,
      supportsDirectImport: false,
      note: 'ยังเชื่อมตรงไม่ได้ — ใช้ปุ่ม Share จากแอป Runway',
    ),
  ];
}

enum InboxStatus { ready, importing, failed }

class InboxItem {
  const InboxItem({
    required this.id,
    required this.title,
    required this.sourceId,
    required this.sourceName,
    required this.status,
    required this.durationSec,
    required this.updatedAt,
    this.progress = 1,
    this.vertical = true,
    this.failureReason,
  });

  final String id;
  final String title;
  final String sourceId;
  final String sourceName;
  final InboxStatus status;
  final int durationSec;
  final DateTime updatedAt;

  /// 0..1 ระหว่าง importing
  final double progress;
  final bool vertical;
  final String? failureReason;

  bool get isReady => status == InboxStatus.ready;

  InboxItem copyWith({
    InboxStatus? status,
    double? progress,
    DateTime? updatedAt,
    String? failureReason,
  }) => InboxItem(
    id: id,
    title: title,
    sourceId: sourceId,
    sourceName: sourceName,
    status: status ?? this.status,
    durationSec: durationSec,
    updatedAt: updatedAt ?? this.updatedAt,
    progress: progress ?? this.progress,
    vertical: vertical,
    failureReason: failureReason,
  );
}
