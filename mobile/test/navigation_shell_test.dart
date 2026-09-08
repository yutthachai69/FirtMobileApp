import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/app.dart';
import 'package:relaycontent/app/providers.dart';
import 'package:relaycontent/core/auth/auth_controller.dart';
import 'package:relaycontent/features/home/domain/content_store.dart';
import 'package:relaycontent/features/home/presentation/home_controller.dart';
import 'package:relaycontent/features/showcase/domain/showcase_product.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('เมนูหลักยังอยู่เมื่อสลับแท็บ', (tester) async {
    final auth = AuthController(FakeAuthApi(), MemoryTokenStore());
    final home = HomeController(auth, FakeHomeApi());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWithValue(auth),
          homeProvider.overrideWithValue(home),
          contentStoreProvider.overrideWithValue(ContentStore(jobs: const [])),
        ],
        child: const RelayApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email')), 'user@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'password');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-import-ai')));
    await tester.pumpAndSettle();
    expect(find.text('AI Content Inbox'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );

    await tester.tap(find.text('หน้าหลัก').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('สินค้า').last);
    await tester.pumpAndSettle();
    expect(find.text('Showcase ของฉัน'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('คอนเทนต์').last);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    home.dispose();
    auth.dispose();
  });

  testWidgets('แต่ละแท็บจำหน้าที่ค้างไว้และแตะแท็บเดิมเพื่อกลับหน้าหลัก', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = AuthController(FakeAuthApi(), MemoryTokenStore());
    final home = HomeController(auth, FakeHomeApi());
    addTearDown(home.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWithValue(auth),
          homeProvider.overrideWithValue(home),
          contentStoreProvider.overrideWithValue(ContentStore(jobs: const [])),
        ],
        child: const RelayApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email')), 'user@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'password');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('สินค้า').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Card),
        matching: find.text(ShowcaseProduct.mock.first.name),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('รายละเอียดสินค้า'), findsOneWidget);

    await tester.tap(find.text('คอนเทนต์').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('สินค้า').last);
    await tester.pumpAndSettle();
    expect(find.text('รายละเอียดสินค้า'), findsOneWidget);

    await tester.tap(find.text('สินค้า').last);
    await tester.pumpAndSettle();
    expect(find.text('Showcase ของฉัน'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
