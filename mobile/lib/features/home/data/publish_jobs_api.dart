import '../../../core/network/api_client.dart';
import '../domain/home_data.dart';

/// Mutations supported by the publish-jobs API.
///
/// Keeping these calls separate from [HomeApi] makes it explicit which UI
/// actions are backed by the server and which are still local-only prototype
/// affordances.
abstract interface class PublishJobsApi {
  Future<PublishJob> retry(String access, String jobId);

  Future<void> cancel(String access, String jobId);

  Future<PublishJob> reschedule(
    String access,
    String jobId,
    DateTime scheduledAt,
  );

  Future<PublishJob> restore(String access, String jobId);
}

class HttpPublishJobsApi implements PublishJobsApi {
  const HttpPublishJobsApi(this.client);
  final ApiClient client;

  @override
  Future<PublishJob> retry(String access, String jobId) async {
    final data = await client.post(
      '/v1/publish-jobs/$jobId/retry',
      access: access,
    );
    final raw = data['job'];
    if (raw is! Map<String, dynamic>) {
      throw StateError('Retry response did not include a publish job');
    }
    return PublishJob.fromJson(raw);
  }

  @override
  Future<void> cancel(String access, String jobId) async {
    await client.post('/v1/publish-jobs/$jobId/cancel', access: access);
  }

  @override
  Future<PublishJob> reschedule(
    String access,
    String jobId,
    DateTime scheduledAt,
  ) async {
    final data = await client.post(
      '/v1/publish-jobs/$jobId/reschedule',
      access: access,
      body: {'scheduled_at': scheduledAt.toUtc().toIso8601String()},
    );
    return _jobFromResponse(data, 'Reschedule');
  }

  @override
  Future<PublishJob> restore(String access, String jobId) async {
    final data = await client.post(
      '/v1/publish-jobs/$jobId/restore',
      access: access,
    );
    return _jobFromResponse(data, 'Restore');
  }

  PublishJob _jobFromResponse(Map<String, dynamic> data, String action) {
    final raw = data['job'];
    if (raw is! Map<String, dynamic>) {
      throw StateError('$action response did not include a publish job');
    }
    return PublishJob.fromJson(raw);
  }
}
