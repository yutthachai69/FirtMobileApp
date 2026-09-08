import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../showcase/domain/showcase_product.dart';
import '../../showcase/presentation/product_artwork.dart';

class CreateHubPage extends StatelessWidget {
  const CreateHubPage({super.key, this.selectedProduct});

  final ShowcaseProduct? selectedProduct;

  @override
  Widget build(BuildContext context) {
    final product = selectedProduct;
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างคอนเทนต์')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Spacing.md, 8, Spacing.md, 110),
          children: [
            Text(
              'เริ่มจากแบบที่เหมาะกับคุณ',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'รับคอนเทนต์จาก AI ที่คุณใช้ แล้วผูกสินค้าและจัดคิวต่อในที่เดียว',
              style: TextStyle(color: context.t.textSecondary),
            ),
            const SizedBox(height: Spacing.lg),
            if (product != null) ...[
              _ProductStrip(product: product),
              const SizedBox(height: Spacing.lg),
            ],
            _CreateChoice(
              icon: Icons.hub_outlined,
              title: 'รับคอนเทนต์จาก AI',
              description: 'เปิด AI Content Inbox จากบัญชีที่เชื่อมไว้ หรือแชร์คลิปเข้ามา',
              badge: 'ทางหลัก',
              color: context.t.primary,
              onTap: () => context.go('/create/import-ai', extra: product),
            ),
            const SizedBox(height: 12),
            _CreateChoice(
              icon: Icons.video_library_outlined,
              title: 'นำเข้าคลิปจากมือถือ',
              description:
                  'อัปโหลดคลิป เขียนแคปชัน และเตรียมส่งต่อไปหน้าตรวจสอบ',
              color: context.t.success,
              onTap: () => context.go('/create/upload', extra: product),
            ),
            const SizedBox(height: 12),
            _CreateChoice(
              icon: Icons.video_camera_back_outlined,
              title: 'ถ่ายคลิปรีวิวแบบมีไกด์',
              description: 'ใช้ shot list และคำแนะนำบนกล้อง ถ่ายทีละช่วงแล้วเลือกเทคที่ดีที่สุด',
              badge: 'ใหม่',
              color: context.t.warning,
              onTap: () {
                if (product == null) {
                  context.go('/showcase');
                } else {
                  context.go('/create/guided', extra: product);
                }
              },
            ),
            const SizedBox(height: 12),
            _CreateChoice(
              icon: Icons.auto_awesome_rounded,
              title: 'สร้างด้วย AI ใน RelayContent',
              description: product == null
                  ? 'ทดลอง flow ด้วยสินค้าตัวอย่าง หรือเลือกสินค้าของคุณก่อนเริ่ม'
                  : 'เลือกมุมขาย น้ำเสียง และความยาว แล้วปรับสคริปต์ก่อนอนุมัติ',
              badge: 'รอง · ทดลอง',
              color: context.t.creative,
              onTap: () => context.go(
                '/create/ai',
                extra: product ?? ShowcaseProduct.mock.first,
              ),
            ),
            const SizedBox(height: 12),
            if (product == null) ...[
              const SizedBox(height: Spacing.lg),
              OutlinedButton.icon(
                onPressed: () => context.go('/showcase'),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('เลือกสินค้าก่อนสร้าง'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductStrip extends StatelessWidget {
  const _ProductStrip({required this.product});
  final ShowcaseProduct product;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: context.t.border),
    ),
    child: Row(
      children: [
        ProductArtwork(product: product, width: 52, height: 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'กำลังสร้างให้สินค้านี้',
                style: TextStyle(fontSize: 11),
              ),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'รับ ฿${product.commissionBaht}/ชิ้น',
                style: TextStyle(color: context.t.success, fontSize: 12),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => context.go('/showcase'),
          child: const Text('เปลี่ยน'),
        ),
      ],
    ),
  );
}

class _CreateChoice extends StatelessWidget {
  const _CreateChoice({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) => Material(
    color: context.t.surfaceContainer,
    borderRadius: BorderRadius.circular(Radii.lg),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .13),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(color: color, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: context.t.textSecondary,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}
