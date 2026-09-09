import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/features/home/domain/home_data.dart';
import 'package:relaycontent/features/home/presentation/content_planner.dart';

PublishJob _job(String id, DateTime at, {JobStatus status = JobStatus.scheduled}) =>
    PublishJob(
      id: id,
      contentId: 'c-$id',
      platform: 'tiktok',
      status: status,
      scheduledAt: at,
      caption: 'งาน $id',
    );

void main() {
  DateTime mondayOfThisWeek() {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day);
    return d.subtract(Duration(days: now.weekday - 1));
  }

  testWidgets('ปฏิทินแสดงงานในวันของมัน และวันว่างมีเวลาที่แนะนำ', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tue = mondayOfThisWeek().add(const Duration(days: 1, hours: 19, minutes: 30));

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: Scaffold(
          body: ContentPlanner(
            jobs: [_job('a', tue)],
            onReschedule: (_, _) {},
            onOpen: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('สัปดาห์นี้'), findsOneWidget);
    expect(find.text('งาน a'), findsOneWidget);
    expect(find.textContaining('แนะนำ'), findsWidgets);
  });

  testWidgets('ลากงานข้ามวันเรียก onReschedule ด้วยวันใหม่', (tester) async {
    tester.view.physicalSize = const Size(430, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final monday = mondayOfThisWeek();
    final tue = monday.add(const Duration(days: 1, hours: 19, minutes: 30));
    DateTime? movedTo;
    String? movedId;

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: Scaffold(
          body: ContentPlanner(
            jobs: [_job('a', tue)],
            onReschedule: (id, date) {
              movedId = id;
              movedTo = date;
            },
            onOpen: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final thursdayHeader = find.textContaining(
      '${monday.add(const Duration(days: 3)).day}/'
      '${monday.add(const Duration(days: 3)).month}',
    );
    expect(thursdayHeader, findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('งาน a')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(thursdayHeader));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(movedId, 'a');
    expect(movedTo, isNotNull);
    expect(movedTo!.day, monday.add(const Duration(days: 3)).day);
    expect(movedTo!.hour, 19);
    expect(movedTo!.minute, 30);
  });
}
