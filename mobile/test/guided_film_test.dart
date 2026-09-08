import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/features/create/presentation/guided_film_page.dart';
import 'package:relaycontent/features/showcase/domain/showcase_product.dart';

void main() {
  testWidgets('guided filming บันทึกและเลือกเทคเพื่อไปช็อตถัดไปได้', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: GuidedFilmPage(product: ShowcaseProduct.mock.first),
      ),
    );

    expect(find.text('ช็อต 1 จาก 3'), findsOneWidget);
    final next = tester.widget<FilledButton>(
      find.byKey(const Key('guided-next')),
    );
    expect(next.onPressed, isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('guided-record')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await tester.pump();
    await tester.tap(find.byKey(const Key('guided-record')));
    await tester.pump();
    expect(find.text('เทค 1'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('guided-next')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('guided-next')));
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 700));
    await tester.pump();
    expect(find.text('ช็อต 2 จาก 3'), findsOneWidget);
  });
}
