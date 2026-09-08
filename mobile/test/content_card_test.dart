import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/features/home/domain/home_data.dart';
import 'package:relaycontent/features/home/presentation/home_page.dart';

void main() {
  testWidgets('content card มีภาพสถานะและ action ตาม lifecycle', (
    tester,
  ) async {
    final job = PublishJob(
      id: 'scheduled-card',
      contentId: 'content-1',
      platform: 'tiktok',
      status: JobStatus.scheduled,
      scheduledAt: DateTime(2026, 9, 9, 19, 30),
      caption: 'ป้ายยาแก้วเก็บความเย็น พร้อมโปรประจำสัปดาห์',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: Scaffold(
          body: JobCard(job: job, onTap: () {}),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('ตั้งเวลา'), findsOneWidget);
    await tester.tap(find.byTooltip('จัดการคอนเทนต์'));
    await tester.pumpAndSettle();

    expect(find.text('เปลี่ยนเวลาเผยแพร่'), findsOneWidget);
    expect(find.text('พักการเผยแพร่'), findsOneWidget);
  });
}
