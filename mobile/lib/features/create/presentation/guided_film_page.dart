import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../showcase/domain/showcase_product.dart';
import '../../showcase/presentation/product_artwork.dart';
import 'publish_review_page.dart';

class GuidedFilmPage extends StatefulWidget {
  const GuidedFilmPage({super.key, required this.product});

  final ShowcaseProduct product;

  @override
  State<GuidedFilmPage> createState() => _GuidedFilmPageState();
}

class _GuidedFilmPageState extends State<GuidedFilmPage> {
  int shot = 0;
  final takeCounts = <int>[0, 0, 0];
  final selectedTakes = <int>[0, 0, 0];

  int get takeCount => takeCounts[shot];
  int get selectedTake => selectedTakes[shot];

  static const shots = [
    (
      'เปิดเรื่องให้หยุดดู',
      'ถือสินค้าใกล้กล้อง แล้วพูดปัญหาที่คนดูเจอ',
      '4–6 วิ',
    ),
    (
      'โชว์สินค้าและวิธีใช้',
      'ถ่ายรายละเอียดสินค้า พร้อมสาธิตจุดขายหลัก',
      '10–15 วิ',
    ),
    (
      'ผลลัพธ์และชวนกดตะกร้า',
      'สรุปประโยชน์ แล้วชี้ตำแหน่งตะกร้าสินค้า',
      '5–8 วิ',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('ถ่ายคลิปแบบมีไกด์'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(3),
        child: LinearProgressIndicator(value: (shot + 1) / shots.length),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Spacing.md, 12, Spacing.md, 120),
        children: [
          _Product(product: widget.product),
          const SizedBox(height: Spacing.lg),
          Text(
            'ช็อต ${shot + 1} จาก ${shots.length}',
            style: TextStyle(
              color: context.t.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            shots[shot].$1,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 5),
          Text(
            shots[shot].$2,
            style: TextStyle(color: context.t.textSecondary, height: 1.5),
          ),
          const SizedBox(height: Spacing.lg),
          _CameraStage(
            shot: shot,
            duration: shots[shot].$3,
            takeCount: takeCount,
            onRecord: () => setState(() {
              takeCounts[shot]++;
              selectedTakes[shot] = takeCounts[shot];
            }),
          ),
          if (takeCount > 0) ...[
            const SizedBox(height: Spacing.lg),
            const Text(
              'เทคของช็อตนี้',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 1; index <= takeCount; index++)
                  ChoiceChip(
                    avatar: const Icon(Icons.play_arrow_rounded, size: 17),
                    label: Text('เทค $index'),
                    selected: selectedTake == index,
                    onSelected: (_) =>
                        setState(() => selectedTakes[shot] = index),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('delete-guided-take'),
                onPressed: _deleteSelectedTake,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text('ลบเทค $selectedTake'),
              ),
            ),
          ],
          const SizedBox(height: Spacing.lg),
          const _CoachTips(),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Spacing.md, 9, Spacing.md, 12),
        decoration: BoxDecoration(
          color: context.t.surface,
          border: Border(top: BorderSide(color: context.t.border)),
        ),
        child: Row(
          children: [
            if (shot > 0)
              IconButton.outlined(
                tooltip: 'ช็อตก่อนหน้า',
                onPressed: () => setState(() => shot--),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            if (shot > 0) const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const Key('guided-next'),
                onPressed: selectedTake == 0 ? null : _next,
                icon: Icon(
                  shot == shots.length - 1
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  shot == shots.length - 1
                      ? 'รวมคลิปและตรวจตะกร้า'
                      : 'ใช้เทคนี้ ไปช็อตถัดไป',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _next() {
    if (shot < shots.length - 1) {
      setState(() => shot++);
      return;
    }
    context.go(
      '/create/publish',
      extra: PublishReviewArgs(
        product: widget.product,
        sourceLabel: 'ถ่ายด้วย Guided Camera',
        mediaName: 'รีวิว ${widget.product.name}',
        durationSec: 28,
        caption:
            '${widget.product.name} ใช้แล้วเป็นยังไง มาดูกัน ✨ ดูรายละเอียดและโปรได้ที่ตะกร้า',
      ),
    );
  }

  Future<void> _deleteSelectedTake() async {
    final target = selectedTake;
    if (target == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: context.t.warning),
        title: Text('ลบเทค $target?'),
        content: const Text(
          'เทคนี้จะถูกนำออกจากช็อต คุณยังอัดใหม่ได้ก่อนดำเนินการต่อ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('เก็บไว้'),
          ),
          FilledButton(
            key: const Key('confirm-delete-guided-take'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบเทค'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      takeCounts[shot]--;
      selectedTakes[shot] = takeCounts[shot];
    });
  }
}

class _Product extends StatelessWidget {
  const _Product({required this.product});
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
        ProductArtwork(product: product, width: 42, height: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '฿${product.commissionBaht}/ชิ้น',
          style: TextStyle(color: context.t.success, fontSize: 12),
        ),
      ],
    ),
  );
}

class _CameraStage extends StatelessWidget {
  const _CameraStage({
    required this.shot,
    required this.duration,
    required this.takeCount,
    required this.onRecord,
  });

  final int shot;
  final String duration;
  final int takeCount;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 9 / 13,
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.t.surfaceElevated, context.t.surfaceContainer],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: context.t.primary.withValues(alpha: .3)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GuidePainter(
                color: context.t.primary.withValues(alpha: .32),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Row(
              children: [
                const _Pill(icon: Icons.hd_rounded, label: '1080P'),
                const Spacer(),
                _Pill(icon: Icons.timer_outlined, label: duration),
              ],
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  shot == 0
                      ? Icons.face_retouching_natural
                      : shot == 1
                      ? Icons.inventory_2_outlined
                      : Icons.shopping_bag_outlined,
                  size: 56,
                  color: context.t.textSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  'วางให้อยู่ในกรอบ',
                  style: TextStyle(color: context.t.textSecondary),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: Center(
              child: GestureDetector(
                key: const Key('guided-record'),
                onTap: onRecord,
                child: Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: takeCount == 0
                          ? context.t.creative
                          : context.t.success,
                    ),
                    child: Icon(
                      takeCount == 0
                          ? Icons.fiber_manual_record
                          : Icons.replay_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}

class _CoachTips extends StatelessWidget {
  const _CoachTips();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.t.primary.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(Radii.md),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.auto_awesome_outlined, size: 19),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'โค้ช: หันหน้าเข้าหาแสง เว้นพื้นที่ด้านล่างไว้ให้ชื่อสินค้า และพูดให้จบในหนึ่งประโยค',
            style: TextStyle(fontSize: 12, height: 1.45),
          ),
        ),
      ],
    ),
  );
}

class _GuidePainter extends CustomPainter {
  const _GuidePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GuidePainter oldDelegate) =>
      oldDelegate.color != color;
}
