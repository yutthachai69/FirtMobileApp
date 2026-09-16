import '../../../core/network/api_client.dart';
import '../../connections/data/connections_api.dart';
import '../../connections/domain/connection.dart';
import 'publish_jobs_api.dart';
import '../domain/home_data.dart';

/// Repository กลางของ content snapshot และ publish-job lifecycle
///
/// Demo fakes สามารถ override เฉพาะ [load] ได้ ส่วน live implementation
/// รองรับทุก mutation ผ่าน API เดียวกัน ทำให้หน้าต่าง ๆ ไม่ถือ repository แยก
/// และไม่เผลอแก้เฉพาะ in-memory store แล้วลืม persist.
abstract class HomeApi {
  Future<HomeData> load(String access);

  Future<PublishJob> get(String access, String jobId) =>
      throw UnsupportedError('job detail is not available in this repository');

  Future<PublishJob> retry(String access, String jobId) =>
      throw UnsupportedError('retry is not available in this repository');

  Future<void> cancel(String access, String jobId) =>
      throw UnsupportedError('cancel is not available in this repository');

  Future<PublishJob> reschedule(
    String access,
    String jobId,
    DateTime scheduledAt,
  ) => throw UnsupportedError('reschedule is not available in this repository');

  Future<PublishJob> restore(String access, String jobId) =>
      throw UnsupportedError('restore is not available in this repository');
}

class HttpHomeApi implements HomeApi {
  const HttpHomeApi(this.client, this.connections);
  final ApiClient client;
  final ConnectionsApi connections;

  @override
  Future<HomeData> load(String access) async {
    // ยิงพร้อมกันทั้งสามเส้น หน้าหลักจะได้ไม่ต้องรอต่อกันเป็นทอด ๆ
    final results = await Future.wait([
      client.get('/v1/publish-jobs', access: access, query: {'limit': 50}),
      client.get('/v1/contents', access: access, query: {'limit': 50}),
      connections.list(access),
    ]);

    final jobsRaw =
        (results[0] as Map<String, dynamic>)['jobs'] as List? ?? const [];
    final contentsRaw =
        (results[1] as Map<String, dynamic>)['contents'] as List? ?? const [];
    final connList = results[2] as ConnectionList;

    // backend เก็บ caption ไว้ที่ contents ไม่ได้ส่งมากับ publish_jobs
    // (publish_jobs อ้างแค่ content_id) จึง join ฝั่งแอป
    final captions = <String, String>{};
    for (final c in contentsRaw.cast<Map<String, dynamic>>()) {
      captions[c['id'] as String] = c['caption'] as String? ?? '';
    }

    final jobs = jobsRaw
        .cast<Map<String, dynamic>>()
        .map(PublishJob.fromJson)
        .map((j) => j.withCaption(captions[j.contentId] ?? ''))
        .toList();

    return HomeData.build(jobs: jobs, connections: connList.items);
  }

  @override
  Future<PublishJob> get(String access, String jobId) async {
    final data = await client.get('/v1/publish-jobs/$jobId', access: access);
    final raw = data['job'];
    if (raw is! Map<String, dynamic>) {
      throw StateError('Job response did not include a publish job');
    }
    final job = PublishJob.fromJson(raw);
    return _withCaption(access, job);
  }

  @override
  Future<PublishJob> retry(String access, String jobId) =>
      _jobsApi.retry(access, jobId);

  @override
  Future<void> cancel(String access, String jobId) =>
      _jobsApi.cancel(access, jobId);

  @override
  Future<PublishJob> reschedule(
    String access,
    String jobId,
    DateTime scheduledAt,
  ) => _jobsApi.reschedule(access, jobId, scheduledAt);

  @override
  Future<PublishJob> restore(String access, String jobId) =>
      _jobsApi.restore(access, jobId);

  HttpPublishJobsApi get _jobsApi => HttpPublishJobsApi(client);

  Future<PublishJob> _withCaption(String access, PublishJob job) async {
    final data = await client.get(
      '/v1/contents/${job.contentId}',
      access: access,
    );
    final raw = data['content'];
    if (raw is! Map<String, dynamic>) return job;
    return job.withCaption(raw['caption'] as String? ?? '');
  }
}
