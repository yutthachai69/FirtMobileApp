import '../../showcase/domain/showcase_product.dart';

/// คะแนนความพร้อมก่อนเผยแพร่ — คิดจากข้อมูลที่หน้า publish มีอยู่แล้ว
/// (caption, แท็ก, ความยาวคลิป, สถานะตะกร้า, สินค้า) ไม่ต้องต่อ backend
///
/// ท่าที: เตือน ไม่บล็อก ผู้ใช้กดเผยแพร่ทั้งที่คะแนนต่ำได้เสมอ
/// หัวข้อที่คะแนนไม่เต็มจะบอกว่าควรแก้อะไร และกดกระโดดไปที่ช่องนั้นได้

enum ReadinessLevel { good, fair, poor }

/// ช่องในหน้า publish ที่หัวข้อหนึ่ง ๆ พาไปแก้ได้
enum ReadinessTarget { caption, basket, none }

class ReadinessCheck {
  const ReadinessCheck({
    required this.id,
    required this.label,
    required this.score,
    required this.maxScore,
    required this.hint,
    this.target = ReadinessTarget.none,
  });

  final String id;
  final String label;
  final int score;
  final int maxScore;

  /// สิ่งที่ควรทำให้คะแนนเต็ม
  final String hint;
  final ReadinessTarget target;

  bool get isFull => score >= maxScore;
  double get ratio => maxScore == 0 ? 1 : score / maxScore;
}

class ReadinessReport {
  const ReadinessReport(this.checks);

  final List<ReadinessCheck> checks;

  int get score => checks.fold(0, (sum, c) => sum + c.score);
  int get maxScore => checks.fold(0, (sum, c) => sum + c.maxScore);
  int get percent => maxScore == 0 ? 0 : (score * 100 / maxScore).round();

  ReadinessLevel get level => switch (percent) {
    >= 80 => ReadinessLevel.good,
    >= 55 => ReadinessLevel.fair,
    _ => ReadinessLevel.poor,
  };

  /// หัวข้อที่ยังไม่เต็ม เรียงจากที่เสียคะแนนมากสุด
  List<ReadinessCheck> get weakest =>
      checks.where((c) => !c.isFull).toList()
        ..sort((a, b) => (a.ratio).compareTo(b.ratio));

  static const _riskyClaims = [
    'รักษา',
    'หายขาด',
    'หาย 100',
    '100%',
    'การันตี',
    'ที่สุดในโลก',
    'ปลอดภัยที่สุด',
    'เห็นผลทันที',
    'ถูกที่สุด',
  ];

  /// คำนวณคะแนน — ฟังก์ชันล้วน เทสได้โดยไม่ต้องมี widget
  static ReadinessReport evaluate({
    required String caption,
    required Set<String> tags,
    required int durationSec,
    required bool basketEnabled,
    required ShowcaseProduct product,
  }) {
    final text = caption.trim();
    final lower = text.toLowerCase();
    final firstLine = text.isEmpty ? '' : text.split('\n').first.trim();

    // Hook — บรรทัดแรกต้องสั้น กระชับ และมีตัวเลขหรือเครื่องหมายกระตุ้น
    var hook = 0;
    if (firstLine.isNotEmpty) {
      hook += 6;
      if (firstLine.runes.length >= 8 &&
          firstLine.runes.length <= 60) {
        hook += 8;
      }
      if (RegExp(r'[0-9]').hasMatch(firstLine) ||
          firstLine.contains('?') ||
          firstLine.contains('!') ||
          firstLine.contains('ทำไม') ||
          firstLine.contains('อย่าเพิ่ง')) {
        hook += 6;
      }
    }

    // สินค้าปรากฏในคำบรรยาย
    var product0 = 0;
    if (lower.contains(product.name.toLowerCase())) {
      product0 += 9;
    }
    if (product.sellingPoints.any(
      (p) => lower.contains(p.toLowerCase().split(' ').first),
    )) {
      product0 += 6;
    }

    // CTA + ตะกร้า
    var cta = basketEnabled ? 13 : 0;
    if (RegExp(
      'ตะกร้า|กดที่|ช้อป|สั่งซื้อ|ลิงก์|โปรโมชั่น|ส่วนลด',
    ).hasMatch(text)) {
      cta += 7;
    }

    // ความยาวคลิป — ช่วงที่เหมาะกับ shoppable video
    final length = switch (durationSec) {
      >= 15 && <= 45 => 15,
      >= 10 && <= 60 => 11,
      >= 7 && <= 80 => 6,
      _ => 2,
    };

    // ความลึกของ caption
    var depth = 0;
    if (text.runes.length >= 40) depth += 8;
    if (text.runes.length >= 90) depth += 3;
    if (tags.isNotEmpty) depth += 4;

    // ความเสี่ยงคำกล่าวอ้าง — ไม่มีคำเสี่ยง = เต็ม
    final hits = _riskyClaims.where(lower.contains).toList();
    final claims = hits.isEmpty ? 15 : (hits.length == 1 ? 7 : 0);

    return ReadinessReport([
      ReadinessCheck(
        id: 'hook',
        label: 'Hook เปิดเรื่อง',
        score: hook.clamp(0, 20),
        maxScore: 20,
        hint: 'ขึ้นต้นด้วยประโยคสั้น ๆ ที่มีตัวเลขหรือคำถามดึงให้ดูต่อ',
        target: ReadinessTarget.caption,
      ),
      ReadinessCheck(
        id: 'product',
        label: 'พูดถึงตัวสินค้า',
        score: product0.clamp(0, 15),
        maxScore: 15,
        hint: 'ใส่ชื่อสินค้าและจุดขายอย่างน้อยหนึ่งข้อในคำบรรยาย',
        target: ReadinessTarget.caption,
      ),
      ReadinessCheck(
        id: 'cta',
        label: 'ชวนกดตะกร้า',
        score: cta.clamp(0, 20),
        maxScore: 20,
        hint: basketEnabled
            ? 'เพิ่มประโยคบอกให้กดตะกร้าหรือดูโปรในคลิป'
            : 'เปิดปักตะกร้าสินค้า แล้วเพิ่มประโยคชวนกด',
        target: basketEnabled
            ? ReadinessTarget.caption
            : ReadinessTarget.basket,
      ),
      ReadinessCheck(
        id: 'length',
        label: 'ความยาวคลิป',
        score: length,
        maxScore: 15,
        hint: 'คลิปขายของทำงานดีที่สุดช่วง 15–45 วินาที',
        target: ReadinessTarget.none,
      ),
      ReadinessCheck(
        id: 'caption',
        label: 'รายละเอียดคำบรรยาย',
        score: depth.clamp(0, 15),
        maxScore: 15,
        hint: 'เขียนอย่างน้อย 2–3 บรรทัด และติดแฮชแท็กที่เกี่ยวข้อง',
        target: ReadinessTarget.caption,
      ),
      ReadinessCheck(
        id: 'claims',
        label: 'ความเสี่ยงคำกล่าวอ้าง',
        score: claims,
        maxScore: 15,
        hint: hits.isEmpty
            ? 'ไม่พบคำกล่าวอ้างเกินจริง'
            : 'เลี่ยงคำเช่น "${hits.first}" ที่อาจโดน TikTok จำกัดการมองเห็น',
        target: ReadinessTarget.caption,
      ),
    ]);
  }
}
