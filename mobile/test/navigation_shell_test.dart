import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/app.dart';
import 'package:relaycontent/app/providers.dart';
import 'package:relaycontent/core/auth/auth_controller.dart';
import 'package:relaycontent/features/home/presentation/home_controller.dart';

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
}
