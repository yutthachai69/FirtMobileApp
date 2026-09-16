class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.readAt,
    required this.createdAt,
    required this.data,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime? readAt;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final rawReadAt = json['read_at'];
    final rawCreatedAt = json['created_at'];
    return AppNotification(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'update',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      readAt: rawReadAt is String ? DateTime.tryParse(rawReadAt) : null,
      createdAt: rawCreatedAt is String
          ? DateTime.tryParse(rawCreatedAt) ?? DateTime.now()
          : DateTime.now(),
      data: rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : const <String, dynamic>{},
    );
  }

  AppNotification markRead() => isRead
      ? this
      : AppNotification(
          id: id,
          type: type,
          title: title,
          body: body,
          readAt: DateTime.now(),
          createdAt: createdAt,
          data: data,
        );
}
