import '../../../core/network/api_client.dart';
import '../../connections/data/connections_api.dart';
import '../../connections/domain/connection.dart';
import '../domain/home_data.dart';

abstract interface class HomeApi {
  Future<HomeData> load(String access);
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

    final jobsRaw = (results[0] as Map<String, dynamic>)['jobs'] as List? ?? const [];
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
}
