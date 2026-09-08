import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/features/create/presentation/ai_create_page.dart';
import 'package:relaycontent/features/showcase/domain/showcase_product.dart';

void main() {
  testWidgets('AI creation flow ไปจาก brief จนอนุมัติฉบับร่างได้', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: AiCreatePage(product: ShowcaseProduct.mock.first),
      ),
    );

    expect(find.text('กำหนดแนวทาง'), findsOneWidget);
    await tester.tap(find.text('แกะกล่องทดลองใช้'));
    await tester.tap(find.text('15 วินาที'));
    await tester.tap(find.byKey(const Key('ai-next')));
    await tester.pumpAndSettle();

    expect(find.text('สคริปต์และเสียง'), findsOneWidget);
    expect(find.byKey(const Key('ai-script')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('ai-script')),
      'ทดสอบแก้ Hook และตรวจสอบข้อมูลสินค้าก่อนสร้างคลิป',
    );
    await tester.tap(find.text('นัท — เป็นกันเอง'));
    await tester.tap(find.byKey(const Key('ai-next')));
    await tester.pumpAndSettle();

    expect(find.text('ตรวจสอบคลิป'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('variant-2')));
    await tester.tap(find.byKey(const Key('variant-2')));
    await tester.tap(find.byKey(const Key('ai-next')));
    await tester.pumpAndSettle();

    expect(find.text('อนุมัติคลิปแล้ว'), findsOneWidget);
    expect(find.text('ตรวจตะกร้าและเผยแพร่'), findsOneWidget);
  });
}
