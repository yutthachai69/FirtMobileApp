import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/features/create/domain/readiness.dart';
import 'package:relaycontent/features/create/presentation/publish_review_page.dart';
import 'package:relaycontent/features/showcase/domain/showcase_product.dart';

void main() {
  final product = ShowcaseProduct.mock.first;

  ReadinessReport run({
    required String caption,
    Set<String> tags = const {'#รีวิว'},
    int durationSec = 30,
    bool basket = true,
  }) => ReadinessReport.evaluate(
    caption: caption,
    tags: tags,
    durationSec: durationSec,
    basketEnabled: basket,
    product: product,
  );

  group('ReadinessReport.evaluate', () {
    test('คำบรรยายว่างได้คะแนนต่ำและอยู่ระดับ poor', () {
      final r = run(caption: '', tags: const {}, basket: false);
      expect(r.percent, lessThan(40));
      expect(r.level, ReadinessLevel.poor);
      expect(r.weakest.first.isFull, isFalse);
    });

    test('caption ครบองค์ประกอบได้ระดับ good', () {
      final r = run(
        caption:
            '3 เหตุผลที่ควรลอง ${product.name} ก่อนของหมด\n'
            '${product.sellingPoints.first} ผิวนุ่มขึ้นจริง '
            'กดที่ตะกร้าเพื่อรับส่วนลดวันนี้ #รีวิวของดี #ป้ายยา',
        durationSec: 30,
      );
      expect(r.level, ReadinessLevel.good);
      expect(r.percent, greaterThanOrEqualTo(80));
    });

    test('คำกล่าวอ้างเสี่ยงตัดคะแนนหัวข้อ claims', () {
      final r = run(
        caption: 'ครีมนี้ รักษา สิวหายขาด การันตี เห็นผลทันที กดตะกร้าเลย',
      );
      final claims = r.checks.firstWhere((c) => c.id == 'claims');
      expect(claims.score, 0);
      expect(claims.isFull, isFalse);
    });

    test('ปิดตะกร้าแล้วหัวข้อ CTA ชี้ให้ไปเปิดตะกร้า', () {
      final r = run(caption: 'ลองดูสินค้าตัวนี้', basket: false);
      final cta = r.checks.firstWhere((c) => c.id == 'cta');
      expect(cta.target, ReadinessTarget.basket);
      expect(cta.isFull, isFalse);
    });

    test('คลิปสั้นหรือยาวเกินไปได้คะแนนความยาวน้อย', () {
      expect(run(caption: 'x', durationSec: 4).checks
          .firstWhere((c) => c.id == 'length').score, lessThan(5));
      expect(run(caption: 'x', durationSec: 30).checks
          .firstWhere((c) => c.id == 'length').score, 15);
    });
  });

  testWidgets('หน้า publish แสดงการ์ดคะแนนและกดหัวข้อเพื่อเลื่อนไปแคปชัน', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: PublishReviewPage(product: product, durationSec: 4),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ความพร้อมก่อนเผยแพร่'), findsOneWidget);
    expect(find.text('Hook เปิดเรื่อง'), findsOneWidget);
    expect(find.text('ความยาวคลิป'), findsOneWidget);

    // หัวข้อที่ยังไม่เต็มมีปุ่มกดไปแก้ แตะแล้วไม่พัง
    final chevrons = find.byIcon(Icons.chevron_right_rounded);
    expect(chevrons, findsWidgets);
    await tester.tap(chevrons.first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('publish-caption')), findsOneWidget);
  });

  testWidgets('คะแนนต่ำมากต้องยืนยันก่อนเผยแพร่ แต่ยังเผยแพร่ได้', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: PublishReviewPage(product: product, durationSec: 4),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('publish-caption')), 'สั้นไป');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('publish-submit')));
    await tester.pumpAndSettle();
    expect(find.text('คะแนนความพร้อมยังต่ำ'), findsOneWidget);

    await tester.tap(find.text('เผยแพร่เลย'));
    await tester.pump(); // ปิด dialog
    await tester.pump(const Duration(milliseconds: 800)); // ผ่าน delay ของ submit
    await tester.pumpAndSettle();
    expect(find.text('คะแนนความพร้อมยังต่ำ'), findsNothing);
    expect(find.text('ติดตามสถานะคอนเทนต์'), findsOneWidget);
  });
}
