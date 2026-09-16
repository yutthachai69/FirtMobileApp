import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/core/auth/auth_controller.dart';
import 'package:relaycontent/core/config/app_config.dart';
import 'package:relaycontent/features/showcase/data/products_api.dart';
import 'package:relaycontent/features/showcase/domain/showcase_product.dart';
import 'package:relaycontent/features/showcase/presentation/products_controller.dart';
import 'package:relaycontent/features/showcase/presentation/showcase_page.dart';

import 'support/fakes.dart';

class _FakeProductsApi implements ProductsApi {
  _FakeProductsApi({this.items = const []});

  final List<ShowcaseProduct> items;

  @override
  Future<List<ShowcaseProduct>> list(String access) async {
    return items;
  }

  @override
  Future<ShowcaseProduct> get(String access, String id) async =>
      items.firstWhere((item) => item.id == id);
}

void main() {
  test(
    'ProductsController keeps server catalog as its only live snapshot',
    () async {
      final auth = AuthController(FakeAuthApi(), MemoryTokenStore());
      await auth.authenticate('user@example.com', 'password');
      final product = ShowcaseProduct.fromJson({
        'id': 'server-product',
        'name': 'Server product',
        'price_baht': 450,
        'commission_percent': 12,
        'stock': 8,
        'shop_name': 'Server shop',
        'selling_points': ['verified'],
      });
      final controller = ProductsController(
        auth,
        _FakeProductsApi(items: [product]),
      );
      addTearDown(() {
        controller.dispose();
        auth.dispose();
      });

      await controller.load();

      expect(controller.loaded, isTrue);
      expect(controller.error, isNull);
      expect(controller.items.single.id, 'server-product');
      expect(controller.byId('server-product'), same(product));
      expect(controller.byId('mock-1'), isNull);
    },
  );

  testWidgets('live Showcase never falls back to mock products', (
    tester,
  ) async {
    if (!AppConfig.isLive) return;

    final auth = AuthController(FakeAuthApi(), MemoryTokenStore());
    await auth.authenticate('user@example.com', 'password');
    final controller = ProductsController(auth, _FakeProductsApi());
    addTearDown(() {
      controller.dispose();
      auth.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: ShowcasePage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีสินค้าใน Showcase'), findsOneWidget);
    for (final product in ShowcaseProduct.mock) {
      expect(find.text(product.name), findsNothing);
    }
  });
}
