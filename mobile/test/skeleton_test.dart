import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/app/widgets/skeleton.dart';

void main() {
  Widget host({required bool reducedMotion, required Widget child}) => MaterialApp(
    theme: AppTheme.dark(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: child),
    ),
  );

  testWidgets('SkeletonList แสดงการ์ดจำลองตามจำนวนที่ขอ', (tester) async {
    await tester.pumpWidget(
      host(reducedMotion: false, child: const SkeletonList(itemCount: 3)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Skeleton), findsWidgets);
    // การ์ดละ 1 thumbnail + 3 บรรทัดข้อความ = 4 ต่อการ์ด
    expect(tester.widgetList(find.byType(Skeleton)).length, 12);
  });

  testWidgets('เปิดลดการเคลื่อนไหวแล้ว shimmer หยุด (ไม่มี ShaderMask)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(reducedMotion: true, child: const Skeleton(width: 80)),
    );
    await tester.pump();

    expect(find.byType(ShaderMask), findsNothing);
  });

  testWidgets('motion ปกติ shimmer ทำงาน (มี ShaderMask)', (tester) async {
    await tester.pumpWidget(
      host(reducedMotion: false, child: const Skeleton(width: 80)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ShaderMask), findsOneWidget);

    // เคลียร์ animation ที่ยัง repeat อยู่
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
