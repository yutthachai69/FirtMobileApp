import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/core/auth/auth_controller.dart';
import 'package:relaycontent/features/home/presentation/notifications_page.dart';
import 'package:relaycontent/features/profile/presentation/profile_page.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('การแจ้งเตือนกรองสิ่งที่ต้องทำและอ่านทั้งหมดได้', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: const NotificationsPage(),
      ),
    );

    expect(find.text('การแจ้งเตือน'), findsOneWidget);
    await tester.tap(find.text('ต้องทำ'));
    await tester.pump();
    expect(find.text('ต้องแก้ก่อนเผยแพร่'), findsOneWidget);
    expect(find.text('รับคอนเทนต์จาก AI แล้ว'), findsNothing);
    await tester.tap(find.text('อ่านทั้งหมด'));
    await tester.pump();
  });

  testWidgets('โปรไฟล์แสดงบัญชีและเปิดตั้งค่าการแจ้งเตือนได้', (tester) async {
    final auth = AuthController(FakeAuthApi(), MemoryTokenStore());
    await auth.authenticate('user@example.com', 'password');
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: ProfilePage(auth: auth),
      ),
    );

    expect(find.text('Tester'), findsOneWidget);
    expect(find.text('TikTok Shop Creator'), findsOneWidget);
    await tester.tap(find.text('การแจ้งเตือน'));
    await tester.pumpAndSettle();
    expect(find.text('แจ้งเมื่องานเปลี่ยนสถานะ'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });

  testWidgets('แก้โปรไฟล์ timezone และส่งค่าหน้าตาแอปได้', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthController(FakeAuthApi(), MemoryTokenStore());
    await auth.authenticate('user@example.com', 'password');
    ThemeMode? selectedTheme;
    bool? selectedMotion;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: ProfilePage(
          auth: auth,
          onThemeModeChanged: (value) => selectedTheme = value,
          onReducedMotionChanged: (value) => selectedMotion = value,
        ),
      ),
    );

    await tester.tap(find.text('แก้ไขโปรไฟล์'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-name-input')),
      'New Creator',
    );
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(find.text('New Creator'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('หน้าตาแอป'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('หน้าตาแอป'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('สว่าง'));
    await tester.pump();
    expect(selectedTheme, ThemeMode.light);
    await tester.tap(find.text('ลดการเคลื่อนไหว'));
    await tester.pump();
    expect(selectedMotion, isTrue);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('เขตเวลา'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asia/Tokyo'));
    await tester.pumpAndSettle();
    expect(auth.account?.timezone, 'Asia/Tokyo');
    auth.dispose();
  });
}
