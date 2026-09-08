import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/features/home/presentation/content_detail_page.dart';

void main() {
  testWidgets('งานที่ล้มเหลวแสดงสาเหตุและส่งกลับเข้าคิวได้', (tester) async {
    final failed = demoContentJobs.firstWhere((job) => job.id == 'demo-failed');
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: ContentDetailPage(job: failed),
      ),
    );

    expect(find.text('ต้องแก้ก่อนส่งใหม่'), findsOneWidget);
    expect(find.text(failed.errorMessage), findsOneWidget);
    await tester.tap(find.byKey(const Key('retry-job')));
    await tester.pumpAndSettle();

    expect(find.text('เข้าคิวแล้ว'), findsOneWidget);
    expect(
      find.text('เพิ่มงานกลับเข้าคิวแล้ว คุณออกจากหน้านี้ได้'),
      findsOneWidget,
    );
  });
}
