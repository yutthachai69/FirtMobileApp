import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/core/auth/auth_controller.dart';
import 'package:relaycontent/features/auth/presentation/auth_page.dart';
import 'package:relaycontent/features/connections/domain/connection.dart';
import 'package:relaycontent/features/home/data/home_api.dart';
import 'package:relaycontent/features/home/domain/home_data.dart';
import 'package:relaycontent/features/home/presentation/home_controller.dart';
import 'package:relaycontent/features/home/presentation/home_page.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('render mobile login and account previews', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('NotoSansThai')
      ..addFont(rootBundle.load('assets/fonts/NotoSansThai.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final auth = AuthController(FakeAuthApi(), MemoryTokenStore());
    await auth.restore();
    final boundaryKey = GlobalKey();
    Future<void> capture(String name, Widget page) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: appTheme(Brightness.light),
            home: page,
          ),
        ),
      );
      // ใช้ pump แบบกำหนดเวลา ไม่ใช่ pumpAndSettle
      // เพราะหน้าหลักมี spinner ของงานที่กำลังทำงานซึ่งหมุนไม่มีวันจบ
      // pumpAndSettle จะรอจนหมดเวลาแล้ว fail
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('.preview').create(recursive: true);
        await File('.preview/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('login', AuthPage(auth: auth));
    await auth.authenticate('user@example.com', 'password');

    // หน้าหลักตอนมีงานจริง — เพื่อดูว่าห้องควบคุมหน้าตาเป็นยังไงเมื่อใช้งานจริง
    final busy = HomeController(auth, _SampleHomeApi(_busySample()));
    await capture('home', HomePage(auth: auth, controller: busy));

    // และตอนยังไม่มีอะไรเลย — ผู้ใช้ใหม่เห็นหน้านี้เป็นหน้าแรก
    final empty = HomeController(auth, _SampleHomeApi(const HomeData()));
    await capture('home-empty', HomePage(auth: auth, controller: empty));

    await tester.pumpWidget(const SizedBox.shrink());
    busy.dispose();
    empty.dispose();
    auth.dispose();
  }, skip: !const bool.fromEnvironment('RENDER_PREVIEWS'));
}

class _SampleHomeApi implements HomeApi {
  _SampleHomeApi(this.data);
  final HomeData data;

  @override
  Future<HomeData> load(String access) async => data;
}

HomeData _busySample() {
  final now = DateTime.now();
  PublishJob job(String caption, JobStatus status, DateTime at) => PublishJob(
        id: caption,
        contentId: caption,
        platform: 'tiktok',
        status: status,
        scheduledAt: at,
        caption: caption,
      );

  return HomeData.build(
    now: now,
    connections: [
      Connection.fromJson(const {
        'id': 'c1',
        'provider': 'tiktok',
        'display_name': '@yutthachai',
        'status': 'needs_reauth',
      }),
    ],
    jobs: [
      job('คลิปขายเสื้อ Oversize แนววัยรุ่น', JobStatus.failed, now),
      job('รีวิวกางเกงยีนส์ทรงใหม่', JobStatus.uploading, now),
      job('เสื้อยืดสีพื้น ลดราคาสิ้นเดือน', JobStatus.scheduled,
          DateTime(now.year, now.month, now.day, 19)),
      job('แจกโค้ดส่วนลดวันศุกร์', JobStatus.scheduled,
          DateTime(now.year, now.month, now.day, 12).add(const Duration(days: 1))),
      job('เปิดกล่องสินค้าใหม่', JobStatus.published,
          now.subtract(const Duration(hours: 3))),
    ],
  );
}
