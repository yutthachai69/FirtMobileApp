import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/core/auth/auth_controller.dart';
import 'package:relaycontent/features/composer/data/composer_api.dart';
import 'package:relaycontent/features/composer/domain/creator_info.dart';
import 'package:relaycontent/features/composer/presentation/composer_controller.dart';
import 'package:relaycontent/features/composer/presentation/tiktok_composer_page.dart';

import 'support/fakes.dart';

/// เทสชุดนี้ตรวจว่ากฎ audit ปรากฏ "บนหน้าจอจริง" ไม่ใช่แค่ใน logic
///
/// เทสของ composer_rules_test.dart ตรวจว่า ComposerState คิดถูก
/// แต่ถ้ามีใครเผลอใส่ค่าเริ่มต้นให้ dropdown ใน widget เทสนั้นจะไม่จับ
/// ทั้งที่เป็นเหตุให้ audit ตกได้ทันที

class FakeComposerApi implements ComposerApi {
  FakeComposerApi({required this.info});
  final CreatorInfo info;
  int creatorInfoCalls = 0;
  Map<String, dynamic>? lastOptions;

  @override
  Future<CreatorInfo> creatorInfo(String access, String connectionId) async {
    creatorInfoCalls++;
    return info;
  }

  @override
  Future<PublishJob> schedule(
    String access, {
    required String contentId,
    required String connectionId,
    required Map<String, dynamic> platformOptions,
    required String idempotencyKey,
    DateTime? scheduledAt,
  }) async {
    lastOptions = platformOptions;
    return const PublishJob(id: 'job_1', status: 'scheduled');
  }

  @override
  Future<PublishJob> get(String access, String jobId) async =>
      const PublishJob(id: 'job_1', status: 'scheduled');
}

CreatorInfo _info({
  List<PrivacyLevel> options = const [
    PrivacyLevel.publicToEveryone,
    PrivacyLevel.selfOnly,
  ],
  bool commentDisabled = false,
}) => CreatorInfo(
  username: 'tester',
  nickname: 'Tester',
  avatarUrl: '',
  privacyLevelOptions: options,
  commentDisabled: commentDisabled,
  duetDisabled: false,
  stitchDisabled: false,
  maxVideoDurationSec: 600,
);

Future<ComposerController> _openPage(
  WidgetTester tester, {
  required FakeComposerApi api,
  bool isAigc = false,
}) async {
  // จอจำลองสูงพอให้ ListView สร้าง widget ครบทั้งหน้า
  // ไม่งั้นปุ่มโพสต์กับข้อความยินยอมจะอยู่นอกจอและหาไม่เจอ
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = AuthController(FakeAuthApi(), MemoryTokenStore());
  // ต้องมี session ก่อน controller ถึงจะเรียก API ได้
  await auth.authenticate('user@example.com', 'password');

  final controller = ComposerController(
    auth: auth,
    api: api,
    contentId: 'content_1',
    connectionId: 'conn_1',
    videoDurationSec: 30,
    isAigc: isAigc,
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: TikTokComposerPage(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('R1 — แสดงชื่อบัญชีที่ดึงสดมา', (tester) async {
    final api = FakeComposerApi(info: _info());
    await _openPage(tester, api: api);

    expect(find.text('@tester'), findsOneWidget);
    // ต้องยิงถามทุกครั้งที่เปิดหน้า ห้ามใช้ค่า cache
    expect(api.creatorInfoCalls, 1);
  });

  testWidgets('R2 — dropdown ต้องไม่มีค่าเลือกไว้ล่วงหน้า', (tester) async {
    await _openPage(tester, api: FakeComposerApi(info: _info()));

    final dropdown = tester.widget<DropdownButtonFormField<PrivacyLevel>>(
      find.byType(DropdownButtonFormField<PrivacyLevel>),
    );
    expect(dropdown.initialValue, isNull);

    // hint ต้องขึ้นให้ผู้ใช้รู้ว่ายังไม่ได้เลือก
    expect(find.text('เลือก'), findsOneWidget);
  });

  testWidgets('R2 — ตัวเลือกมีเท่าที่ creator_info ส่งมาเท่านั้น', (
    tester,
  ) async {
    // บัญชีส่วนตัวไม่มี "ทุกคน" ให้เลือก
    await _openPage(
      tester,
      api: FakeComposerApi(info: _info(options: const [PrivacyLevel.selfOnly])),
    );

    await tester.tap(find.byType(DropdownButtonFormField<PrivacyLevel>));
    await tester.pumpAndSettle();

    expect(find.text('เฉพาะฉัน'), findsWidgets);
    expect(find.text('ทุกคน'), findsNothing);
  });

  testWidgets('R3 — toggle ทั้งหมดต้องเริ่มที่ปิด', (tester) async {
    await _openPage(tester, api: FakeComposerApi(info: _info()));

    final switches = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .toList();

    expect(switches, isNotEmpty);
    for (final s in switches) {
      expect(s.value, isFalse, reason: 'มี toggle ที่ถูกเปิดไว้ล่วงหน้า');
    }
  });

  testWidgets('R3 — ช่องที่บัญชีปิดไว้ต้อง disable', (tester) async {
    await _openPage(
      tester,
      api: FakeComposerApi(info: _info(commentDisabled: true)),
    );

    final comment = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('แสดงความคิดเห็น'),
        matching: find.byType(SwitchListTile),
      ),
    );
    // onChanged เป็น null คือสิ่งที่ทำให้ Flutter disable ตัว switch
    expect(comment.onChanged, isNull);
  });

  testWidgets('ปุ่มโพสต์ต้องกดไม่ได้จนกว่าจะเลือก privacy', (tester) async {
    await _openPage(tester, api: FakeComposerApi(info: _info()));

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    // และต้องบอกเหตุผลด้วย ไม่ใช่ปล่อยให้ผู้ใช้เดา
    expect(find.text('กรุณาเลือกว่าใครดูวิดีโอนี้ได้'), findsOneWidget);
  });

  testWidgets('R6 — ข้อความยินยอมต้องอยู่เหนือปุ่มโพสต์', (tester) async {
    await _openPage(tester, api: FakeComposerApi(info: _info()));

    expect(find.textContaining('Music Usage Confirmation'), findsOneWidget);

    final consentY = tester
        .getTopLeft(find.textContaining('Music Usage Confirmation'))
        .dy;
    final buttonY = tester.getTopLeft(find.byType(FilledButton)).dy;

    expect(
      consentY,
      lessThan(buttonY),
      reason: 'TikTok กำหนดให้ข้อความยินยอมอยู่เหนือปุ่ม',
    );
  });

  testWidgets('R8 — วิดีโอจาก AI ต้องขึ้นข้อความแจ้ง', (tester) async {
    await _openPage(tester, api: FakeComposerApi(info: _info()), isAigc: true);
    expect(find.textContaining('สร้างด้วย AI'), findsOneWidget);
  });

  testWidgets('ไม่ใช่วิดีโอ AI ต้องไม่ขึ้นข้อความนั้น', (tester) async {
    await _openPage(tester, api: FakeComposerApi(info: _info()));
    expect(find.textContaining('สร้างด้วย AI'), findsNothing);
  });

  testWidgets('เลือก privacy แล้วโพสต์ได้ และส่งค่าถูกต้อง', (tester) async {
    final api = FakeComposerApi(info: _info());
    await _openPage(tester, api: api);

    await tester.tap(find.byType(DropdownButtonFormField<PrivacyLevel>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทุกคน').last);
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(api.lastOptions?['privacy_level'], 'PUBLIC_TO_EVERYONE');
    // UI ถามเป็น allow แต่ TikTok รับเป็น disable
    expect(api.lastOptions?['disable_comment'], isTrue);
  });
}
