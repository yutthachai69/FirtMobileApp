import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/features/create/presentation/publish_review_page.dart';
import 'package:relaycontent/features/showcase/domain/showcase_product.dart';

void main() {
  testWidgets('opens a full video preview and toggles playback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: PublishReviewPage(
          product: ShowcaseProduct.mock.first,
          mediaName: 'review-serum.mov',
          durationSec: 42,
        ),
      ),
    );

    expect(find.byKey(const Key('video-preview-card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-video-preview')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('preview-play-pause')), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
    await tester.tap(find.byKey(const Key('preview-play-pause')));
    await tester.pump();
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('ปิดตัวอย่าง'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('preview-play-pause')), findsNothing);
  });

  testWidgets('ตรวจตะกร้าและเลือกโพสต์ทันทีจนรับงานได้', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: PublishReviewPage(product: ShowcaseProduct.mock.first),
      ),
    );

    expect(find.text('ตรวจสอบก่อนเผยแพร่'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('โพสต์ทันที'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('โพสต์ทันที'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('สรุปก่อนยืนยัน'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('เปิดตะกร้าสินค้าแล้ว'), findsOneWidget);
    await tester.tap(find.byKey(const Key('publish-submit')));
    await tester.pump();
    expect(find.text('กำลังส่งเข้าคิว…'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('รับงานเผยแพร่แล้ว'), findsOneWidget);
    expect(find.text('ติดตามสถานะคอนเทนต์'), findsOneWidget);
  });

  testWidgets('รับรายละเอียดคลิปและแคปชันจากทางอัปโหลด', (tester) async {
    final product = ShowcaseProduct.mock.first;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: PublishReviewPage(
          product: product,
          initialCaption: 'แคปชันจากมือถือ #พร้อมขาย',
          mediaName: 'review-serum.mov',
          durationSec: 42,
          sourceLabel: 'อัปโหลดจากมือถือ',
        ),
      ),
    );

    expect(find.text('review-serum.mov'), findsOneWidget);
    expect(find.text('อัปโหลดจากมือถือ · 00:42 · 1080P'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('publish-caption')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final field = tester.widget<TextField>(
      find.byKey(const Key('publish-caption')),
    );
    expect(field.controller!.text, 'แคปชันจากมือถือ #พร้อมขาย');
  });

  testWidgets('ปิดตะกร้าต้องยืนยันและเปิด date time picker ได้', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: PublishReviewPage(product: ShowcaseProduct.mock.first),
      ),
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('เผยแพร่โดยไม่ปักตะกร้า?'), findsOneWidget);
    await tester.tap(find.text('คงตะกร้าไว้'));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เผยแพร่แบบไม่มีตะกร้า'));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.scrollUntilVisible(
      find.byKey(const Key('pick-publish-date')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-publish-date')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick-publish-time')));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
  });
}
