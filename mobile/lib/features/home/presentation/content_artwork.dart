import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../showcase/domain/showcase_product.dart';
import '../../showcase/presentation/product_artwork.dart';
import '../domain/home_data.dart';

class ContentArtwork extends StatelessWidget {
  const ContentArtwork({
    super.key,
    required this.job,
    required this.status,
    required this.width,
    required this.height,
    this.compact = false,
  });

  final PublishJob job;
  final JobStatus status;
  final double width;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = contentStatusColor(context, status);
    return Hero(
      tag: 'content-${job.id}',
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 12 : 22),
          border: Border.all(color: color.withValues(alpha: .38)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ProductArtwork(
              product: productForJob(job),
              borderRadius: compact ? 11 : 21,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC00101E)],
                  stops: [.38, 1],
                ),
              ),
            ),
            Center(
              child: Container(
                width: compact ? 28 : 48,
                height: compact ? 28 : 48,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .52),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  status == JobStatus.failed
                      ? Icons.error_outline_rounded
                      : status == JobStatus.published
                      ? Icons.play_arrow_rounded
                      : Icons.movie_filter_outlined,
                  size: compact ? 17 : 28,
                  color: status == JobStatus.failed ? color : Colors.white,
                ),
              ),
            ),
            Positioned(
              left: compact ? 5 : 10,
              right: compact ? 5 : 10,
              bottom: compact ? 5 : 10,
              child: Row(
                children: [
                  Container(
                    width: compact ? 6 : 8,
                    height: compact ? 6 : 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      compact ? _shortStatus(status) : 'วิดีโอตัวอย่าง · 00:30',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 8 : 11,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(blurRadius: 5, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ShowcaseProduct productForJob(PublishJob job) {
  final available = ShowcaseProduct.available;
  if (available.isEmpty) return ShowcaseProduct.placeholder;
  final title = job.title.toLowerCase();
  if (title.contains('ไมโครโฟน') || title.contains('creator')) {
    return available[1];
  }
  if (title.contains('แก้ว') || title.contains('ความเย็น')) {
    return available[2];
  }
  return available.first;
}

Color contentStatusColor(BuildContext context, JobStatus status) =>
    switch (status) {
      JobStatus.failed => context.t.error,
      JobStatus.published => context.t.success,
      JobStatus.scheduled => const Color(0xFFA78BFA),
      JobStatus.draft => context.t.textSecondary,
      _ => context.t.primary,
    };

String _shortStatus(JobStatus status) => switch (status) {
  JobStatus.processing => 'กำลังสร้าง',
  JobStatus.scheduled => 'ตั้งเวลา',
  JobStatus.published => 'โพสต์แล้ว',
  JobStatus.failed => 'ต้องแก้',
  JobStatus.draft => 'ฉบับร่าง',
  _ => status.label,
};
