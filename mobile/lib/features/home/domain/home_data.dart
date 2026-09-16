import '../../connections/domain/connection.dart';

/// สถานะงานโพสต์ ตรงกับ publish_jobs.status ฝั่ง backend
enum JobStatus {
  draft,
  awaitingReview,
  scheduled,
  queued,
  uploading,
  processing,
  published,
  failed,
  cancelled,
  unknown;

  static JobStatus parse(String? raw) => switch (raw) {
    'draft' => JobStatus.draft,
    'awaiting_review' => JobStatus.awaitingReview,
    'scheduled' => JobStatus.scheduled,
    'queued' => JobStatus.queued,
    'uploading' => JobStatus.uploading,
    'processing' => JobStatus.processing,
    'published' => JobStatus.published,
    'failed' => JobStatus.failed,
    'cancelled' => JobStatus.cancelled,
    _ => JobStatus.unknown,
  };

  /// กำลังทำงานอยู่ = ระบบกำลังจัดการให้ ผู้ใช้ไม่ต้องทำอะไร
  bool get isWorking => switch (this) {
    JobStatus.queued || JobStatus.uploading || JobStatus.processing => true,
    _ => false,
  };

  String get label => switch (this) {
    JobStatus.draft => 'ฉบับร่าง',
    JobStatus.awaitingReview => 'รอตรวจ',
    JobStatus.scheduled => 'รอถึงเวลา',
    JobStatus.queued => 'เข้าคิวแล้ว',
    JobStatus.uploading => 'กำลังส่งขึ้น TikTok',
    JobStatus.processing => 'TikTok กำลังประมวลผล',
    JobStatus.published => 'โพสต์แล้ว',
    JobStatus.failed => 'ไม่สำเร็จ',
    JobStatus.cancelled => 'ยกเลิกแล้ว',
    JobStatus.unknown => 'ไม่ทราบสถานะ',
  };
}

class PublishJob {
  const PublishJob({
    required this.id,
    required this.contentId,
    required this.platform,
    required this.status,
    required this.scheduledAt,
    this.permalink = '',
    this.errorMessage = '',
    this.caption = '',
    this.productId,
    this.sourceLabel = '',
    this.remixOfId,
  });

  final String id;
  final String contentId;
  final String platform;
  final JobStatus status;
  final DateTime scheduledAt;
  final String permalink;
  final String errorMessage;

  /// caption มาจากการ join กับ /v1/contents ฝั่งแอป
  /// backend ไม่ได้ส่งมาด้วยเพราะ publish_jobs เก็บแค่ content_id
  final String caption;

  /// สินค้าที่ปักตะกร้ากับงานนี้ — ใช้เชื่อมหน้า Showcase กับคอนเทนต์
  /// null สำหรับงานเก่าที่ backend ยังไม่ผูกสินค้า
  final String? productId;

  /// ที่มาของคอนเทนต์ เช่น "AI Content Inbox · Google Flow" หรือ "อัปโหลดเอง"
  final String sourceLabel;

  /// ถ้างานนี้เกิดจากการรีมิกซ์งานเดิม เก็บ id ของงานต้นทางไว้
  final String? remixOfId;

  /// ข้อความที่ใช้แทนชื่องานในรายการ
  String get title {
    final t = caption.trim();
    if (t.isEmpty) return 'ไม่มีคำบรรยาย';
    final firstLine = t.split('\n').first;
    return firstLine.length <= 60
        ? firstLine
        : '${firstLine.substring(0, 60)}…';
  }

  PublishJob withCaption(String c) => copyWith(caption: c);

  PublishJob copyWith({
    JobStatus? status,
    DateTime? scheduledAt,
    String? permalink,
    String? errorMessage,
    String? caption,
    String? productId,
    String? sourceLabel,
    String? remixOfId,
  }) => PublishJob(
    id: id,
    contentId: contentId,
    platform: platform,
    status: status ?? this.status,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    permalink: permalink ?? this.permalink,
    errorMessage: errorMessage ?? this.errorMessage,
    caption: caption ?? this.caption,
    productId: productId ?? this.productId,
    sourceLabel: sourceLabel ?? this.sourceLabel,
    remixOfId: remixOfId ?? this.remixOfId,
  );

  factory PublishJob.fromJson(Map<String, dynamic> json) => PublishJob(
    id: json['id'] as String,
    contentId: json['content_id'] as String? ?? '',
    platform: json['platform'] as String? ?? '',
    status: JobStatus.parse(json['status'] as String?),
    scheduledAt:
        DateTime.tryParse(json['scheduled_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    permalink: json['permalink'] as String? ?? '',
    errorMessage: json['last_error'] is Map
        ? ((json['last_error'] as Map)['message'] as String? ?? '')
        : '',
    productId: json['product_id'] as String?,
    remixOfId: json['remix_of_id'] as String?,
  );
}

/// สิ่งที่ต้องให้ผู้ใช้ลงมือทำ — ขึ้นบนสุดของหน้าหลักเสมอ
class ActionItem {
  const ActionItem({
    required this.kind,
    required this.title,
    required this.detail,
    required this.actionLabel,
    this.jobId,
    this.connectionId,
  });

  final ActionKind kind;
  final String title;
  final String detail;
  final String actionLabel;
  final String? jobId;
  final String? connectionId;
}

enum ActionKind { needsReauth, jobFailed }

/// HomeData จัดกลุ่มงานตาม "ความเร่งด่วนของสิ่งที่ผู้ใช้ต้องทำ"
/// ไม่ใช่เรียงตามเวลา
///
/// เหตุผล: หน้านี้ต้องตอบคำถามเดียวคือ "ตอนนี้มีอะไรต้องทำ"
/// ถ้าเรียงตามเวลา งานที่ล้มเหลวเมื่อวานจะจมอยู่ล่างสุดโดยไม่มีใครเห็น
class HomeData {
  const HomeData({
    this.jobs = const [],
    this.needAction = const [],
    this.reviewQueue = const [],
    this.working = const [],
    this.scheduled = const [],
    this.publishedToday = const [],
  });

  /// Raw jobs returned by the backend. The grouped lists below are derived
  /// views for the home dashboard; keeping this list prevents other screens
  /// from maintaining a second, divergent copy of the same data.
  final List<PublishJob> jobs;

  final List<ActionItem> needAction;

  /// งานที่ทำเสร็จแล้วรอผู้ใช้ตรวจ/อนุมัติ — ป้อนคิว Swipe Review
  final List<PublishJob> reviewQueue;
  final List<PublishJob> working;
  final List<PublishJob> scheduled;
  final List<PublishJob> publishedToday;

  bool get isEmpty =>
      needAction.isEmpty &&
      reviewQueue.isEmpty &&
      working.isEmpty &&
      scheduled.isEmpty &&
      publishedToday.isEmpty;

  /// build จัดกลุ่มจากข้อมูลดิบ — เป็น logic ล้วน เทสได้โดยไม่ต้องต่อ network
  static HomeData build({
    required List<PublishJob> jobs,
    required List<Connection> connections,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();

    final actions = <ActionItem>[];

    // บัญชีที่หลุดการเชื่อมต่อขึ้นก่อน เพราะมันบล็อกงานทั้งหมดของบัญชีนั้น
    for (final c in connections) {
      if (!c.status.isUsable) {
        actions.add(
          ActionItem(
            kind: ActionKind.needsReauth,
            title: '${_platformName(c.provider)} หลุดการเชื่อมต่อ',
            detail: 'โพสต์ที่ตั้งเวลาไว้จะยังไม่ถูกส่งจนกว่าจะเชื่อมใหม่',
            actionLabel: 'เชื่อมใหม่',
            connectionId: c.id,
          ),
        );
      }
    }

    final working = <PublishJob>[];
    final scheduled = <PublishJob>[];
    final published = <PublishJob>[];
    final review = <PublishJob>[];

    for (final j in jobs) {
      switch (j.status) {
        case JobStatus.awaitingReview:
          review.add(j);
        case JobStatus.failed:
          actions.add(
            ActionItem(
              kind: ActionKind.jobFailed,
              title: 'โพสต์ไม่สำเร็จ',
              detail: j.errorMessage.isEmpty ? j.title : j.errorMessage,
              actionLabel: 'ดูสาเหตุ',
              jobId: j.id,
            ),
          );
        case JobStatus.published:
          if (_isSameDay(j.scheduledAt, today)) published.add(j);
        case JobStatus.scheduled:
          scheduled.add(j);
        case JobStatus.draft || JobStatus.cancelled || JobStatus.unknown:
          break;
        default:
          if (j.status.isWorking) working.add(j);
      }
    }

    // งานที่ตั้งเวลาไว้เรียงจากใกล้ถึงเวลาที่สุด — อันที่จะเกิดก่อนอยู่บน
    scheduled.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    published.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    review.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return HomeData(
      jobs: List.unmodifiable(jobs),
      needAction: actions,
      reviewQueue: review,
      working: working,
      scheduled: scheduled,
      publishedToday: published,
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _platformName(String provider) => switch (provider) {
    'tiktok' => 'TikTok',
    'facebook' => 'Facebook',
    'instagram' => 'Instagram',
    'youtube' => 'YouTube',
    _ => provider,
  };
}
