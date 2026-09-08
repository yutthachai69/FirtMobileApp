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

  testWidgets('งานที่ตั้งเวลาเปลี่ยนวันเวลาและยกเลิกแล้วนำกลับได้', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scheduled = demoContentJobs.firstWhere(
      (job) => job.id == 'demo-scheduled',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: ContentDetailPage(job: scheduled),
      ),
    );

    await tester.tap(find.byKey(const Key('reschedule-job')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(DatePickerDialog)))
        .pop(DateTime(2026, 9, 12));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(TimePickerDialog)))
        .pop(const TimeOfDay(hour: 21, minute: 15));
    await tester.pumpAndSettle();

    expect(find.text('12/9/2026 · 21:15'), findsWidgets);
    expect(find.text('เปลี่ยนเวลาเผยแพร่แล้ว'), findsOneWidget);

    await tester.tap(find.byTooltip('ตัวเลือกเพิ่มเติม'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-scheduled-job')));
    await tester.pumpAndSettle();
    expect(find.text('ยกเลิกการเผยแพร่?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-cancel-job')));
    await tester.pumpAndSettle();

    expect(find.text('ยกเลิกแล้ว'), findsOneWidget);
    expect(find.text('ยกเลิกการเผยแพร่แล้ว'), findsWidgets);
    await tester.tap(find.text('นำกลับ').first);
    await tester.pumpAndSettle();
    expect(find.text('รอถึงเวลา'), findsOneWidget);
  });
}
