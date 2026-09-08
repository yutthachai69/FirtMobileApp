import '../../home/domain/home_data.dart';

/// รีมิกซ์งานเก่า — ส่งกลับเข้าเส้นทางสร้างพร้อม "โจทย์ที่ต่างไป"
///
/// RelayContent ไม่เขียน hook หรือสคริปต์ให้ มันแค่เตรียมช่องและบอกว่าให้แก้อะไร
/// ผู้ใช้เป็นคนปรับคอนเทนต์เอง (หรือกลับไปสั่งเครื่องมือ AI ต้นทาง)

enum RemixKind { newHook, newCta, short15, newProduct, newCaption }

class RemixPreset {
  const RemixPreset({
    required this.kind,
    required this.label,
    required this.note,
    required this.seedCaption,
    this.durationSec = 30,
    this.needsProductPick = false,
  });

  final RemixKind kind;
  final String label;

  /// ข้อความบอกว่ารีมิกซ์นี้ให้แก้อะไร แสดงเป็นแบนเนอร์ในหน้า publish
  final String note;
  final String seedCaption;
  final int durationSec;
  final bool needsProductPick;

  static RemixPreset of(RemixKind kind, PublishJob source) {
    final lines = source.caption.split('\n');
    final withoutFirstLine = lines.length > 1
        ? lines.sublist(1).join('\n').trim()
        : '';

    return switch (kind) {
      RemixKind.newHook => RemixPreset(
        kind: kind,
        label: 'เปลี่ยน Hook',
        note: 'รีมิกซ์: เขียนบรรทัดแรกใหม่ให้ต่างจากคลิปเดิม',
        seedCaption: withoutFirstLine,
      ),
      RemixKind.newCta => RemixPreset(
        kind: kind,
        label: 'เปลี่ยนคำชวนกดตะกร้า',
        note: 'รีมิกซ์: ปรับประโยคปิดท้าย/CTA ให้ต่างจากคลิปเดิม',
        seedCaption: source.caption,
      ),
      RemixKind.short15 => RemixPreset(
        kind: kind,
        label: 'ทำเวอร์ชัน 15 วินาที',
        note: 'รีมิกซ์: ตัดให้กระชับเหลือราว 15 วินาที',
        seedCaption: source.caption,
        durationSec: 15,
      ),
      RemixKind.newProduct => RemixPreset(
        kind: kind,
        label: 'เปลี่ยนสินค้า',
        note: 'รีมิกซ์: เลือกสินค้าใหม่แล้วปรับคำบรรยายให้เข้ากับสินค้านั้น',
        seedCaption: source.caption,
        needsProductPick: true,
      ),
      RemixKind.newCaption => RemixPreset(
        kind: kind,
        label: 'เขียนคำบรรยายใหม่',
        note: 'รีมิกซ์: เขียนคำบรรยายใหม่ทั้งหมด',
        seedCaption: '',
      ),
    };
  }
}
