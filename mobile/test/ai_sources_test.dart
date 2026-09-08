import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/features/create/presentation/ai_sources_page.dart';
import 'package:relaycontent/features/showcase/domain/showcase_product.dart';

void main() {
  testWidgets('AI Content Inbox แสดงแหล่งเชื่อมและเชื่อม mock source ได้', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: AiSourcesPage(product: ShowcaseProduct.mock.first),
      ),
    );

    expect(find.text('AI Content Inbox'), findsOneWidget);
    expect(find.text('Google Flow'), findsWidgets);
    expect(find.text('Serum close-up · Golden hour'), findsOneWidget);

    await tester.tap(find.text('Sora').first);
    await tester.pump();
    expect(find.text('เชื่อม Sora ในโหมดตัวอย่างแล้ว'), findsOneWidget);
  });
}
