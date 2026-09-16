import '../../../core/network/api_client.dart';
import '../domain/app_notification.dart';

abstract interface class NotificationsApi {
  Future<List<AppNotification>> list(String access, {bool unreadOnly = false});

  Future<void> markAllRead(String access);
}

class HttpNotificationsApi implements NotificationsApi {
  const HttpNotificationsApi(this.client);

  final ApiClient client;

  @override
  Future<List<AppNotification>> list(
    String access, {
    bool unreadOnly = false,
  }) async {
    final response = await client.get(
      '/v1/notifications',
      access: access,
      query: {'limit': 50, 'unread': unreadOnly},
    );
    final raw = response['notifications'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (item) => AppNotification.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  @override
  Future<void> markAllRead(String access) async {
    await client.post('/v1/notifications/read-all', access: access);
  }
}
