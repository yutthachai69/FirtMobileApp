import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../home/domain/content_store.dart';
import '../domain/opportunity.dart';
import '../domain/showcase_product.dart';
import 'product_artwork.dart';
import 'saved_products_controller.dart';

enum _ProductFilter { all, saved, highCommission, inStock, unavailable }

class ShowcasePage extends StatefulWidget {
  const ShowcasePage({super.key, this.savedProducts, this.store});

  final SavedProductsController? savedProducts;

  /// ใช้คำนวณ Opportunity Radar จากคลิปที่เคยทำ
  final ContentStore? store;

  @override
  State<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<ShowcasePage> {
  final _search = TextEditingController();
  _ProductFilter _filter = _ProductFilter.all;
  bool _selectMode = false;
  final _selected = <String>{};

  void _toggleSelectMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectMode = !_selectMode;
      _selected.clear();
    });
  }

  void _toggleSelected(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    });
  }

  void _startBatch() {
    final picked = ShowcaseProduct.mock
        .where((p) => _selected.contains(p.id))
        .toList();
    context.go('/create/batch', extra: picked);
  }

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
        title: Text(_selectMode ? 'เลือกสินค้าทำเป็นชุด' : 'สินค้า'),
        actions: [
          if (widget.store != null)
            IconButton.outlined(
              key: const Key('toggle-batch-select'),
              tooltip: _selectMode ? 'ยกเลิกเลือกหลายชิ้น' : 'เลือกหลายชิ้น',
              onPressed: _toggleSelectMode,
              style: IconButton.styleFrom(
                foregroundColor: _selectMode
                    ? context.t.creative
                    : context.t.textSecondary,
                backgroundColor: _selectMode
                    ? context.t.creative.withValues(alpha: .1)
                    : context.t.surfaceElevated,
                side: BorderSide(
                  color: _selectMode
                      ? context.t.creative.withValues(alpha: .38)
                      : context.t.border,
                ),
              ),
              icon: Icon(
                _selectMode ? Icons.close_rounded : Icons.checklist_rounded,
              ),
            ),
          if (!_selectMode)
            IconButton.outlined(
              tooltip: 'ซิงก์ข้อมูลตัวอย่าง',
              style: IconButton.styleFrom(
                backgroundColor: context.t.surfaceElevated,
                side: BorderSide(color: context.t.border),
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('อัปเดตข้อมูลตัวอย่างแล้ว')),
                );
              },
              icon: const Icon(Icons.sync_rounded),
            ),
          const SizedBox(width: Spacing.sm),
        ],
      ),
      bottomNavigationBar: _selectMode && _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md,
                  Spacing.sm,
                  Spacing.md,
                  Spacing.md,
                ),
                child: _BatchSelectionTray(
                  count: _selected.length,
                  onStart: _startBatch,
                ),
              ),
            )
          : null,
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
                        avatar: Icon(
                          _filterIcon(filter),
                          size: 16,
                          color: _filter == filter
                              ? context.t.primary
                              : context.t.textSecondary,
                        ),
                        label: Text(_filterLabel(filter)),
                        selected: _filter == filter,
                        showCheckmark: false,
                        side: BorderSide(
                          color: _filter == filter
                              ? context.t.primary.withValues(alpha: .55)
                              : context.t.border,
                        ),
                        selectedColor: context.t.primary.withValues(alpha: .12),
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _filter = filter);
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            if (widget.store != null && !_selectMode)
              _OpportunityRadar(
                opportunities: Opportunity.scan(
                  products: ShowcaseProduct.mock,
                  store: widget.store!,
                ),
                onOpen: (p) => context.go('/showcase/${p.id}'),
                onCreate: (p) => context.go('/create', extra: p),
              ),
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
                  key: ValueKey(product.id),
                  product: product,
                  saved: _saved.contains(product.id),
                  onSaved: () => _saved.toggle(product.id),
                  selectMode: _selectMode,
                  selected: _selected.contains(product.id),
                  onOpen: _selectMode
                      ? () => _toggleSelected(product.id)
                      : () => context.go('/showcase/${product.id}'),
                  onCreate: _selectMode || !product.inStock
                      ? null
                      : () => context.go('/create', extra: product),
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

  IconData _filterIcon(_ProductFilter filter) => switch (filter) {
    _ProductFilter.all => Icons.grid_view_rounded,
    _ProductFilter.saved => Icons.bookmark_outline_rounded,
    _ProductFilter.highCommission => Icons.payments_outlined,
    _ProductFilter.inStock => Icons.inventory_2_outlined,
    _ProductFilter.unavailable => Icons.block_outlined,
  };
}

class _BatchSelectionTray extends StatelessWidget {
  const _BatchSelectionTray({required this.count, required this.onStart});

  final int count;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: context.t.surfaceElevated,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: context.t.creative.withValues(alpha: .35)),
      boxShadow: [
        BoxShadow(
          color: context.t.creative.withValues(alpha: .12),
          blurRadius: 20,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Row(
      children: [
        SizedBox(
          width: 54,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < count.clamp(1, 3); i++)
                Positioned(
                  left: 4.0 + (i * 11),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        context.t.creative,
                        context.t.primary,
                        i / 3,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.t.surfaceElevated,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: i == count.clamp(1, 3) - 1
                          ? Text(
                              '$count',
                              style: TextStyle(
                                color: context.t.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: FilledButton.icon(
            key: const Key('start-batch'),
            style: FilledButton.styleFrom(
              backgroundColor: context.t.creative,
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? context.t.textPrimary
                  : context.t.surfaceContainer,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              onStart();
            },
            icon: const Icon(Icons.playlist_add_rounded),
            label: Text('สร้างเป็นชุด ($count)'),
          ),
        ),
      ],
    ),
  );
}

class _OpportunityRadar extends StatelessWidget {
  const _OpportunityRadar({
    required this.opportunities,
    required this.onOpen,
    required this.onCreate,
  });
  final List<Opportunity> opportunities;
  final void Function(ShowcaseProduct) onOpen;
  final void Function(ShowcaseProduct) onCreate;

  @override
  Widget build(BuildContext context) {
    if (opportunities.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.radar_rounded, size: 18, color: context.t.creative),
              const SizedBox(width: Spacing.sm),
              Text(
                'โอกาสวันนี้',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                '${opportunities.length}',
                style: TextStyle(color: context.t.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          SizedBox(
            height: 152,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: opportunities.length,
              separatorBuilder: (_, _) => const SizedBox(width: Spacing.sm),
              itemBuilder: (context, i) => _OpportunityCard(
                opportunity: opportunities[i],
                onOpen: () => onOpen(opportunities[i].product),
                onCreate: () => onCreate(opportunities[i].product),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.opportunity,
    required this.onOpen,
    required this.onCreate,
  });
  final Opportunity opportunity;
  final VoidCallback onOpen;
  final VoidCallback onCreate;

  ({IconData icon, Color color}) _style(BuildContext context) =>
      switch (opportunity.kind) {
        OpportunityKind.proven => (
          icon: Icons.trending_up_rounded,
          color: context.t.success,
        ),
        OpportunityKind.lowStock => (
          icon: Icons.inventory_2_outlined,
          color: context.t.warning,
        ),
        OpportunityKind.highCommission => (
          icon: Icons.payments_outlined,
          color: context.t.creative,
        ),
        OpportunityKind.noContent => (
          icon: Icons.add_circle_outline_rounded,
          color: context.t.primary,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final s = _style(context);
    return SizedBox(
      width: 236,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.t.surfaceContainer,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: s.color.withValues(alpha: .4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(s.icon, size: 15, color: s.color),
                  const SizedBox(width: 6),
                  Text(
                    opportunity.headline,
                    style: TextStyle(
                      color: s.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                opportunity.product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  opportunity.detail,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: context.t.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    backgroundColor: s.color.withValues(alpha: .16),
                    foregroundColor: s.color,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onCreate();
                  },
                  icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                  label: const Text(
                    'สร้างคอนเทนต์',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

class _ProductCard extends StatefulWidget {
  const _ProductCard({
    super.key,
    required this.product,
    required this.onOpen,
    required this.onCreate,
    required this.saved,
    required this.onSaved,
    this.selectMode = false,
    this.selected = false,
  });
  final ShowcaseProduct product;
  final VoidCallback onOpen;
  final VoidCallback? onCreate;
  final bool saved;
  final VoidCallback onSaved;
  final bool selectMode;
  final bool selected;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return AnimatedScale(
      scale: _pressed ? .985 : 1,
      duration: const Duration(milliseconds: 100),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        elevation: widget.selected ? 4 : 0,
        shadowColor: context.t.primary.withValues(alpha: .28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(
            color: widget.selected ? context.t.primary : context.t.border,
            width: widget.selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onHighlightChanged: (value) {
            if (mounted) setState(() => _pressed = value);
          },
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onOpen();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            color: widget.selected
                ? context.t.primary.withValues(alpha: .055)
                : context.t.surfaceContainer,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.selectMode) ...[
                  AnimatedScale(
                    scale: widget.selected ? 1.08 : 1,
                    duration: const Duration(milliseconds: 160),
                    child: Checkbox(
                      value: widget.selected,
                      onChanged: (_) => widget.onOpen(),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: widget.saved
                                ? 'เลิกบันทึก'
                                : 'บันทึกสินค้า',
                            style: IconButton.styleFrom(
                              foregroundColor: widget.saved
                                  ? context.t.warning
                                  : context.t.textSecondary,
                              backgroundColor: widget.saved
                                  ? context.t.warning.withValues(alpha: .1)
                                  : context.t.surfaceElevated,
                              side: BorderSide(
                                color: widget.saved
                                    ? context.t.warning.withValues(alpha: .3)
                                    : context.t.border,
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              widget.onSaved();
                            },
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Icon(
                                widget.saved
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                key: ValueKey(widget.saved),
                                size: 20,
                              ),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.t.success.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'คอม ฿${p.commissionBaht}',
                              style: TextStyle(
                                color: context.t.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!widget.selectMode) ...[
                        const SizedBox(height: 10),
                        _ProductCreateButton(
                          product: p,
                          onPressed: widget.onCreate,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCreateButton extends StatefulWidget {
  const _ProductCreateButton({required this.product, required this.onPressed});

  final ShowcaseProduct product;
  final VoidCallback? onPressed;

  @override
  State<_ProductCreateButton> createState() => _ProductCreateButtonState();
}

class _ProductCreateButtonState extends State<_ProductCreateButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted || widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final foreground = Theme.of(context).brightness == Brightness.dark
        ? context.t.textPrimary
        : context.t.surfaceContainer;
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? .97 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: double.infinity,
          height: 42,
          decoration: BoxDecoration(
            color: enabled ? null : context.t.surfaceElevated,
            gradient: enabled
                ? LinearGradient(
                    colors: [
                      context.t.creative,
                      Color.lerp(context.t.creative, context.t.primary, .2)!,
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: enabled
                  ? context.t.creative.withValues(alpha: .35)
                  : context.t.border,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (enabled)
                Positioned(
                  right: 11,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        Container(
                          width: 3.0 + i,
                          height: 3.0 + i,
                          decoration: BoxDecoration(
                            color: foreground.withValues(
                              alpha: .13 + (i * .05),
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                    ],
                  ),
                ),
              FilledButton.icon(
                key: Key('create-product-${widget.product.id}'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  backgroundColor: context.t.creative.withValues(alpha: 0),
                  disabledBackgroundColor: context.t.surfaceElevated.withValues(
                    alpha: 0,
                  ),
                  foregroundColor: foreground,
                  disabledForegroundColor: context.t.textSecondary,
                  shadowColor: context.t.creative.withValues(alpha: 0),
                ),
                onPressed: enabled
                    ? () {
                        HapticFeedback.mediumImpact();
                        widget.onPressed!();
                      }
                    : null,
                icon: Icon(
                  enabled ? Icons.movie_creation_outlined : Icons.block_rounded,
                  size: 18,
                ),
                label: Text(enabled ? 'สร้างคอนเทนต์' : 'สินค้าหมดสต็อก'),
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
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () {
            HapticFeedback.selectionClick();
            onReset();
          },
          icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
          label: const Text('ล้างตัวกรอง'),
        ),
      ],
    ),
  );
}
