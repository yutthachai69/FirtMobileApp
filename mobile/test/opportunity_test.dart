import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/features/home/domain/content_store.dart';
import 'package:relaycontent/features/showcase/domain/opportunity.dart';
import 'package:relaycontent/features/showcase/domain/showcase_product.dart';
import 'package:relaycontent/features/showcase/presentation/showcase_page.dart';

void main() {
  group('Opportunity.scan', () {
    test('สินค้าที่เคยทำเงินได้ ขึ้นเป็น proven และมาก่อนใบอื่น', () {
      final list = Opportunity.scan(
        products: ShowcaseProduct.mock,
        store: ContentStore(),
      );
      expect(list, isNotEmpty);
      expect(list.first.kind, OpportunityKind.proven);
      expect(list.first.product.id, 'mock-1');
      expect(list.first.detail, contains('฿'));
    });

    test('สต็อกเหลือน้อยขึ้นเป็น lowStock', () {
      final list = Opportunity.scan(
        products: ShowcaseProduct.mock,
        store: ContentStore(jobs: const []),
      );
      final mic = list.firstWhere((o) => o.product.id == 'mock-2');
      expect(mic.kind, OpportunityKind.lowStock);
      expect(mic.detail, contains('เหลือ'));
    });

    test('สินค้าหมดสต็อกไม่ขึ้นใน radar', () {
      final list = Opportunity.scan(
        products: ShowcaseProduct.mock,
        store: ContentStore(jobs: const []),
      );
      expect(list.any((o) => o.product.id == 'mock-3'), isFalse);
    });

    test('ไม่มีสินค้าเลย = ไม่มีคำแนะนำ', () {
      expect(
        Opportunity.scan(products: const [], store: ContentStore()),
        isEmpty,
      );
    });
  });

  testWidgets('หน้า Showcase แสดงแถบ "โอกาสวันนี้" และกดสร้างได้', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var createdFor = '';
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ShowcasePage(store: ContentStore()),
        ),
        GoRoute(
          path: '/create',
          builder: (_, state) {
            createdFor = (state.extra as ShowcaseProduct?)?.id ?? '';
            return const Scaffold(body: Text('create'));
          },
        ),
        GoRoute(
          path: '/showcase/:id',
          builder: (_, _) => const Scaffold(body: Text('detail')),
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

    expect(find.text('โอกาสวันนี้'), findsOneWidget);
    expect(find.text('เคยทำเงินให้คุณ'), findsOneWidget);

    await tester.tap(find.text('สร้างคอนเทนต์').first);
    await tester.pumpAndSettle();
    expect(find.text('create'), findsOneWidget);
    expect(createdFor, isNotEmpty);
  });

  test('live scan does not infer proven revenue from mock orders', () {
    final list = Opportunity.scan(
      products: ShowcaseProduct.mock,
      store: ContentStore(),
      includeOrderMetrics: false,
    );
    expect(list.where((o) => o.kind == OpportunityKind.proven), isEmpty);
  });
}
