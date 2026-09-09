import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../home/domain/content_store.dart';
import '../../home/domain/home_data.dart';
import '../../showcase/domain/showcase_product.dart';
import '../../showcase/presentation/product_artwork.dart';

/// สร้างคอนเทนต์เป็นชุด — เลือกสินค้าหลายตัวจาก Showcase แล้ววิ่งผ่าน flow เดียว
///
/// ระบบกระจายวันเวลาให้อัตโนมัติ (หนึ่งชิ้นต่อวัน สลับช่วงเวลาแนะนำ)
/// ผู้ใช้ปรับคำบรรยายและเลื่อนวันรายชิ้นได้ ก่อนยืนยันทั้งชุด
class BatchCreatePage extends StatefulWidget {
  const BatchCreatePage({super.key, required this.products, this.store});

  final List<ShowcaseProduct> products;
  final ContentStore? store;

  @override
  State<BatchCreatePage> createState() => _BatchCreatePageState();
}

class _BatchCreatePageState extends State<BatchCreatePage> {
  static const _slots = [
    (19, 30),
    (12, 0),
    (21, 0),
  ];
  final _rows = <_BatchRow>[];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final base = DateTime.now().add(const Duration(days: 1));
    for (var i = 0; i < widget.products.length; i++) {
      final p = widget.products[i];
      final slot = _slots[i % _slots.length];
      _rows.add(
        _BatchRow(
          product: p,
          caption: TextEditingController(
            text:
                '${p.name} ที่อยากให้ลอง ✨ ${p.sellingPoints.first} '
                'ดูโปรได้ที่ตะกร้า',
          ),
          slot: DateTime(
            base.year,
            base.month,
            base.day + i,
            slot.$1,
            slot.$2,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.caption.dispose();
    }
    super.dispose();
  }

  int get _dayCount =>
      _rows.map((r) => DateTime(r.slot.year, r.slot.month, r.slot.day)).toSet()
          .length;

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final now = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      widget.store?.add(
        PublishJob(
          id: 'job-$now-$i',
          contentId: 'content-$now-$i',
          productId: r.product.id,
          platform: 'tiktok',
          status: JobStatus.scheduled,
          scheduledAt: r.slot,
          caption: r.caption.text.trim(),
          sourceLabel: 'สร้างเป็นชุด',
        ),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ตั้งเวลา ${_rows.length} คลิปเป็นชุดแล้ว')),
    );
    context.go('/content');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างเป็นชุด')),
      body: SafeArea(
        child: _rows.isEmpty
            ? _empty(context)
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md,
                  Spacing.sm,
                  Spacing.md,
                  Spacing.xl,
                ),
                children: [
                  Text(
                    '${_rows.length} คลิป · กระจาย $_dayCount วัน',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ปรับคำบรรยายและเลื่อนวันได้ก่อนยืนยัน',
                    style: TextStyle(
                      color: context.t.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  for (var i = 0; i < _rows.length; i++)
                    _BatchRowCard(
                      row: _rows[i],
                      onShiftDay: (delta) => setState(
                        () => _rows[i].slot = _rows[i].slot.add(
                          Duration(days: delta),
                        ),
                      ),
                      onRemove: () => setState(() => _rows.removeAt(i)),
                    ),
                ],
              ),
      ),
      bottomNavigationBar: _rows.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md,
                  Spacing.sm,
                  Spacing.md,
                  Spacing.md,
                ),
                child: FilledButton.icon(
                  key: const Key('confirm-batch'),
                  onPressed: _submitting ? null : _confirm,
                  icon: Icon(
                    _submitting
                        ? Icons.sync_rounded
                        : Icons.event_available_rounded,
                  ),
                  label: Text(
                    _submitting
                        ? 'กำลังตั้งเวลา…'
                        : 'ยืนยันทั้งชุด (${_rows.length})',
                  ),
                ),
              ),
            ),
    );
  }

  Widget _empty(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.playlist_remove_rounded,
            size: 48,
            color: context.t.textSecondary,
          ),
          const SizedBox(height: Spacing.md),
          const Text('ไม่มีสินค้าในชุดแล้ว'),
          const SizedBox(height: Spacing.md),
          FilledButton(
            onPressed: () => context.go('/showcase'),
            child: const Text('กลับไปเลือกสินค้า'),
          ),
        ],
      ),
    ),
  );
}

class _BatchRow {
  _BatchRow({
    required this.product,
    required this.caption,
    required this.slot,
  });
  final ShowcaseProduct product;
  final TextEditingController caption;
  DateTime slot;
}

class _BatchRowCard extends StatelessWidget {
  const _BatchRowCard({
    required this.row,
    required this.onShiftDay,
    required this.onRemove,
  });
  final _BatchRow row;
  final void Function(int delta) onShiftDay;
  final VoidCallback onRemove;

  String get _slotText {
    final d = row.slot;
    final now = DateTime.now();
    final label = _sameDay(d, now.add(const Duration(days: 1)))
        ? 'พรุ่งนี้'
        : '${d.day}/${d.month}';
    final clock =
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
    return '$label · $clock';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: context.t.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductArtwork(product: row.product, width: 46, height: 58),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                row.product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'เอาออกจากชุด',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: row.caption,
          minLines: 2,
          maxLines: 3,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'คำบรรยายของคลิปนี้',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 16,
              color: context.t.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(_slotText, style: const TextStyle(fontSize: 12)),
            const Spacer(),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'เลื่อนเร็วขึ้นหนึ่งวัน',
              onPressed: () => onShiftDay(-1),
              icon: const Icon(Icons.remove_rounded, size: 18),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'เลื่อนออกไปหนึ่งวัน',
              onPressed: () => onShiftDay(1),
              icon: const Icon(Icons.add_rounded, size: 18),
            ),
          ],
        ),
      ],
    ),
  );
}
