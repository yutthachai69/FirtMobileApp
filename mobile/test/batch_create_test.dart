import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/features/create/presentation/batch_create_page.dart';
import 'package:relaycontent/features/home/domain/content_store.dart';
import 'package:relaycontent/features/home/domain/home_data.dart';
import 'package:relaycontent/features/showcase/domain/showcase_product.dart';
import 'package:relaycontent/features/showcase/presentation/showcase_page.dart';

GoRouter _router(ContentStore store) => GoRouter(
  initialLocation: '/showcase',
  routes: [
    GoRoute(
      path: '/showcase',
      builder: (_, _) => ShowcasePage(store: store),
    ),
    GoRoute(
      path: '/create/batch',
      builder: (_, state) => BatchCreatePage(
        products: state.extra! as List<ShowcaseProduct>,
        store: store,
      ),
    ),
    GoRoute(
      path: '/content',
      builder: (_, _) => const Scaffold(body: Text('content tab')),
    ),
    GoRoute(
      path: '/showcase/:id',
      builder: (_, _) => const Scaffold(body: Text('detail')),
    ),
  ],
);

void main() {
  testWidgets('เลือกหลายชิ้น → สร้างเป็นชุด → ยืนยัน แล้วงานเข้า store ตามวันที่กระจาย', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ContentStore(jobs: const []);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: appTheme(Brightness.dark),
        routerConfig: _router(store),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('toggle-batch-select')));
    await tester.pumpAndSettle();

    // เลือกสองสินค้าแรกที่แสดง
    final checkboxes = find.byType(Checkbox);
    expect(checkboxes, findsWidgets);
    await tester.tap(checkboxes.at(0));
    await tester.pump();
    await tester.tap(checkboxes.at(1));
    await tester.pump();

    await tester.tap(find.byKey(const Key('start-batch')));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 คลิป · กระจาย'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-batch')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('content tab'), findsOneWidget);
    expect(store.jobs, hasLength(2));
    expect(store.jobs.every((j) => j.status == JobStatus.scheduled), isTrue);
    expect(store.jobs.every((j) => j.sourceLabel == 'สร้างเป็นชุด'), isTrue);
    // คนละวันกัน
    final days = store.jobs
        .map((j) => '${j.scheduledAt.month}-${j.scheduledAt.day}')
        .toSet();
    expect(days.length, 2);
  });

  testWidgets('เอาแถวออกจากชุดได้ และหมดแถวแล้วปุ่มยืนยันหาย', (tester) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ContentStore(jobs: const []);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: BatchCreatePage(
          products: ShowcaseProduct.mock.take(2).toList(),
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('confirm-batch')), findsOneWidget);
    await tester.tap(find.byTooltip('เอาออกจากชุด').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 คลิป'), findsOneWidget);

    await tester.tap(find.byTooltip('เอาออกจากชุด').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm-batch')), findsNothing);
    expect(find.text('ไม่มีสินค้าในชุดแล้ว'), findsOneWidget);
  });
}
