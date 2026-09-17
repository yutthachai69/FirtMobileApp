import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/core/auth/auth_controller.dart';
import 'package:relaycontent/features/auth/data/auth_api.dart';

import 'support/fakes.dart';

void main() {
  test('real backend: auth and live data endpoints', () async {
    final dio = Dio(
      BaseOptions(
        baseUrl: const String.fromEnvironment(
          'TEST_API_BASE_URL',
          defaultValue: 'http://127.0.0.1:8080',
        ),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final api = HttpAuthApi(dio);
    final store = MemoryTokenStore();
    final email =
        'mobile-test-${DateTime.now().microsecondsSinceEpoch}@example.com';
    final password = 'Test-${DateTime.now().microsecondsSinceEpoch}-password';
    final registered = await api.register(
      email,
      password,
      'Mobile integration test',
    );
    await api.logout(registered.tokens.refresh);
    final auth = AuthController(api, store);
    await auth.restore();
    await auth.authenticate(email, password);
    expect(auth.phase, SessionPhase.signedIn, reason: auth.error);
    expect(auth.account?.id, registered.account.id);

    final accessHeaders = {
      'Authorization': 'Bearer ${registered.tokens.access}',
    };
    for (final path in const [
      '/v1/products',
      '/v1/contents',
      '/v1/publish-jobs',
    ]) {
      final response = await dio.get<Map<String, dynamic>>(
        path,
        queryParameters: const {'limit': 50},
        options: Options(headers: accessHeaders),
      );
      expect(response.statusCode, 200, reason: path);
      final data = response.data ?? const <String, dynamic>{};
      final key = switch (path) {
        '/v1/products' => 'products',
        '/v1/contents' => 'contents',
        '/v1/publish-jobs' => 'jobs',
        _ => path.split('/').last,
      };
      expect(data[key], isA<List>(), reason: 'Expected $key list');
    }

    final restarted = AuthController(api, store);
    await restarted.restore();
    expect(restarted.phase, SessionPhase.signedIn, reason: restarted.error);
    expect((await restarted.currentAccount()).email, email);
    await restarted.signOut();
    expect(store.value, isNull);
    expect(restarted.phase, SessionPhase.signedOut);
    // Only the test account ID is printed; credentials are never logged.
    // ignore: avoid_print
    print('Created test user: ${registered.account.id}');
    auth.dispose();
    restarted.dispose();
    dio.close();
  }, skip: !const bool.fromEnvironment('RUN_LIVE_BACKEND_TEST'));
}
