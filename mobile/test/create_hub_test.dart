import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/features/create/presentation/create_hub_page.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: const CreateHubPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('เลือก AI Inbox เป็นเส้นทางแนะนำเริ่มต้น', (tester) async {
    await open(tester);

    expect(find.text('เปิด AI Content Inbox'), findsOneWidget);
    expect(find.text('นำเข้าเร็ว'), findsOneWidget);
    expect(find.text('LAB'), findsOneWidget);
  });

  testWidgets('แตะตัวเลือกแล้ว CTA และรายละเอียดเปลี่ยนตามเส้นทาง', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text('นำเข้าคลิปจากมือถือ'));
    await tester.pumpAndSettle();

    expect(find.text('เลือกคลิปจากเครื่อง'), findsOneWidget);
    expect(find.text('Trim'), findsOneWidget);

    await tester.tap(find.text('ถ่ายรีวิวแบบมีไกด์'));
    await tester.pumpAndSettle();

    expect(find.text('เลือกสินค้าก่อนถ่าย'), findsOneWidget);
    expect(find.text('Shot list'), findsOneWidget);
  });
}
