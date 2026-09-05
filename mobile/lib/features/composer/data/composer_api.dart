import '../../../core/network/api_client.dart';
import '../domain/creator_info.dart';

abstract interface class ComposerApi {
  /// ต้องเรียกทุกครั้งที่เปิดหน้า Composer — ห้าม cache ข้ามรอบ
  /// TikTok ตรวจตอน audit ว่าค่าที่แสดงตรงกับสถานะจริงของบัญชี
  Future<CreatorInfo> creatorInfo(String access, String connectionId);

  Future<PublishJob> schedule(
    String access, {
    required String contentId,
    required String connectionId,
    required Map<String, dynamic> platformOptions,
    required String idempotencyKey,
    DateTime? scheduledAt,
  });
}

class PublishJob {
  const PublishJob({required this.id, required this.status});
  final String id;
  final String status;

  factory PublishJob.fromJson(Map<String, dynamic> j) => PublishJob(
        id: j['id'] as String,
        status: j['status'] as String? ?? 'scheduled',
      );
}

class HttpComposerApi implements ComposerApi {
  const HttpComposerApi(this.client);
  final ApiClient client;

  @override
  Future<CreatorInfo> creatorInfo(String access, String connectionId) async {
    final data = await client.get(
      '/v1/connections/$connectionId/creator-info',
      access: access,
    );
    return CreatorInfo.fromJson(
      data['creator_info'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  Future<PublishJob> schedule(
    String access, {
    required String contentId,
    required String connectionId,
    required Map<String, dynamic> platformOptions,
    required String idempotencyKey,
    DateTime? scheduledAt,
  }) async {
    final data = await client.post(
      '/v1/publish-jobs',
      access: access,
      // Idempotency-Key ต้องเป็นค่าเดิมทุกครั้งที่ยิงซ้ำ
      // ถ้าสร้างใหม่ทุกครั้ง เน็ตหลุดแล้วกดใหม่จะได้โพสต์ซ้ำบน TikTok ซึ่งกู้ไม่ได้
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'content_id': contentId,
        'connection_id': connectionId,
        'platform_options': platformOptions,
        if (scheduledAt != null)
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      },
    );
    return PublishJob.fromJson(data['job'] as Map<String, dynamic>);
  }
}
