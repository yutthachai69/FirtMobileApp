import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/core/auth/auth_controller.dart';
import 'package:relaycontent/features/auth/presentation/auth_page.dart';
import 'package:relaycontent/features/connections/data/connections_api.dart';
import 'package:relaycontent/features/connections/domain/connection.dart';
import 'package:relaycontent/features/create/data/create_api.dart';
import 'package:relaycontent/features/create/domain/picked_video.dart';
import 'package:relaycontent/features/create/presentation/create_controller.dart';
import 'package:relaycontent/features/create/presentation/create_page.dart';
import 'package:relaycontent/features/home/data/home_api.dart';
import 'package:relaycontent/features/home/domain/home_data.dart';
import 'package:relaycontent/features/home/presentation/home_controller.dart';
import 'package:relaycontent/features/home/presentation/content_library_page.dart';
import 'package:relaycontent/features/home/presentation/home_page.dart';
import 'package:relaycontent/features/showcase/presentation/showcase_page.dart';

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
            key: ValueKey(name),
            debugShowCheckedModeBanner: false,
            theme: appTheme(Brightness.dark),
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

    // หน้าสร้างคอนเทนต์ ขั้นเลือกวิดีโอ
    final create = CreateController(
      auth: auth,
      api: _StubCreateApi(),
      connections: _StubConnectionsApi(),
    );
    await capture('create', CreatePage(controller: create));

    // แท็บใหม่ของ bottom nav — สินค้า (mock) และ คอนเทนต์ (backend จริง)
    await capture('showcase', const ShowcasePage());
    final content = HomeController(auth, _SampleHomeApi(_busySample()));
    await capture('content-library', ContentLibraryPage(controller: content));

    await tester.pumpWidget(const SizedBox.shrink());
    create.dispose();
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


class _StubCreateApi implements CreateApi {
  @override
  Future<UploadTicket> requestUpload(String a, PickedVideo v) async =>
      const UploadTicket(assetId: 'a', url: 'https://example.test', headers: {});
  @override
  Future<void> upload(UploadTicket t, PickedVideo v,
      {void Function(int, int)? onProgress}) async {}
  @override
  Future<String> completeUpload(String a, String id) async => '';
  @override
  Future<String> createContent(String a,
          {required String caption, required String mediaAssetId}) async =>
      'content-1';
}

class _StubConnectionsApi implements ConnectionsApi {
  @override
  Future<ConnectionList> list(String access) async => ConnectionList(
        tiktokEnabled: true,
        items: [
          Connection.fromJson(const {
            'id': 'c1',
            'provider': 'tiktok',
            'display_name': '@yutthachai',
            'status': 'active',
          }),
        ],
      );
  @override
  Future<String> startTikTokOAuth(String access) async => '';
  @override
  Future<void> remove(String access, String id) async {}
  @override
  Future<Map<String, dynamic>> creatorInfo(String a, String id) async => const {};
}
