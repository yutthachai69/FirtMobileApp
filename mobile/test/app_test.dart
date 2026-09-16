import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/app.dart';
import 'package:relaycontent/app/providers.dart';
import 'package:relaycontent/core/auth/auth_controller.dart';
import 'package:relaycontent/features/auth/domain/session.dart';
import 'package:relaycontent/features/home/domain/content_store.dart';
import 'package:relaycontent/features/home/presentation/home_controller.dart';

import 'support/fakes.dart';

/// หน้าหลักเริ่มเปล่าในเทสนี้ เพื่อตรวจ empty state และเส้นทาง auth
final _emptyStore = contentStoreProvider.overrideWithValue(
  ContentStore(jobs: const []),
);

void main() {
  testWidgets('login, home, restart and logout', (tester) async {
    final api = FakeAuthApi();
    final store = MemoryTokenStore();
    final auth = AuthController(api, store);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWithValue(auth),
          homeProvider.overrideWithValue(HomeController(auth, FakeHomeApi())),
          _emptyStore,
        ],
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
    // หน้าหลักใหม่เป็นห้องควบคุม ไม่ใช่หน้าโปรไฟล์
    expect(find.text('สวัสดี, Tester'), findsOneWidget);
    expect(find.text('เปลี่ยนคอนเทนต์ให้พร้อมขาย'), findsOneWidget);
    expect(find.byKey(const Key('home-import-ai')), findsOneWidget);
    expect(find.byTooltip('ออกจากระบบ'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    final restarted = AuthController(api, store);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWithValue(restarted),
          homeProvider.overrideWithValue(
            HomeController(restarted, FakeHomeApi()),
          ),
          _emptyStore,
        ],
        child: const RelayApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('สวัสดี, Tester'), findsOneWidget);
    expect(api.loginCount, 1);
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-sign-out')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('profile-sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ออกจากระบบ').last);
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
        overrides: [authProvider.overrideWithValue(auth), _emptyStore],
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
