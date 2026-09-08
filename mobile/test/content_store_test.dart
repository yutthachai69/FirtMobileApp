import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/core/auth/auth_controller.dart';
import 'package:relaycontent/features/create/presentation/publish_review_page.dart';
import 'package:relaycontent/features/home/domain/content_store.dart';
import 'package:relaycontent/features/home/domain/home_data.dart';
import 'package:relaycontent/features/home/presentation/content_library_page.dart';
import 'package:relaycontent/features/home/presentation/home_controller.dart';
import 'package:relaycontent/features/showcase/domain/showcase_product.dart';

import 'support/fakes.dart';

void main() {
  group('ContentStore', () {
    test('seed คำนวณวันเวลาสัมพันธ์กับตอนนี้ ไม่ตรึงไว้ที่วันใดวันหนึ่ง', () {
      final jobs = ContentStore.seedJobs();
      final scheduled = jobs.firstWhere((j) => j.id == 'demo-scheduled');
      final tomorrow = DateTime.now().add(const Duration(days: 1));

      expect(scheduled.scheduledAt.year, tomorrow.year);
      expect(scheduled.scheduledAt.month, tomorrow.month);
      expect(scheduled.scheduledAt.day, tomorrow.day);
    });

    test('add แทรกงานใหม่ไว้บนสุดและแจ้ง listener', () {
      final store = ContentStore();
      var notified = 0;
      store.addListener(() => notified++);
      final before = store.jobs.length;

      store.add(
        PublishJob(
          id: 'job-x',
          contentId: 'c-x',
          platform: 'tiktok',
          status: JobStatus.scheduled,
          scheduledAt: DateTime.now(),
          caption: 'งานใหม่',
        ),
      );

      expect(store.jobs.length, before + 1);
      expect(store.jobs.first.id, 'job-x');
      expect(notified, 1);
    });

    test('reschedule / cancel / restore / retry เปลี่ยนสถานะงานเดิม', () {
      final store = ContentStore();
      final at = DateTime(2027, 1, 2, 8, 30);

      store.reschedule('demo-scheduled', at);
      expect(store.byId('demo-scheduled')!.scheduledAt, at);
      expect(store.byId('demo-scheduled')!.status, JobStatus.scheduled);

      store.cancel('demo-scheduled');
      expect(store.byId('demo-scheduled')!.status, JobStatus.cancelled);
      store.restore('demo-scheduled');
      expect(store.byId('demo-scheduled')!.status, JobStatus.scheduled);

      store.retry('demo-failed');
      expect(store.byId('demo-failed')!.status, JobStatus.queued);
      expect(store.byId('demo-failed')!.errorMessage, isEmpty);
    });

    test('byProduct คืนเฉพาะงานของสินค้านั้น เรียงใหม่สุดก่อน', () {
      final store = ContentStore();
      final forSerum = store.byProduct('mock-1');

      expect(forSerum, isNotEmpty);
      expect(forSerum.every((j) => j.productId == 'mock-1'), isTrue);
      for (var i = 1; i < forSerum.length; i++) {
        expect(
          forSerum[i - 1].scheduledAt.isAfter(forSerum[i].scheduledAt) ||
              forSerum[i - 1].scheduledAt == forSerum[i].scheduledAt,
          isTrue,
        );
      }
    });
  });

  testWidgets('กดเผยแพร่แล้วงานไปโผล่ในแท็บคอนเทนต์จริง', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ContentStore(jobs: []);
    final home = HomeController(
      AuthController(FakeAuthApi(), MemoryTokenStore()),
      FakeHomeApi(),
    );
    addTearDown(home.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: PublishReviewPage(
          product: ShowcaseProduct.mock.first,
          store: store,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('publish-submit')));
    await tester.pumpAndSettle();

    expect(store.jobs, hasLength(1));
    expect(store.jobs.first.productId, ShowcaseProduct.mock.first.id);
    expect(store.jobs.first.status, JobStatus.scheduled);

    // แท็บคอนเทนต์อ่านจาก store ตัวเดียวกันแล้วเห็นงานนั้น
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: ContentLibraryPage(controller: home, store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(store.jobs.first.title), findsWidgets);
  });
}
