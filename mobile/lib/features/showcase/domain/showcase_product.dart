/// สินค้าจาก TikTok Shop Showcase ของ creator
///
/// ⚠️ ยังไม่มี backend จริง — รอสมัคร TikTok Shop Partner Center และยืนยัน
/// scope ของ Affiliate Creator API ก่อน (ดู system-design-v1.md หัวข้อ 0.1)
/// ตอนนี้ [ShowcaseProduct.mock] คือข้อมูลตัวอย่างล้วน ๆ เพื่อสร้าง UI ตามดีไซน์
/// ที่อนุมัติแล้วใน stitch_relaycontent_mobile_ux_review3/
class ShowcaseProduct {
  const ShowcaseProduct({
    required this.id,
    required this.name,
    required this.priceBaht,
    required this.commissionPercent,
    required this.stock,
    this.discountPercent = 0,
  });

  final String id;
  final String name;
  final int priceBaht;
  final int commissionPercent;
  final int stock;
  final int discountPercent;

  int get commissionBaht => (priceBaht * commissionPercent / 100).round();
  bool get inStock => stock > 0;

  static const mock = [
    ShowcaseProduct(
      id: 'mock-1',
      name: 'เซรั่มวิตซีหน้าใส ไฮยาลูรอนเข้มข้น 30ml',
      priceBaht: 290,
      commissionPercent: 20,
      stock: 1420,
      discountPercent: 25,
    ),
    ShowcaseProduct(
      id: 'mock-2',
      name: 'ไมโครโฟนไร้สาย สำหรับ Live และถ่ายคลิป',
      priceBaht: 850,
      commissionPercent: 15,
      stock: 340,
    ),
    ShowcaseProduct(
      id: 'mock-3',
      name: 'แก้วเก็บความเย็น 900ml สแตนเลส',
      priceBaht: 350,
      commissionPercent: 12,
      stock: 0,
    ),
  ];
}
