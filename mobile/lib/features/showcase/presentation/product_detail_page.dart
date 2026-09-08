import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../domain/showcase_product.dart';
import 'product_artwork.dart';
import 'saved_products_controller.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    this.savedProducts,
  });
  final ShowcaseProduct product;
  final SavedProductsController? savedProducts;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  SavedProductsController get _saved =>
      widget.savedProducts ?? savedProductsController;

  bool get saved => _saved.contains(widget.product.id);

  @override
  void initState() {
    super.initState();
    _saved.addListener(_onSavedChanged);
  }

  @override
  void dispose() {
    _saved.removeListener(_onSavedChanged);
    super.dispose();
  }

  void _onSavedChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดสินค้า'),
        actions: [
          IconButton(
            onPressed: () {
              _saved.toggle(widget.product.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    saved ? 'บันทึกสินค้าแล้ว' : 'นำออกจากรายการบันทึกแล้ว',
                  ),
                ),
              );
            },
            tooltip: saved ? 'เลิกบันทึก' : 'บันทึกสินค้า',
            icon: Icon(
              saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, 112),
          children: [
            _ProductHero(product: p),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                _StockBadge(inStock: p.inStock),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Text(p.shopName, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Spacing.md),
            _EarningCard(product: p),
            const SizedBox(height: Spacing.lg),
            Text(
              'จุดเด่นที่ใช้ทำคอนเทนต์',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.sm),
            for (final point in p.sellingPoints)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: context.t.success,
                      size: 18,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(child: Text(point)),
                  ],
                ),
              ),
            const SizedBox(height: Spacing.md),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: context.t.warning.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(
                  color: context.t.warning.withValues(alpha: .28),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: context.t.warning,
                    size: 20,
                  ),
                  const SizedBox(width: Spacing.sm),
                  const Expanded(
                    child: Text(
                      'AI จะอ้างอิงเฉพาะข้อมูลสินค้าที่แสดงในหน้านี้ และให้คุณตรวจก่อนเผยแพร่',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: SafeArea(
        top: false,
        child: Container(
          color: context.t.surface,
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.sm,
            Spacing.md,
            Spacing.md,
          ),
          child: p.inStock
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.t.creative,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => context.go('/create', extra: p),
                  icon: const Icon(Icons.movie_creation_outlined),
                  label: const Text('สร้างคอนเทนต์จากสินค้านี้'),
                )
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.go('/showcase'),
                        child: const Text('เลือกสินค้าอื่น'),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => ScaffoldMessenger.of(context)
                            .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'ตรวจสอบข้อมูลสินค้าอีกครั้งแล้ว',
                                ),
                              ),
                            ),
                        child: const Text('ตรวจอีกครั้ง'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ProductHero extends StatelessWidget {
  const _ProductHero({required this.product});
  final ShowcaseProduct product;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.45,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.t.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.t.surfaceElevated, context.t.surfaceContainer],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: ProductArtwork(
              product: product,
              borderRadius: 22,
              hero: true,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: .25),
                  ],
                ),
              ),
            ),
          ),
          if (product.discountPercent > 0)
            Positioned(
              left: 14,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: context.t.creative,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'ลด ${product.discountPercent}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.inStock});
  final bool inStock;

  @override
  Widget build(BuildContext context) {
    final color = inStock ? context.t.success : context.t.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Text(
        inStock ? 'พร้อมขาย' : 'หมดสต็อก',
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}

class _EarningCard extends StatelessWidget {
  const _EarningCard({required this.product});
  final ShowcaseProduct product;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Spacing.md),
    decoration: BoxDecoration(
      color: context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: context.t.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: _Value(
            label: 'ราคาปัจจุบัน',
            value: '฿${product.priceBaht}',
            color: context.t.textPrimary,
          ),
        ),
        Container(width: 1, height: 48, color: context.t.border),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: Spacing.md),
            child: _Value(
              label: 'ค่าคอมต่อชิ้น',
              value: '฿${product.commissionBaht}',
              color: context.t.success,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
