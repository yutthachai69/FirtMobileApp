import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../domain/showcase_product.dart';

/// หน้าสินค้าจาก TikTok Shop Showcase (D01 ในดีไซน์ที่อนุมัติแล้ว)
///
/// ⚠️ แสดงข้อมูลตัวอย่างเท่านั้น — ยังไม่มี backend เชื่อม TikTok Shop จริง
/// รอสมัคร TikTok Shop Partner Center ก่อน (ดู system-design-v1.md หัวข้อ 0.1)
/// ต้องมี banner บอกชัดว่าเป็นตัวอย่าง ตามกติกาที่ตกลงไว้ในเอกสารดีไซน์
/// ห้ามทำให้ดูเหมือนใช้งานได้จริงเพราะจะหลอกผู้ใช้ทดสอบ
class ShowcasePage extends StatelessWidget {
  const ShowcasePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('สินค้า')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(Spacing.md),
            children: [
              _PreviewBanner(),
              const SizedBox(height: Spacing.lg),
              Text(
                'Showcase ของฉัน',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'สินค้าที่คุณเชื่อมต่อไว้ใน TikTok Shop',
                style: TextStyle(color: context.t.textSecondary),
              ),
              const SizedBox(height: Spacing.md),
              for (final p in ShowcaseProduct.mock) _ProductCard(product: p),
            ],
          ),
        ),
      );
}

class _PreviewBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: context.t.warning.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: context.t.warning.withValues(alpha: .4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: context.t.warning, size: 20),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                'ตัวอย่างหน้าจอ — ยังไม่ได้เชื่อมต่อ TikTok Shop จริง '
                'สินค้าด้านล่างเป็นข้อมูลสมมติเพื่อดูหน้าตาก่อน',
                style: TextStyle(color: context.t.warning, fontSize: 13),
              ),
            ),
          ],
        ),
      );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});
  final ShowcaseProduct product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Opacity(
      opacity: p.inStock ? 1 : .5,
      child: Card(
        margin: const EdgeInsets.only(bottom: Spacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: context.t.surfaceElevated,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: context.t.textSecondary,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.discountPercent > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.t.creative,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'คอม ${p.commissionPercent}% · ฿${p.commissionBaht}/ชิ้น',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      '฿${p.priceBaht}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.inStock ? 'สต็อก ${p.stock} ชิ้น' : 'สินค้าหมดสต็อก',
                      style: TextStyle(
                        color: p.inStock
                            ? context.t.textSecondary
                            : context.t.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.sm),
              // ปุ่มในธีมตั้ง minimumSize เป็นความกว้างไม่จำกัด (เต็มจอ) โดยตั้งใจ
              // เพราะปุ่มหลักส่วนใหญ่อยู่เดี่ยว ๆ ใต้ฟอร์ม — ที่นี่อยู่ใน Row
              // จึงต้องกำหนดขนาดเองไม่งั้น layout พัง (BoxConstraints w=Infinity)
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  // ⚠️ ต้องระบุ fontFamily ซ้ำทุกครั้งที่ override textStyle
                  // ไม่งั้นจะทับค่าจากธีมทิ้งไปเงียบ ๆ แล้วภาษาไทยกลายเป็นกล่องสี่เหลี่ยม
                  textStyle: const TextStyle(
                    fontFamily: 'NotoSansThai',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: p.inStock
                    ? () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'การผูกสินค้าจริงจะเปิดใช้เมื่อเชื่อมต่อ TikTok Shop สำเร็จ',
                            ),
                          ),
                        )
                    : null,
                child: const Text('สร้างคอนเทนต์'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
