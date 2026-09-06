import 'dart:typed_data';

/// วิดีโอที่ผู้ใช้เลือกจากเครื่อง
///
/// เก็บเป็น "วิธีเปิดอ่าน" ไม่ใช่ตัวข้อมูล — วิดีโอ 100MB ที่โหลดเข้าหน่วยความจำ
/// ทั้งก้อนทำให้แอปถูกระบบฆ่าบนเครื่องสเปกต่ำ
///
/// [openRead] เป็นฟังก์ชันเพราะ stream อ่านได้ครั้งเดียว
/// ถ้าต้องอัปใหม่ (retry) ต้องเปิด stream ใหม่
class PickedVideo {
  const PickedVideo({
    required this.name,
    required this.sizeBytes,
    required this.mime,
    required this.openRead,
  });

  final String name;
  final int sizeBytes;
  final String mime;
  final Stream<Uint8List> Function() openRead;

  String get readableSize {
    const mb = 1024 * 1024;
    if (sizeBytes >= mb) return '${(sizeBytes / mb).toStringAsFixed(1)} MB';
    return '${(sizeBytes / 1024).round()} KB';
  }

  /// mimeFromName เดา mime จากนามสกุล
  ///
  /// backend รับเฉพาะชนิดที่ TikTok รองรับ ถ้าเดาผิดจะถูกปฏิเสธตั้งแต่ขอ URL
  static String mimeFromName(String name) =>
      name.toLowerCase().endsWith('.mov') ? 'video/quicktime' : 'video/mp4';
}
