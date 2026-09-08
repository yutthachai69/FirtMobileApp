import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/features/create/domain/remix.dart';
import 'package:relaycontent/features/create/presentation/publish_review_page.dart';
import 'package:relaycontent/features/home/domain/content_store.dart';
import 'package:relaycontent/features/home/presentation/content_detail_page.dart';

void main() {
  group('RemixPreset.of', () {
    final source = ContentStore().byId('demo-published')!;

    test('เปลี่ยน Hook ตัดบรรทัดแรกออกจาก seed caption', () {
      final multi = source.copyWith(caption: 'บรรทัดแรก\nบรรทัดสอง');
      final p = RemixPreset.of(RemixKind.newHook, multi);
      expect(p.seedCaption, 'บรรทัดสอง');
      expect(p.note, contains('บรรทัดแรก'));
    });

    test('เวอร์ชัน 15 วินาที ตั้ง durationSec = 15', () {
      expect(RemixPreset.of(RemixKind.short15, source).durationSec, 15);
    });

    test('เขียนคำบรรยายใหม่ = seed ว่าง', () {
      expect(RemixPreset.of(RemixKind.newCaption, source).seedCaption, isEmpty);
    });

    test('เปลี่ยนสินค้าต้องให้เลือกสินค้าก่อน', () {
      expect(
        RemixPreset.of(RemixKind.newProduct, source).needsProductPick,
        isTrue,
      );
    });
  });

  testWidgets('รีมิกซ์จากหน้าคอนเทนต์ สร้างงานใหม่ที่อ้างถึงงานต้นทาง', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ContentStore();
    final source = store.byId('demo-published')!;
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (_, _) => ContentDetailPage(job: source, store: store),
        ),
        GoRoute(
          path: '/create/publish',
          builder: (_, state) {
            final a = state.extra as PublishReviewArgs;
            return PublishReviewPage(
              product: a.product,
              initialCaption: a.caption,
              durationSec: a.durationSec,
              sourceLabel: a.sourceLabel,
              store: store,
              remixOfId: a.remixOfId,
              remixNote: a.remixNote,
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: appTheme(Brightness.dark),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('ตัวเลือกเพิ่มเติม'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remix-job')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทำเวอร์ชัน 15 วินาที'));
    await tester.pumpAndSettle();

    expect(find.textContaining('รีมิกซ์: ตัดให้กระชับ'), findsOneWidget);

    final before = store.jobs.length;
    await tester.tap(find.byKey(const Key('publish-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(store.jobs.length, before + 1);
    expect(store.jobs.first.remixOfId, 'demo-published');
    expect(store.jobs.first.productId, source.productId);
  });
}
