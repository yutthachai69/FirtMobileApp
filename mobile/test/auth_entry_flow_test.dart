import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/app.dart';
import 'package:relaycontent/app/providers.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/core/auth/auth_controller.dart';
import 'package:relaycontent/features/auth/presentation/auth_page.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('ลืมรหัสผ่านตรวจอีเมลและแสดง success state', (tester) async {
    final auth = AuthController(FakeAuthApi(), MemoryTokenStore());
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: AuthPage(auth: auth),
      ),
    );

    await tester.tap(find.byKey(const Key('forgot-password')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reset-email')), 'ผิด');
    await tester.tap(find.byKey(const Key('send-reset')));
    await tester.pump();
    expect(find.text('กรุณากรอกอีเมลให้ถูกต้อง'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('reset-email')),
      'creator@example.com',
    );
    await tester.tap(find.byKey(const Key('send-reset')));
    await tester.pumpAndSettle();
    expect(find.text('ส่งลิงก์เรียบร้อย'), findsOneWidget);
    auth.dispose();
  });

  testWidgets('สมัครสมาชิกแล้วเข้า onboarding สามขั้น', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeAuthApi();
    final auth = AuthController(api, MemoryTokenStore());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWithValue(auth)],
        child: const RelayApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยังไม่มีบัญชี? สมัครสมาชิก'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('display-name')), 'Creator');
    await tester.enterText(
      find.byKey(const Key('email')),
      'creator@example.com',
    );
    await tester.enterText(find.byKey(const Key('password')), 'password8');
    await tester.ensureVisible(find.byKey(const Key('submit')));
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();

    expect(api.registerCount, 1);
    expect(find.text('วันนี้คุณอยากทำอะไร?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('รับคอนเทนต์จากที่ไหน?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('เลือกสินค้าชิ้นแรก'), findsOneWidget);
    auth.dispose();
  });
}
