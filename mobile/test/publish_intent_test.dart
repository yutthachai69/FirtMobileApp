import 'package:flutter_test/flutter_test.dart';

import 'package:relaycontent/features/create/domain/publish_intent.dart';

void main() {
  test('keeps one id across upload and content checkpoints', () {
    final intent = PublishIntent.create();
    final withAsset = intent.copyWith(assetId: 'asset-1');
    final withContent = withAsset.copyWith(contentId: 'content-1');

    expect(withAsset.id, intent.id);
    expect(withContent.id, intent.id);
    expect(withContent.assetId, 'asset-1');
    expect(withContent.contentId, 'content-1');
  });

  test('new intents use different ids', () {
    expect(PublishIntent.create().id, isNot(PublishIntent.create().id));
  });
}
