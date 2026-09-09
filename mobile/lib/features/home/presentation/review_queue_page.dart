import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../showcase/domain/showcase_product.dart';
import '../../showcase/presentation/product_artwork.dart';
import '../domain/content_store.dart';
import '../domain/home_data.dart';

/// คิวตรวจงานแบบปัด — ปัดขวาอนุมัติ ปัดซ้ายส่งกลับแก้ ปุ่มพักไว้
///
/// ทุกการกระทำมี "เลิกทำ" ทันทีใน SnackBar ลดความรู้สึกว่าเป็นแบบฟอร์ม
class ReviewQueuePage extends StatefulWidget {
  const ReviewQueuePage({super.key, required this.store});
  final ContentStore store;

  @override
  State<ReviewQueuePage> createState() => _ReviewQueuePageState();
}

class _ReviewQueuePageState extends State<ReviewQueuePage> {
  void _act(PublishJob job, String verb, void Function() apply) {
    apply();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$verb: ${job.title}'),
          action: SnackBarAction(
            label: 'เลิกทำ',
            onPressed: () => widget.store.updateStatus(
              job.id,
              JobStatus.awaitingReview,
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final queue = widget.store.reviewQueue;
      return Scaffold(
        appBar: AppBar(title: const Text('ตรวจงานร่าง')),
        body: SafeArea(
          child: queue.isEmpty
              ? _Done(onBack: () => context.go('/'))
              : Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Column(
                    children: [
                      Text(
                        'เหลือ ${queue.length} งานรอตรวจ',
                        style: TextStyle(
                          color: context.t.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                      Expanded(
                        child: _ReviewCard(
                          key: ValueKey(queue.first.id),
                          job: queue.first,
                          onApprove: () => _act(
                            queue.first,
                            'อนุมัติแล้ว',
                            () => widget.store.approveReview(queue.first.id),
                          ),
                          onSendBack: () => _act(
                            queue.first,
                            'ส่งกลับไปแก้',
                            () =>
                                widget.store.sendBackToDraft(queue.first.id),
                          ),
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                      TextButton.icon(
                        onPressed: () => _act(
                          queue.first,
                          'พักไว้ก่อน',
                          () => widget.store.cancel(queue.first.id),
                        ),
                        icon: const Icon(Icons.snooze_rounded),
                        label: const Text('พักงานนี้ไว้ก่อน'),
                      ),
                      Text(
                        'ปัดขวา = อนุมัติ · ปัดซ้าย = ส่งกลับแก้',
                        style: TextStyle(
                          color: context.t.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    },
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    super.key,
    required this.job,
    required this.onApprove,
    required this.onSendBack,
  });
  final PublishJob job;
  final VoidCallback onApprove;
  final VoidCallback onSendBack;

  ShowcaseProduct? get _product {
    for (final p in ShowcaseProduct.mock) {
      if (p.id == job.productId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    return Dismissible(
      key: ValueKey('review-${job.id}'),
      background: _swipeBg(
        context,
        Alignment.centerLeft,
        Icons.check_circle_rounded,
        'อนุมัติ',
        context.t.success,
      ),
      secondaryBackground: _swipeBg(
        context,
        Alignment.centerRight,
        Icons.undo_rounded,
        'ส่งกลับแก้',
        context.t.warning,
      ),
      onDismissed: (dir) => dir == DismissDirection.startToEnd
          ? onApprove()
          : onSendBack(),
      child: Container(
        decoration: BoxDecoration(
          color: context.t.surfaceContainer,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: context.t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product != null)
              SizedBox(
                height: 190,
                width: double.infinity,
                child: ProductArtwork(product: product, borderRadius: 0),
              ),
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.sourceLabel.isEmpty
                        ? 'รอตรวจ'
                        : job.sourceLabel,
                    style: TextStyle(
                      color: context.t.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    job.caption.isEmpty ? 'ไม่มีคำบรรยาย' : job.caption,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: context.t.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'เสนอ ${job.scheduledAt.day}/${job.scheduledAt.month} '
                        '${job.scheduledAt.hour.toString().padLeft(2, '0')}:'
                        '${job.scheduledAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: context.t.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('review-send-back'),
                          onPressed: onSendBack,
                          icon: const Icon(Icons.undo_rounded, size: 18),
                          label: const Text('ส่งกลับแก้'),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('review-approve'),
                          onPressed: onApprove,
                          icon: const Icon(
                            Icons.check_rounded,
                            size: 18,
                          ),
                          label: const Text('อนุมัติ'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swipeBg(
    BuildContext context,
    Alignment align,
    IconData icon,
    String label,
    Color color,
  ) => Container(
    color: color.withValues(alpha: .18),
    alignment: align,
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _Done extends StatelessWidget {
  const _Done({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.task_alt_rounded, size: 64, color: context.t.success),
        const SizedBox(height: Spacing.md),
        Text(
          'ตรวจครบแล้ว',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'ไม่มีงานรอตรวจในคิว',
          style: TextStyle(color: context.t.textSecondary),
        ),
        const SizedBox(height: Spacing.lg),
        FilledButton(onPressed: onBack, child: const Text('กลับหน้าหลัก')),
      ],
    ),
  );
}
