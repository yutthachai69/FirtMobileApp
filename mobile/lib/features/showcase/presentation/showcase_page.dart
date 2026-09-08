import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../domain/showcase_product.dart';
import 'product_artwork.dart';
import 'saved_products_controller.dart';

enum _ProductFilter { all, saved, highCommission, inStock, unavailable }

class ShowcasePage extends StatefulWidget {
  const ShowcasePage({super.key, this.savedProducts});

  final SavedProductsController? savedProducts;

  @override
  State<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<ShowcasePage> {
  final _search = TextEditingController();
  _ProductFilter _filter = _ProductFilter.all;

  SavedProductsController get _saved =>
      widget.savedProducts ?? savedProductsController;

  @override
  void initState() {
    super.initState();
    _saved.addListener(_onSavedChanged);
  }

  @override
  void dispose() {
    _saved.removeListener(_onSavedChanged);
    _search.dispose();
    super.dispose();
  }

  void _onSavedChanged() {
    if (mounted) setState(() {});
  }

  List<ShowcaseProduct> get _products {
    final query = _search.text.trim().toLowerCase();
    return ShowcaseProduct.mock.where((product) {
      final matchesQuery =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.shopName.toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _ProductFilter.all => true,
        _ProductFilter.saved => _saved.contains(product.id),
        _ProductFilter.highCommission => product.commissionPercent >= 15,
        _ProductFilter.inStock => product.inStock,
        _ProductFilter.unavailable => !product.inStock,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;
    return Scaffold(
      appBar: AppBar(
        title: const Text('สินค้า'),
        actions: [
          IconButton(
            tooltip: 'ซิงก์ข้อมูลตัวอย่าง',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('อัปเดตข้อมูลตัวอย่างแล้ว')),
            ),
            icon: const Icon(Icons.sync_rounded),
          ),
          const SizedBox(width: Spacing.sm),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            0,
            Spacing.md,
            Spacing.lg,
          ),
          children: [
            Text(
              'Showcase ของฉัน',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 2),
            Text(
              '${ShowcaseProduct.mock.length} สินค้าพร้อมใช้สร้างคอนเทนต์',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อสินค้าหรือร้านค้า',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'ล้างคำค้นหา',
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in _ProductFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: Spacing.sm),
                      child: ChoiceChip(
                        label: Text(_filterLabel(filter)),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            _PreviewNotice(),
            const SizedBox(height: Spacing.md),
            if (products.isEmpty)
              _NoResults(
                onReset: () {
                  _search.clear();
                  setState(() => _filter = _ProductFilter.all);
                },
              )
            else
              for (final product in products)
                _ProductCard(
                  product: product,
                  saved: _saved.contains(product.id),
                  onSaved: () => _saved.toggle(product.id),
                  onOpen: () => context.go('/showcase/${product.id}'),
                  onCreate: product.inStock
                      ? () => context.go('/create', extra: product)
                      : null,
                ),
          ],
        ),
      ),
    );
  }

  String _filterLabel(_ProductFilter filter) => switch (filter) {
    _ProductFilter.all => 'ทั้งหมด',
    _ProductFilter.saved => 'บันทึกไว้',
    _ProductFilter.highCommission => 'คอมมิชชันสูง',
    _ProductFilter.inStock => 'พร้อมขาย',
    _ProductFilter.unavailable => 'ไม่พร้อมขาย',
  };
}

class _PreviewNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: context.t.primary.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(Radii.md),
      border: Border.all(color: context.t.primary.withValues(alpha: .2)),
    ),
    child: Row(
      children: [
        Icon(Icons.science_outlined, color: context.t.primary, size: 18),
        const SizedBox(width: Spacing.sm),
        const Expanded(
          child: Text(
            'โหมดตัวอย่าง — ใช้ข้อมูลจำลองเพื่อทดสอบ UX',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onOpen,
    required this.onCreate,
    required this.saved,
    required this.onSaved,
  });
  final ShowcaseProduct product;
  final VoidCallback onOpen;
  final VoidCallback? onCreate;
  final bool saved;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductArtwork(product: p, width: 82, height: 106, hero: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: saved ? 'เลิกบันทึก' : 'บันทึกสินค้า',
                          onPressed: onSaved,
                          icon: Icon(
                            saved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      p.shopName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '฿${p.priceBaht}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'คอม ฿${p.commissionBaht}',
                          style: TextStyle(
                            color: context.t.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          backgroundColor: onCreate == null
                              ? context.t.surfaceElevated
                              : context.t.creative,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: onCreate,
                        icon: Icon(
                          onCreate == null
                              ? Icons.block_rounded
                              : Icons.movie_creation_outlined,
                        ),
                        label: Text(
                          onCreate == null ? 'สินค้าหมดสต็อก' : 'สร้างคอนเทนต์',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 44),
    child: Column(
      children: [
        Icon(
          Icons.search_off_rounded,
          size: 42,
          color: context.t.textSecondary,
        ),
        const SizedBox(height: Spacing.md),
        const Text('ไม่พบสินค้าที่ค้นหา'),
        TextButton(onPressed: onReset, child: const Text('ล้างตัวกรอง')),
      ],
    ),
  );
}
