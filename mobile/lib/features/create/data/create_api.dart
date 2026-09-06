import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/picked_video.dart';

/// ผลจากการขอ URL อัปโหลด
class UploadTicket {
  const UploadTicket({
    required this.assetId,
    required this.url,
    required this.headers,
  });

  final String assetId;
  final String url;

  /// ต้องส่ง header พวกนี้ไปตอน PUT ให้ครบและตรงเป๊ะ
  /// ไม่งั้นลายเซ็นของ presigned URL จะไม่ตรงและ storage จะปฏิเสธ
  final Map<String, String> headers;
}

abstract interface class CreateApi {
  Future<UploadTicket> requestUpload(String access, PickedVideo video);

  Future<void> upload(
    UploadTicket ticket,
    PickedVideo video, {
    void Function(int sent, int total)? onProgress,
  });

  /// ยืนยันว่าอัปเสร็จ — backend จะ HEAD เช็คของจริงก่อนรับ
  /// คืน public_url ไว้ให้แอปเปิด preview
  Future<String> completeUpload(String access, String assetId);

  Future<String> createContent(
    String access, {
    required String caption,
    required String mediaAssetId,
  });
}

class HttpCreateApi implements CreateApi {
  const HttpCreateApi(this.client, this.uploadDio);

  final ApiClient client;

  /// dio แยกสำหรับยิงไป storage โดยตรง
  /// ห้ามใช้ตัวเดียวกับที่คุยกับ backend เพราะ baseUrl กับ header ต่างกัน
  /// และที่สำคัญ — ห้ามแนบ Authorization ของเราไปกับ presigned URL
  final Dio uploadDio;

  @override
  Future<UploadTicket> requestUpload(String access, PickedVideo video) async {
    final data = await client.post(
      '/v1/media/upload-url',
      access: access,
      body: {
        'kind': 'video',
        'mime': video.mime,
        'size_bytes': video.sizeBytes,
        'source': 'upload',
      },
    );

    final asset = data['asset'] as Map<String, dynamic>;
    final upload = data['upload'] as Map<String, dynamic>;

    return UploadTicket(
      assetId: asset['id'] as String,
      url: upload['url'] as String,
      headers: (upload['headers'] as Map).map(
        (k, v) => MapEntry(k as String, v.toString()),
      ),
    );
  }

  @override
  Future<void> upload(
    UploadTicket ticket,
    PickedVideo video, {
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      await uploadDio.put<void>(
        ticket.url,
        // ส่งเป็น stream ไม่โหลดทั้งไฟล์เข้าหน่วยความจำ
        // วิดีโอ 100MB ที่อยู่ใน RAM ทั้งก้อนทำให้แอปถูกระบบฆ่าบนเครื่องสเปกต่ำ
        data: video.openRead(),
        options: Options(
          headers: ticket.headers,
          // storage ตอบ 200 เปล่า ๆ ไม่มี body
          responseType: ResponseType.plain,
        ),
        onSendProgress: onProgress,
      );
    } on DioException catch (e) {
      throw failureFrom(e);
    }
  }

  @override
  Future<String> completeUpload(String access, String assetId) async {
    final data = await client.post(
      '/v1/media/$assetId/complete',
      access: access,
      body: const <String, dynamic>{},
    );
    final asset = data['asset'] as Map<String, dynamic>? ?? const {};
    return asset['public_url'] as String? ?? '';
  }

  @override
  Future<String> createContent(
    String access, {
    required String caption,
    required String mediaAssetId,
  }) async {
    final data = await client.post(
      '/v1/contents',
      access: access,
      body: {'caption': caption, 'media_asset_id': mediaAssetId},
    );
    return (data['content'] as Map<String, dynamic>)['id'] as String;
  }
}
