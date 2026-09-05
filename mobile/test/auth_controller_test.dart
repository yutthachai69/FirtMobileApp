import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/core/auth/auth_controller.dart';
import 'package:relaycontent/features/auth/domain/session.dart';

import 'support/fakes.dart';

void main() {
  late FakeAuthApi api;
  late MemoryTokenStore store;
  late AuthController auth;
  setUp(() {
    api = FakeAuthApi();
    store = MemoryTokenStore();
    auth = AuthController(api, store);
  });
  tearDown(() {
    auth.dispose();
  });

  test('cold start without credentials shows login', () async {
    await auth.restore();
    expect(auth.phase, SessionPhase.signedOut);
    expect(api.refreshCount, 0);
  });
  test(
    'login and process restart restore same account with rotated tokens',
    () async {
      await auth.authenticate('user@example.com', 'password');
      expect(store.value?.refresh, 'refresh-1');
      final restarted = AuthController(api, store);
      await restarted.restore();
      expect(restarted.account?.id, auth.account?.id);
      expect(restarted.phase, SessionPhase.signedIn);
      expect(store.value?.refresh, 'refresh-2');
      restarted.dispose();
    },
  );
  test('network outage keeps saved credentials and retry recovers', () async {
    store.value = testTokens;
    api.refreshFailure = const AuthFailure('offline');
    await auth.restore();
    expect(auth.phase, SessionPhase.unavailable);
    expect(store.value, testTokens);
    api.refreshFailure = null;
    await auth.restore();
    expect(auth.phase, SessionPhase.signedIn);
  });
  test('rejected refresh clears saved credentials', () async {
    store.value = testTokens;
    api.refreshFailure = const AuthFailure('expired', status: 401);
    await auth.restore();
    expect(auth.phase, SessionPhase.signedOut);
    expect(store.value, isNull);
  });
  test('simultaneous 401 responses only rotate once', () async {
    await auth.authenticate('user@example.com', 'password');
    api.rejectOldAccess = true;
    api.refreshGate = Completer<void>();
    final first = auth.currentAccount();
    final second = auth.currentAccount();
    await Future<void>.delayed(Duration.zero);
    expect(api.refreshCount, 1);
    api.refreshGate!.complete();
    final results = await Future.wait([first, second]);
    expect(results.map((u) => u.id), ['user-1', 'user-1']);
    expect(store.value?.refresh, 'refresh-2');
  });
  test('logout revokes latest credentials and clears local session', () async {
    store.value = testTokens;
    await auth.restore();
    await auth.signOut();
    expect(api.revoked, 'refresh-2');
    expect(store.value, isNull);
    expect(auth.phase, SessionPhase.signedOut);
  });
  test('offline logout still clears local session', () async {
    await auth.authenticate('user@example.com', 'password');
    api.logoutOffline = true;
    await auth.signOut();
    expect(store.value, isNull);
    expect(auth.phase, SessionPhase.signedOut);
    expect(auth.error, isNotNull);
  });
}
