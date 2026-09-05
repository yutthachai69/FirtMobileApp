import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/app.dart';
import 'package:relaycontent/app/providers.dart';
import 'package:relaycontent/core/auth/auth_controller.dart';
import 'package:relaycontent/features/auth/domain/session.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('login, home, restart and logout', (tester) async {
    final api = FakeAuthApi();
    final store = MemoryTokenStore();
    final auth = AuthController(api, store);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWithValue(auth)],
        child: const RelayApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ยินดีต้อนรับกลับ'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('email')), 'user@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'password');
    await tester.ensureVisible(find.byKey(const Key('submit')));
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(find.text('บัญชีของคุณ'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    final restarted = AuthController(api, store);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWithValue(restarted)],
        child: const RelayApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('บัญชีของคุณ'), findsOneWidget);
    expect(api.loginCount, 1);
    await tester.ensureVisible(find.text('ออกจากระบบ'));
    await tester.tap(find.text('ออกจากระบบ'));
    await tester.pumpAndSettle();
    expect(find.text('ยินดีต้อนรับกลับ'), findsOneWidget);
    expect(store.value, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    restarted.dispose();
  });

  testWidgets('invalid inputs and server errors stay on login', (tester) async {
    final api = FakeAuthApi()
      ..loginFailure = const AuthFailure(
        'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
        status: 401,
      );
    final auth = AuthController(api, MemoryTokenStore());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWithValue(auth)],
        child: const RelayApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('submit')));
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(api.loginCount, 0);
    expect(find.text('กรุณากรอกอีเมลให้ถูกต้อง'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('email')), 'user@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'incorrect');
    await tester.ensureVisible(find.byKey(const Key('submit')));
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(find.text('อีเมลหรือรหัสผ่านไม่ถูกต้อง'), findsOneWidget);
    expect(auth.phase, SessionPhase.signedOut);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });
}
