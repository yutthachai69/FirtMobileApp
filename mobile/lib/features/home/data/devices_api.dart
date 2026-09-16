import '../../../core/network/api_client.dart';

abstract interface class DevicesApi {
  Future<bool> register(String access, String token, String platform);

  Future<void> remove(String access, String token);
}

class HttpDevicesApi implements DevicesApi {
  const HttpDevicesApi(this.client);

  final ApiClient client;

  @override
  Future<bool> register(String access, String token, String platform) async {
    final response = await client.post(
      '/v1/devices',
      access: access,
      body: {'fcm_token': token, 'platform': platform},
    );
    return response['push_enabled'] as bool? ?? false;
  }

  @override
  Future<void> remove(String access, String token) async {
    await client.delete(
      '/v1/devices',
      access: access,
      body: {'fcm_token': token},
    );
  }
}
