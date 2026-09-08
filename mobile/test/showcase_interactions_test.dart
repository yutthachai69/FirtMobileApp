import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/features/showcase/presentation/showcase_page.dart';

void main() {
  testWidgets('สินค้าใช้ภาพจริงและกรองรายการบันทึกได้', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: appTheme(Brightness.dark), home: const ShowcasePage()),
    );
    await tester.pump();

    expect(find.byType(Image), findsWidgets);
    await tester.tap(find.byTooltip('บันทึกสินค้า').first);
    await tester.pump();
    await tester.tap(find.text('บันทึกไว้'));
    await tester.pump();

    expect(find.byTooltip('เลิกบันทึก'), findsOneWidget);
    expect(
      find.text('เซรั่มวิตซีหน้าใส ไฮยาลูรอนเข้มข้น 30ml'),
      findsOneWidget,
    );
    expect(find.text('ไมโครโฟนไร้สาย สำหรับ Live และถ่ายคลิป'), findsNothing);
  });
}
