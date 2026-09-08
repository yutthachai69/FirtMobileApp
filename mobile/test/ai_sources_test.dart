import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/features/create/domain/ai_source.dart';
import 'package:relaycontent/features/create/presentation/ai_sources_controller.dart';
import 'package:relaycontent/features/create/presentation/ai_sources_page.dart';
import 'package:relaycontent/features/showcase/domain/showcase_product.dart';

void main() {
  group('AiSourcesController', () {
    test('เชื่อมแหล่งที่มีข้อจำกัดแล้วขึ้นสถานะ needsAttention + งานใหม่เข้า Inbox', () async {
      final c = AiSourcesController(autoAdvance: false);
      final before = c.inbox.length;

      await c.connect('sora');

      expect(c.sourceById('sora').status, SourceStatus.needsAttention);
      expect(c.inbox.length, before + 1);
      expect(c.inbox.first.sourceId, 'sora');
      c.dispose();
    });

    test('sync ผลักงานที่กำลังนำเข้าจนพร้อมใช้', () async {
      final c = AiSourcesController(autoAdvance: false);
      expect(c.importingItems, isNotEmpty);

      await c.sync();
      await c.sync();

      expect(c.importingItems, isEmpty);
      expect(c.readyItems.any((i) => i.id == 'inbox-importing-1'), isTrue);
      c.dispose();
    });

    test('retry เปลี่ยนงานที่ล้มเหลวกลับไป importing แล้วเดินต่อได้', () {
      final c = AiSourcesController(autoAdvance: false);
      expect(c.failedItems, isNotEmpty);
      final id = c.failedItems.first.id;

      c.retry(id);
      expect(c.failedItems, isEmpty);
      expect(c.importingItems.any((i) => i.id == id), isTrue);

      c.debugAdvance(1);
      expect(c.readyItems.any((i) => i.id == id), isTrue);
      c.dispose();
    });

    test('disconnect ไม่ลบงานที่นำเข้ามาแล้ว', () {
      final c = AiSourcesController(autoAdvance: false);
      final count = c.inbox.length;

      c.disconnect('google-flow');
      expect(c.sourceById('google-flow').status, SourceStatus.disconnected);
      expect(c.inbox.length, count);
      c.dispose();
    });
  });

  testWidgets('หน้า AI Content Inbox แสดงงาน ready / importing / failed และคำเตือน capability', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = AiSourcesController(autoAdvance: false);
    addTearDown(c.dispose);
    await c.connect('sora'); // ให้เกิดคำเตือน capability

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: AiSourcesPage(
          product: ShowcaseProduct.mock.first,
          controller: c,
        ),
      ),
    );

    expect(find.text('AI Content Inbox'), findsOneWidget);
    expect(find.text('Serum close-up · Golden hour'), findsOneWidget);
    expect(find.textContaining('ไฟล์ต้นทางถูกลบ'), findsOneWidget);
    expect(find.textContaining('กำลังรับไฟล์จาก Google Flow'), findsOneWidget);
    expect(find.textContaining('ต้องครอปเป็นแนวตั้ง'), findsOneWidget);

    await tester.tap(find.text('ลองใหม่'));
    await tester.pump();
    expect(find.text('ลองใหม่'), findsNothing);
    expect(c.importingItems.any((i) => i.id == 'inbox-failed-1'), isTrue);
  });
}
