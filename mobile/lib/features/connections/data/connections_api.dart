import '../../../core/network/api_client.dart';
import '../domain/connection.dart';

abstract interface class ConnectionsApi {
  Future<ConnectionList> list(String access);

  /// เริ่ม OAuth — คืน URL ที่ต้องเปิดใน in-app browser
  Future<String> startTikTokOAuth(String access);

  Future<void> remove(String access, String connectionId);

  /// ข้อมูลสดของ creator สำหรับหน้า Composer
  Future<Map<String, dynamic>> creatorInfo(String access, String connectionId);
}

class HttpConnectionsApi implements ConnectionsApi {
  const HttpConnectionsApi(this.client);
  final ApiClient client;

  @override
  Future<ConnectionList> list(String access) async {
    final data = await client.get('/v1/connections', access: access);

    final items = (data['connections'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Connection.fromJson)
        .toList();

    // providers.tiktok.enabled บอกว่า backend ตั้งค่า TikTok app ไว้หรือยัง
    final providers = data['providers'] as Map<String, dynamic>?;
    final tiktok = providers?['tiktok'] as Map<String, dynamic>?;

    return ConnectionList(
      items: items,
      tiktokEnabled: tiktok?['enabled'] as bool? ?? false,
    );
  }

  @override
  Future<String> startTikTokOAuth(String access) async {
    final data = await client.post('/v1/oauth/tiktok/start', access: access);
    final url = data['authorize_url'] as String?;
    if (url == null || url.isEmpty) {
      throw const AuthFailureMissingUrl();
    }
    return url;
  }

  @override
  Future<void> remove(String access, String connectionId) =>
      client.delete('/v1/connections/$connectionId', access: access);

  @override
  Future<Map<String, dynamic>> creatorInfo(
    String access,
    String connectionId,
  ) async {
    final data = await client.get(
      '/v1/connections/$connectionId/creator-info',
      access: access,
    );
    return data['creator_info'] as Map<String, dynamic>? ?? const {};
  }
}

/// เซิร์ฟเวอร์ตอบ 200 แต่ไม่มี authorize_url — ไม่ควรเกิด แต่ต้องไม่ crash
class AuthFailureMissingUrl implements Exception {
  const AuthFailureMissingUrl();
  @override
  String toString() => 'เริ่มการเชื่อมต่อไม่สำเร็จ กรุณาลองใหม่';
}
