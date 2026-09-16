import 'dart:math';

/// Stable client-side identity for one upload-to-publish attempt.
///
/// The same id is carried into the backend `Idempotency-Key` so a retry after
/// a timeout resolves to the original publish job instead of creating a new
/// post. A new intent is created only when the user starts over.
class PublishIntent {
  PublishIntent({required this.id, this.assetId, this.contentId});

  factory PublishIntent.create() => PublishIntent(id: _newId());

  final String id;
  final String? assetId;
  final String? contentId;

  PublishIntent copyWith({String? assetId, String? contentId}) => PublishIntent(
    id: id,
    assetId: assetId ?? this.assetId,
    contentId: contentId ?? this.contentId,
  );

  static String _newId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
