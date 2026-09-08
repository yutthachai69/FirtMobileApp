import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/core/auth/auth_controller.dart';
import 'package:relaycontent/features/connections/data/connections_api.dart';
import 'package:relaycontent/features/connections/domain/connection.dart';
import 'package:relaycontent/features/create/data/create_api.dart';
import 'package:relaycontent/features/create/domain/picked_video.dart';
import 'package:relaycontent/features/create/presentation/create_controller.dart';
import 'package:relaycontent/features/create/presentation/create_page.dart';
import 'package:relaycontent/features/showcase/domain/showcase_product.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('เลือกเฟรมภาพปกหลังอัปโหลดได้', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = AuthController(FakeAuthApi(), MemoryTokenStore());
    final controller =
        CreateController(
            auth: auth,
            api: _UnusedCreateApi(),
            connections: _UnusedConnectionsApi(),
          )
          ..step = CreateStep.describe
          ..video = PickedVideo(
            name: 'review.mp4',
            sizeBytes: 5 * 1024 * 1024,
            mime: 'video/mp4',
            openRead: () => Stream.value(Uint8List(0)),
          );
    addTearDown(auth.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: CreatePage(
          controller: controller,
          selectedProduct: ShowcaseProduct.mock.first,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('manage-uploaded-clip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('select-thumbnail-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const Key('thumbnail-0.15')), findsOneWidget);
    await tester.tap(find.byKey(const Key('thumbnail-0.85')));
    await tester.tap(find.byKey(const Key('confirm-thumbnail')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ภาพปกที่ 26 วินาที'), findsOneWidget);
  });
}

class _UnusedCreateApi implements CreateApi {
  @override
  Future<String> completeUpload(String access, String assetId) =>
      throw UnimplementedError();

  @override
  Future<String> createContent(
    String access, {
    required String caption,
    required String mediaAssetId,
  }) => throw UnimplementedError();

  @override
  Future<UploadTicket> requestUpload(String access, PickedVideo video) =>
      throw UnimplementedError();

  @override
  Future<void> upload(
    UploadTicket ticket,
    PickedVideo video, {
    void Function(int sent, int total)? onProgress,
  }) => throw UnimplementedError();
}

class _UnusedConnectionsApi implements ConnectionsApi {
  @override
  Future<Map<String, dynamic>> creatorInfo(
    String access,
    String connectionId,
  ) => throw UnimplementedError();

  @override
  Future<ConnectionList> list(String access) => throw UnimplementedError();

  @override
  Future<void> remove(String access, String connectionId) =>
      throw UnimplementedError();

  @override
  Future<String> startTikTokOAuth(String access) => throw UnimplementedError();
}
