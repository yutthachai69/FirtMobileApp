import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/features/home/domain/content_store.dart';
import 'package:relaycontent/features/home/domain/home_data.dart';
import 'package:relaycontent/features/showcase/domain/showcase_product.dart';
import 'package:relaycontent/features/showcase/presentation/product_detail_page.dart';

Widget _host(Widget child) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => child),
      GoRoute(
        path: '/content/:id',
        builder: (_, state) =>
            Scaffold(body: Text('job ${state.pathParameters['id']}')),
      ),
    ],
  );
  return MaterialApp.router(
    theme: appTheme(Brightness.dark),
    routerConfig: router,
  );
}

void main() {
  final serum = ShowcaseProduct.mock.firstWhere((p) => p.id == 'mock-1');

  testWidgets('หน้าสินค้าแสดงคลิปที่เคยทำ รายได้โดยประมาณ และกดเข้าไปดูได้', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ContentStore();
    await tester.pumpWidget(
      _host(ProductDetailPage(product: serum, store: store)),
    );
    await tester.pumpAndSettle();

    final linked = store.byProduct('mock-1');
    expect(linked, isNotEmpty);
    expect(find.text('คลิปของสินค้านี้'), findsOneWidget);
    expect(find.text('${linked.length} คลิป'), findsOneWidget);
    expect(find.textContaining('รายได้รวมโดยประมาณ ฿'), findsOneWidget);

    final published = linked.firstWhere(
      (j) => j.status == JobStatus.published,
    );
    await tester.tap(find.text(published.title).first);
    await tester.pumpAndSettle();
    expect(find.text('job ${published.id}'), findsOneWidget);
  });

  testWidgets('สินค้าไม่มีคลิปแสดงข้อความชวนเริ่มชิ้นแรก', (tester) async {
    tester.view.physicalSize = const Size(430, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        ProductDetailPage(product: serum, store: ContentStore(jobs: const [])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0 คลิป'), findsOneWidget);
    expect(find.textContaining('ยังไม่เคยทำคลิปให้สินค้านี้'), findsOneWidget);
  });
}
