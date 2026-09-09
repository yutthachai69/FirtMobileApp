import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/features/home/domain/content_store.dart';
import 'package:relaycontent/features/home/domain/home_data.dart';
import 'package:relaycontent/features/home/presentation/review_queue_page.dart';

Widget _host(ContentStore store) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => ReviewQueuePage(store: store)),
    ],
  );
  return MaterialApp.router(
    theme: appTheme(Brightness.dark),
    routerConfig: router,
  );
}

void main() {
  testWidgets('อนุมัติงานแรก คิวลดลงและงานกลายเป็น scheduled', (tester) async {
    tester.view.physicalSize = const Size(430, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ContentStore();
    final first = store.reviewQueue.first;
    expect(store.reviewQueue.length, 3);

    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    expect(find.text('เหลือ 3 งานรอตรวจ'), findsOneWidget);

    await tester.tap(find.byKey(const Key('review-approve')));
    await tester.pumpAndSettle();

    expect(store.reviewQueue.length, 2);
    expect(store.byId(first.id)!.status, JobStatus.scheduled);
    expect(find.text('เหลือ 2 งานรอตรวจ'), findsOneWidget);
  });

  testWidgets('ส่งกลับแก้ทำให้เป็น draft และ undo คืนสถานะ', (tester) async {
    tester.view.physicalSize = const Size(430, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ContentStore();
    final first = store.reviewQueue.first;

    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('review-send-back')));
    await tester.pumpAndSettle();
    expect(store.byId(first.id)!.status, JobStatus.draft);

    await tester.tap(find.text('เลิกทำ'));
    await tester.pumpAndSettle();
    expect(store.byId(first.id)!.status, JobStatus.awaitingReview);
  });

  testWidgets('ปัดขวาเพื่ออนุมัติ', (tester) async {
    tester.view.physicalSize = const Size(430, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ContentStore();
    final first = store.reviewQueue.first;

    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Dismissible), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(store.byId(first.id)!.status, JobStatus.scheduled);
  });

  testWidgets('คิวหมดแสดง "ตรวจครบแล้ว"', (tester) async {
    final store = ContentStore(jobs: const []);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();
    expect(find.text('ตรวจครบแล้ว'), findsOneWidget);
  });
}
