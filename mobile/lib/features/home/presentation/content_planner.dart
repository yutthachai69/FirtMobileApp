import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../domain/home_data.dart';
import 'content_artwork.dart' show contentStatusColor;

/// มุมมองปฏิทินรายสัปดาห์ของแท็บคอนเทนต์ — ลากงานข้ามวันเพื่อเปลี่ยนเวลาโพสต์
///
/// เป็นอีกมุมมองของงานชุดเดียวกับมุมมองรายการ ไม่ใช่หน้าใหม่
/// วันที่ยังไม่มีงานตั้งเวลาไว้ จะโชว์ช่องว่างพร้อมเวลาที่แนะนำ
class ContentPlanner extends StatefulWidget {
  const ContentPlanner({
    super.key,
    required this.jobs,
    required this.onReschedule,
    required this.onOpen,
  });

  final List<PublishJob> jobs;
  final void Function(String jobId, DateTime newDate) onReschedule;
  final void Function(PublishJob job) onOpen;

  @override
  State<ContentPlanner> createState() => _ContentPlannerState();
}

class _ContentPlannerState extends State<ContentPlanner> {
  int _weekOffset = 0;

  static const _suggestedSlots = ['19:30', '12:00', '21:00', '20:00'];
  static const _weekdayLabels = [
    'จ.',
    'อ.',
    'พ.',
    'พฤ.',
    'ศ.',
    'ส.',
    'อา.',
  ];

  DateTime get _weekStart {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: 7 * _weekOffset));
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<PublishJob> _jobsOn(DateTime day) =>
      widget.jobs.where((j) => _sameDay(j.scheduledAt, day)).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  bool _movable(PublishJob j) =>
      j.status == JobStatus.scheduled ||
      j.status == JobStatus.draft ||
      j.status == JobStatus.queued;

  @override
  Widget build(BuildContext context) {
    final start = _weekStart;
    final end = start.add(const Duration(days: 6));

    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _weekOffset--),
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'สัปดาห์ก่อน',
            ),
            Expanded(
              child: Text(
                _weekOffset == 0
                    ? 'สัปดาห์นี้'
                    : '${start.day}/${start.month} – ${end.day}/${end.month}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _weekOffset++),
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: 'สัปดาห์ถัดไป',
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        for (var i = 0; i < 7; i++)
          _DaySection(
            day: start.add(Duration(days: i)),
            weekdayLabel: _weekdayLabels[i],
            jobs: _jobsOn(start.add(Duration(days: i))),
            suggestedSlot: _suggestedSlots[i % _suggestedSlots.length],
            isToday: _sameDay(start.add(Duration(days: i)), DateTime.now()),
            movable: _movable,
            onOpen: widget.onOpen,
            onDropped: (job, day) {
              final next = DateTime(
                day.year,
                day.month,
                day.day,
                job.scheduledAt.hour,
                job.scheduledAt.minute,
              );
              widget.onReschedule(job.id, next);
            },
          ),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.weekdayLabel,
    required this.jobs,
    required this.suggestedSlot,
    required this.isToday,
    required this.movable,
    required this.onOpen,
    required this.onDropped,
  });

  final DateTime day;
  final String weekdayLabel;
  final List<PublishJob> jobs;
  final String suggestedSlot;
  final bool isToday;
  final bool Function(PublishJob) movable;
  final void Function(PublishJob job) onOpen;
  final void Function(PublishJob job, DateTime day) onDropped;

  @override
  Widget build(BuildContext context) {
    final hasScheduled = jobs.any((j) => j.status == JobStatus.scheduled);

    return DragTarget<PublishJob>(
      onWillAcceptWithDetails: (d) => !_sameDay(d.data.scheduledAt, day),
      onAcceptWithDetails: (d) => onDropped(d.data, day),
      builder: (context, candidate, _) {
        final active = candidate.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: active
                ? context.t.primary.withValues(alpha: .12)
                : context.t.surfaceContainer,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(
              color: active
                  ? context.t.primary
                  : isToday
                  ? context.t.primary.withValues(alpha: .5)
                  : context.t.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$weekdayLabel ${day.day}/${day.month}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isToday ? context.t.primary : null,
                    ),
                  ),
                  const Spacer(),
                  if (jobs.isNotEmpty)
                    Text(
                      '${jobs.length} งาน',
                      style: TextStyle(
                        color: context.t.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (jobs.isEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 14,
                      color: context.t.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ว่าง · แนะนำ $suggestedSlot',
                      style: TextStyle(
                        color: context.t.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              else ...[
                for (final job in jobs)
                  _PlannerJob(
                    job: job,
                    draggable: movable(job),
                    onOpen: () => onOpen(job),
                  ),
                if (!hasScheduled)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'ยังไม่มีงานตั้งเวลา · แนะนำ $suggestedSlot',
                      style: TextStyle(
                        color: context.t.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _PlannerJob extends StatelessWidget {
  const _PlannerJob({
    required this.job,
    required this.draggable,
    required this.onOpen,
  });
  final PublishJob job;
  final bool draggable;
  final VoidCallback onOpen;

  String get _clock =>
      '${job.scheduledAt.hour.toString().padLeft(2, '0')}:'
      '${job.scheduledAt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final color = contentStatusColor(context, job.status);
    final row = InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: Text(
                _clock,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                job.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (draggable)
              Icon(
                Icons.drag_indicator_rounded,
                size: 16,
                color: context.t.textSecondary,
              ),
          ],
        ),
      ),
    );

    if (!draggable) return row;

    final feedback = Material(
      color: Colors.transparent,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.t.surfaceElevated,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: context.t.primary),
        ),
        child: Text(
          job.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );

    return LongPressDraggable<PublishJob>(
      data: job,
      feedback: feedback,
      childWhenDragging: Opacity(opacity: 0.35, child: row),
      child: row,
    );
  }
}
