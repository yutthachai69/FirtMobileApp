import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../domain/home_data.dart';
import 'content_artwork.dart';

final demoContentJobs = <PublishJob>[
  PublishJob(
    id: 'demo-draft',
    contentId: 'content-draft',
    platform: 'tiktok',
    status: JobStatus.draft,
    scheduledAt: DateTime(2026, 9, 8, 11, 30),
    caption: 'รีวิวเซรั่มวิตามินซี ฉบับร่างจาก AI Content Inbox',
  ),
  PublishJob(
    id: 'demo-processing',
    contentId: 'content-processing',
    platform: 'tiktok',
    status: JobStatus.processing,
    scheduledAt: DateTime(2026, 9, 8, 14, 10),
    caption: 'คลิปแกะกล่องไมโครโฟนไร้สายสำหรับ Creator',
  ),
  PublishJob(
    id: 'demo-scheduled',
    contentId: 'content-scheduled',
    platform: 'tiktok',
    status: JobStatus.scheduled,
    scheduledAt: DateTime(2026, 9, 9, 19, 30),
    caption: 'ป้ายยาแก้วเก็บความเย็น พร้อมโปรประจำสัปดาห์',
  ),
  PublishJob(
    id: 'demo-published',
    contentId: 'content-published',
    platform: 'tiktok',
    status: JobStatus.published,
    scheduledAt: DateTime(2026, 9, 8, 9, 15),
    caption: '3 เหตุผลที่ควรลองเซรั่มตัวนี้ก่อนโปรหมด',
    permalink: 'https://www.tiktok.com/',
  ),
  PublishJob(
    id: 'demo-failed',
    contentId: 'content-failed',
    platform: 'tiktok',
    status: JobStatus.failed,
    scheduledAt: DateTime(2026, 9, 8, 8, 40),
    caption: 'คลิปรีวิวสินค้าเวอร์ชัน Hook เร็ว',
    errorMessage: 'สินค้าที่ผูกไว้หมดสต็อกก่อนถึงเวลาเผยแพร่',
  ),
];

class ContentDetailPage extends StatefulWidget {
  const ContentDetailPage({super.key, required this.job});
  final PublishJob job;

  @override
  State<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends State<ContentDetailPage> {
  late JobStatus status = widget.job.status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดคอนเทนต์'),
        actions: [
          IconButton(
            tooltip: 'ตัวเลือกเพิ่มเติม',
            onPressed: () => _actions(context),
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Spacing.md, 4, Spacing.md, 110),
          children: [
            Row(
              children: [
                _StatusPill(status: status, color: color),
                const Spacer(),
                Text(
                  _updatedText(status),
                  style: TextStyle(
                    color: context.t.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            _VideoHero(job: widget.job, status: status),
            const SizedBox(height: Spacing.md),
            Text(
              widget.job.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 5),
            Text(
              'TikTok Shop · AI Content Relay',
              style: TextStyle(color: context.t.textSecondary),
            ),
            const SizedBox(height: Spacing.lg),
            if (status == JobStatus.failed)
              _ProblemCard(
                message: widget.job.errorMessage.isEmpty
                    ? 'ส่งคอนเทนต์ไม่สำเร็จ กรุณาตรวจการเชื่อมต่อ'
                    : widget.job.errorMessage,
                onRetry: _retry,
                onReplace: () => context.go('/showcase'),
              )
            else if (status == JobStatus.published)
              const _PublishedMetrics()
            else
              _ProgressTimeline(status: status),
            const SizedBox(height: Spacing.lg),
            _CommerceCard(status: status),
            const SizedBox(height: Spacing.lg),
            _ScheduleCard(job: widget.job, status: status),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.md, 8, Spacing.md, 12),
          child: _primaryAction(context),
        ),
      ),
    );
  }

  Widget _primaryAction(BuildContext context) => switch (status) {
    JobStatus.draft => FilledButton.icon(
      onPressed: () => context.go('/create'),
      icon: const Icon(Icons.edit_outlined),
      label: const Text('ทำฉบับร่างต่อ'),
    ),
    JobStatus.failed => FilledButton.icon(
      key: const Key('retry-job'),
      onPressed: _retry,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('แก้แล้วลองส่งใหม่'),
    ),
    JobStatus.scheduled => OutlinedButton.icon(
      onPressed: () => _toast('เปิดตัวเลือกเปลี่ยนเวลาแล้ว'),
      icon: const Icon(Icons.edit_calendar_outlined),
      label: const Text('เปลี่ยนเวลาเผยแพร่'),
    ),
    JobStatus.published => FilledButton.icon(
      onPressed: () => _toast('เปิดลิงก์ผลงานตัวอย่างแล้ว'),
      icon: const Icon(Icons.open_in_new_rounded),
      label: const Text('เปิดผลงานบน TikTok'),
    ),
    _ => OutlinedButton.icon(
      onPressed: () => context.go('/content'),
      icon: const Icon(Icons.notifications_active_outlined),
      label: const Text('แจ้งเตือนเมื่อเสร็จ'),
    ),
  };

  void _retry() {
    setState(() => status = JobStatus.queued);
    _toast('เพิ่มงานกลับเข้าคิวแล้ว คุณออกจากหน้านี้ได้');
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _actions(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('สร้างสำเนา'),
              onTap: () {
                Navigator.pop(context);
                _toast('สร้างสำเนาฉบับร่างแล้ว');
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('บันทึกวิดีโอ'),
              onTap: () {
                Navigator.pop(context);
                _toast('เตรียมไฟล์ตัวอย่างแล้ว');
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.t.error),
              title: Text(
                'ลบออกจากรายการ',
                style: TextStyle(color: context.t.error),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}

class _VideoHero extends StatelessWidget {
  const _VideoHero({required this.job, required this.status});
  final PublishJob job;
  final JobStatus status;
  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 210,
      height: 300,
      child: Stack(
        children: [
          ContentArtwork(job: job, status: status, width: 210, height: 300),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                LinearProgressIndicator(
                  value: status.isWorking ? .72 : 1,
                  minHeight: 3,
                  color: _statusColor(context, status),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.color});
  final JobStatus status;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      status.label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _ProgressTimeline extends StatelessWidget {
  const _ProgressTimeline({required this.status});
  final JobStatus status;
  @override
  Widget build(BuildContext context) {
    final current = switch (status) {
      JobStatus.draft => 0,
      JobStatus.scheduled => 2,
      JobStatus.queued => 2,
      JobStatus.uploading => 3,
      JobStatus.processing => 4,
      _ => 1,
    };
    const steps = [
      'รับคอนเทนต์แล้ว',
      'ตรวจและอนุมัติ',
      'เข้าคิวเผยแพร่',
      'กำลังอัปโหลด',
      'รอแพลตฟอร์มประมวลผล',
    ];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ความคืบหน้า',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 11),
              child: Row(
                children: [
                  Icon(
                    i < current
                        ? Icons.check_circle
                        : i == current
                        ? Icons.radio_button_checked
                        : Icons.circle_outlined,
                    color: i <= current
                        ? context.t.primary
                        : context.t.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: i <= current
                            ? context.t.textPrimary
                            : context.t.textSecondary,
                      ),
                    ),
                  ),
                  if (i == current)
                    const Text('ตอนนี้', style: TextStyle(fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({
    required this.message,
    required this.onRetry,
    required this.onReplace,
  });
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onReplace;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Spacing.md),
    decoration: BoxDecoration(
      color: context.t.error.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: context.t.error.withValues(alpha: .3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: context.t.error),
            const SizedBox(width: 8),
            const Text(
              'ต้องแก้ก่อนส่งใหม่',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(fontSize: 12, height: 1.5)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onReplace,
                child: const Text('เปลี่ยนสินค้า'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: onRetry,
                child: const Text('ลองใหม่'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PublishedMetrics extends StatelessWidget {
  const _PublishedMetrics();
  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: const [
        _Metric('12.4K', 'ยอดดู'),
        _Metric('486', 'กดตะกร้า'),
        _Metric('38', 'ออเดอร์'),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      Text(
        label,
        style: TextStyle(color: context.t.textSecondary, fontSize: 10),
      ),
    ],
  );
}

class _CommerceCard extends StatelessWidget {
  const _CommerceCard({required this.status});
  final JobStatus status;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      children: [
        Icon(
          Icons.shopping_bag,
          color: status == JobStatus.failed
              ? context.t.warning
              : context.t.success,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ตะกร้าสินค้า',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                status == JobStatus.failed
                    ? 'สินค้าเดิมต้องตรวจใหม่'
                    : 'ตรวจสินค้าและสต็อกแล้ว',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        Text(
          status == JobStatus.failed ? 'ต้องแก้' : 'พร้อม',
          style: TextStyle(
            color: status == JobStatus.failed
                ? context.t.warning
                : context.t.success,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.job, required this.status});
  final PublishJob job;
  final JobStatus status;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      children: [
        const Icon(Icons.schedule_rounded),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'เวลาที่กำหนด',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                _format(job.scheduledAt),
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        Text(
          status == JobStatus.scheduled ? 'Asia/Bangkok' : 'อัปเดตล่าสุด',
          style: TextStyle(color: context.t.textSecondary, fontSize: 10),
        ),
      ],
    ),
  );
  static String _format(DateTime d) =>
      '${d.day}/${d.month}/${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Spacing.md),
    decoration: BoxDecoration(
      color: context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: context.t.border),
    ),
    child: child,
  );
}

Color _statusColor(BuildContext context, JobStatus status) =>
    contentStatusColor(context, status);

String _updatedText(JobStatus status) => switch (status) {
  JobStatus.processing ||
  JobStatus.uploading ||
  JobStatus.queued => 'อัปเดตเมื่อครู่',
  JobStatus.failed => 'พบปัญหา 12 นาทีที่แล้ว',
  JobStatus.published => 'เผยแพร่วันนี้',
  JobStatus.scheduled => 'พรุ่งนี้ 19:30',
  _ => 'แก้ไขล่าสุดวันนี้',
};
