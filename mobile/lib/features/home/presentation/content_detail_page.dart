import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../create/domain/remix.dart';
import '../../create/presentation/publish_review_page.dart';
import '../../showcase/domain/showcase_product.dart';
import '../domain/content_store.dart';
import '../domain/home_data.dart';
import 'content_artwork.dart';

/// fixture ตั้งต้นของหน้าคอนเทนต์ — ตอนนี้เป็นของ [ContentStore]
/// ยังเปิด getter ไว้ให้โค้ดเก่าที่อ้างถึง demo job ตามชื่อ
List<PublishJob> get demoContentJobs => ContentStore.seedJobs();

class ContentDetailPage extends StatefulWidget {
  const ContentDetailPage({
    super.key,
    required this.job,
    this.store,
    this.onRetryRemote,
    this.onCancelRemote,
    this.onRescheduleRemote,
    this.onRestoreRemote,
  });
  final PublishJob job;

  /// เมื่อส่งเข้ามา การเปลี่ยนเวลา/ยกเลิก/นำกลับ จะเขียนกลับไปที่แหล่งข้อมูลกลาง
  /// รายการในแท็บคอนเทนต์จึงอัปเดตตาม
  final ContentStore? store;

  /// Live routes provide these callbacks; demo routes keep instant local UX.
  final Future<void> Function(String jobId)? onRetryRemote;
  final Future<void> Function(String jobId)? onCancelRemote;
  final Future<void> Function(String jobId, DateTime scheduledAt)?
  onRescheduleRemote;
  final Future<void> Function(String jobId)? onRestoreRemote;

  @override
  State<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends State<ContentDetailPage> {
  late JobStatus status = _current.status;
  late DateTime scheduledAt = _current.scheduledAt;

  PublishJob get _current => widget.store?.byId(widget.job.id) ?? widget.job;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดคอนเทนต์'),
        actions: [
          IconButton.outlined(
            tooltip: 'ตัวเลือกเพิ่มเติม',
            style: IconButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: .32)),
              backgroundColor: color.withValues(alpha: .07),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              _actions(context);
            },
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
                  _updatedText(status, scheduledAt),
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
            else if (status == JobStatus.cancelled)
              _CancelledCard(onRestore: _restoreSchedule)
            else
              _ProgressTimeline(status: status),
            const SizedBox(height: Spacing.lg),
            _CommerceCard(status: status),
            const SizedBox(height: Spacing.lg),
            _ScheduleCard(scheduledAt: scheduledAt, status: status),
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
    JobStatus.draft => _DetailActionButton(
      kind: _DetailActionKind.draft,
      onPressed: () => context.go('/create'),
      icon: const Icon(Icons.edit_outlined),
      label: 'ทำฉบับร่างต่อ',
    ),
    JobStatus.failed => _DetailActionButton(
      key: const Key('retry-job'),
      kind: _DetailActionKind.retry,
      onPressed: _retry,
      icon: const Icon(Icons.refresh_rounded),
      label: 'แก้แล้วลองส่งใหม่',
    ),
    JobStatus.scheduled => _DetailActionButton(
      key: const Key('reschedule-job'),
      kind: _DetailActionKind.schedule,
      onPressed: _reschedule,
      icon: const Icon(Icons.edit_calendar_outlined),
      label: 'เปลี่ยนเวลาเผยแพร่',
    ),
    JobStatus.cancelled => _DetailActionButton(
      kind: _DetailActionKind.restore,
      onPressed: _restoreSchedule,
      icon: const Icon(Icons.restore_rounded),
      label: 'นำกลับมาตั้งเวลา',
    ),
    JobStatus.published => _DetailActionButton(
      kind: _DetailActionKind.open,
      onPressed: () => _toast('เปิดลิงก์ผลงานตัวอย่างแล้ว'),
      icon: const Icon(Icons.open_in_new_rounded),
      label: 'เปิดผลงานบน TikTok',
    ),
    _ => _DetailActionButton(
      kind: _DetailActionKind.notify,
      onPressed: () => context.go('/content'),
      icon: const Icon(Icons.notifications_active_outlined),
      label: 'แจ้งเตือนเมื่อเสร็จ',
    ),
  };

  Future<void> _retry() async {
    final previous = _current;
    widget.store?.retry(widget.job.id);
    setState(() => status = JobStatus.queued);
    final remote = widget.onRetryRemote;
    if (remote != null) {
      try {
        await remote(widget.job.id);
      } catch (_) {
        if (!mounted) return;
        widget.store?.replace(previous);
        setState(() => status = previous.status);
        _toast('ลองใหม่ไม่สำเร็จ ข้อมูลถูกคืนกลับแล้ว');
        return;
      }
    }
    _toast('เพิ่มงานกลับเข้าคิวแล้ว คุณออกจากหน้านี้ได้');
  }

  Future<void> _reschedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(scheduledAt),
    );
    if (time == null || !mounted) return;
    final next = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final previous = _current;
    widget.store?.reschedule(widget.job.id, next);
    setState(() {
      scheduledAt = next;
      status = JobStatus.scheduled;
    });
    final remote = widget.onRescheduleRemote;
    if (remote != null) {
      try {
        await remote(widget.job.id, next);
      } catch (_) {
        if (!mounted) return;
        widget.store?.replace(previous);
        setState(() {
          scheduledAt = previous.scheduledAt;
          status = previous.status;
        });
        _toast('เปลี่ยนเวลาไม่สำเร็จ ข้อมูลถูกคืนกลับแล้ว');
        return;
      }
    }
    _toast('เปลี่ยนเวลาเผยแพร่แล้ว');
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.event_busy_outlined, color: context.t.warning),
        title: const Text('ยกเลิกการเผยแพร่?'),
        content: const Text(
          'งานนี้จะไม่ถูกส่งตามเวลาที่ตั้งไว้ คุณสามารถนำกลับมาตั้งเวลาใหม่ได้ภายหลัง',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('เก็บเวลาเดิม'),
          ),
          FilledButton(
            key: const Key('confirm-cancel-job'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยกเลิกการเผยแพร่'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final previous = _current;
      widget.store?.cancel(widget.job.id);
      setState(() => status = JobStatus.cancelled);
      final remote = widget.onCancelRemote;
      if (remote != null) {
        try {
          await remote(widget.job.id);
        } catch (_) {
          if (!mounted) return;
          widget.store?.replace(previous);
          setState(() => status = previous.status);
          _toast('ยกเลิกไม่สำเร็จ ข้อมูลถูกคืนกลับแล้ว');
          return;
        }
      }
      _toast('ยกเลิกการเผยแพร่แล้ว');
    }
  }

  Future<void> _restoreSchedule() async {
    final previous = _current;
    widget.store?.restore(widget.job.id);
    setState(() => status = JobStatus.scheduled);
    final remote = widget.onRestoreRemote;
    if (remote != null) {
      try {
        await remote(widget.job.id);
      } catch (_) {
        if (!mounted) return;
        widget.store?.replace(previous);
        setState(() => status = previous.status);
        _toast('นำงานกลับมาไม่สำเร็จ ข้อมูลถูกคืนกลับแล้ว');
        return;
      }
    }
    _toast('นำงานกลับมาตั้งเวลาแล้ว');
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  ShowcaseProduct? get _remixProduct {
    final id = widget.job.productId;
    for (final product in ShowcaseProduct.available) {
      if (product.id == id) return product;
    }
    return null;
  }

  void _openRemix(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(Spacing.lg, 4, Spacing.lg, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ทำเวอร์ชันใหม่จากคลิปนี้',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          for (final kind in RemixKind.values)
            ListTile(
              leading: Icon(_remixIcon(kind)),
              title: Text(RemixPreset.of(kind, widget.job).label),
              onTap: () {
                Navigator.pop(context);
                _startRemix(kind);
              },
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  IconData _remixIcon(RemixKind kind) => switch (kind) {
    RemixKind.newHook => Icons.bolt_rounded,
    RemixKind.newCta => Icons.campaign_outlined,
    RemixKind.short15 => Icons.timer_outlined,
    RemixKind.newProduct => Icons.swap_horiz_rounded,
    RemixKind.newCaption => Icons.edit_note_rounded,
  };

  void _startRemix(RemixKind kind) {
    final preset = RemixPreset.of(kind, widget.job);
    if (preset.needsProductPick) {
      _toast('เลือกสินค้าใหม่สำหรับเวอร์ชันรีมิกซ์');
      context.go('/showcase');
      return;
    }
    final product = _remixProduct;
    if (product == null) {
      _toast('เลือกสินค้าจริงก่อนสร้างเวอร์ชันรีมิกซ์');
      context.go('/showcase');
      return;
    }
    context.go(
      '/create/publish',
      extra: PublishReviewArgs(
        product: product,
        caption: preset.seedCaption,
        durationSec: preset.durationSec,
        sourceLabel: 'รีมิกซ์ · ${preset.label}',
        remixOfId: widget.job.id,
        remixNote: preset.note,
      ),
    );
  }

  void _actions(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.md,
          2,
          Spacing.md,
          Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _statusColor(context, status).withValues(alpha: .1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: _statusColor(context, status),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'จัดการคอนเทนต์',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        status.label,
                        style: TextStyle(
                          color: _statusColor(context, status),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            if (status == JobStatus.scheduled) ...[
              _DetailMenuTile(
                icon: Icons.edit_calendar_outlined,
                label: 'เปลี่ยนเวลาเผยแพร่',
                color: context.t.warning,
                prominent: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _reschedule();
                },
              ),
              const SizedBox(height: 8),
              _DetailMenuTile(
                key: const Key('cancel-scheduled-job'),
                icon: Icons.event_busy_outlined,
                label: 'ยกเลิกการเผยแพร่',
                color: context.t.warning,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmCancel();
                },
              ),
              const SizedBox(height: 8),
            ],
            _DetailMenuTile(
              key: const Key('remix-job'),
              icon: Icons.auto_awesome_motion_outlined,
              label: 'ทำเวอร์ชันใหม่',
              detail: 'รีมิกซ์จากคลิปนี้',
              color: context.t.creative,
              prominent: status != JobStatus.scheduled,
              onTap: () {
                Navigator.pop(sheetContext);
                _openRemix(context);
              },
            ),
            const SizedBox(height: 8),
            _DetailMenuTile(
              icon: Icons.download_outlined,
              label: 'บันทึกวิดีโอ',
              color: context.t.primary,
              onTap: () {
                Navigator.pop(sheetContext);
                _toast('เตรียมไฟล์ตัวอย่างแล้ว');
              },
            ),
            const SizedBox(height: 8),
            _DetailMenuTile(
              icon: Icons.delete_outline,
              label: 'ลบออกจากรายการ',
              color: context.t.error,
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailMenuTile extends StatelessWidget {
  const _DetailMenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.detail,
    this.prominent = false,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final Color color;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Material(
    color: prominent ? color.withValues(alpha: .1) : context.t.surfaceContainer,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      side: BorderSide(
        color: prominent ? color.withValues(alpha: .34) : context.t.border,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color == context.t.error ? color : null,
                      fontWeight: prominent ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      style: TextStyle(
                        color: context.t.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: color, size: 18),
          ],
        ),
      ),
    ),
  );
}

enum _DetailActionKind { draft, retry, schedule, restore, open, notify }

/// ปุ่มหลักของหน้ารายละเอียดใช้ interaction mechanics ร่วมกัน แต่ visual
/// signature เปลี่ยนตาม lifecycle เพื่อไม่ให้ “ลองใหม่” ดูเหมือน “เผยแพร่สำเร็จ”
class _DetailActionButton extends StatefulWidget {
  const _DetailActionButton({
    super.key,
    required this.kind,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final _DetailActionKind kind;
  final VoidCallback onPressed;
  final Widget icon;
  final String label;

  @override
  State<_DetailActionButton> createState() => _DetailActionButtonState();
}

class _DetailActionButtonState extends State<_DetailActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final accent = switch (widget.kind) {
      _DetailActionKind.draft => t.creative,
      _DetailActionKind.retry => t.error,
      _DetailActionKind.schedule => t.warning,
      _DetailActionKind.restore => t.primary,
      _DetailActionKind.open => t.success,
      _DetailActionKind.notify => t.primary,
    };
    final solid =
        widget.kind == _DetailActionKind.draft ||
        widget.kind == _DetailActionKind.open;
    final darkFill =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark;
    final solidForeground = darkFill
        ? (Theme.of(context).brightness == Brightness.dark
              ? t.textPrimary
              : t.surfaceContainer)
        : (Theme.of(context).brightness == Brightness.dark
              ? t.surface
              : t.textPrimary);
    final foreground = solid ? solidForeground : accent;
    final reduced = MediaQuery.of(context).disableAnimations;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, reveal, child) => Transform.translate(
        offset: Offset(0, 5 * (1 - reveal)),
        child: Opacity(opacity: reveal, child: child),
      ),
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? .97 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 56,
            decoration: BoxDecoration(
              color: solid ? null : accent.withValues(alpha: .1),
              gradient: solid
                  ? LinearGradient(
                      colors: [accent, Color.lerp(accent, t.primary, .2)!],
                    )
                  : null,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: solid
                    ? accent.withValues(alpha: 0)
                    : accent.withValues(alpha: .42),
              ),
              boxShadow: _pressed
                  ? null
                  : [
                      BoxShadow(
                        color: accent.withValues(alpha: solid ? .18 : .08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  right: 11,
                  top: 0,
                  bottom: 0,
                  child: _DetailActionSignature(
                    kind: widget.kind,
                    color: foreground,
                    pressed: _pressed,
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent.withValues(alpha: 0),
                    foregroundColor: foreground,
                    shadowColor: accent.withValues(alpha: 0),
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onPressed();
                  },
                  icon: AnimatedRotation(
                    turns:
                        _pressed &&
                            (widget.kind == _DetailActionKind.retry ||
                                widget.kind == _DetailActionKind.restore)
                        ? -.12
                        : 0,
                    duration: const Duration(milliseconds: 140),
                    child: widget.icon,
                  ),
                  label: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailActionSignature extends StatelessWidget {
  const _DetailActionSignature({
    required this.kind,
    required this.color,
    required this.pressed,
  });

  final _DetailActionKind kind;
  final Color color;
  final bool pressed;

  IconData get _icon => switch (kind) {
    _DetailActionKind.draft => Icons.edit_note_rounded,
    _DetailActionKind.retry => Icons.replay_circle_filled_outlined,
    _DetailActionKind.schedule => Icons.schedule_rounded,
    _DetailActionKind.restore => Icons.history_rounded,
    _DetailActionKind.open => Icons.arrow_forward_rounded,
    _DetailActionKind.notify => Icons.graphic_eq_rounded,
  };

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: pressed ? .86 : 1,
    duration: const Duration(milliseconds: 130),
    child: SizedBox(
      width: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (kind == _DetailActionKind.open)
            for (var i = 0; i < 3; i++)
              Positioned(
                right: 7.0 + (i * 8),
                child: Container(
                  width: 13.0 - (i * 2),
                  height: 2,
                  color: color.withValues(alpha: .09 + (i * .05)),
                ),
              )
          else if (kind == _DetailActionKind.schedule)
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: .18),
                  width: 2,
                ),
              ),
            )
          else if (kind == _DetailActionKind.retry)
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: .17)),
              ),
            ),
          Icon(_icon, size: 24, color: color.withValues(alpha: .24)),
        ],
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
  const _ScheduleCard({required this.scheduledAt, required this.status});
  final DateTime scheduledAt;
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
              Text(_format(scheduledAt), style: const TextStyle(fontSize: 11)),
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

class _CancelledCard extends StatelessWidget {
  const _CancelledCard({required this.onRestore});
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      children: [
        Icon(Icons.event_busy_outlined, color: context.t.warning),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ยกเลิกการเผยแพร่แล้ว',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                'งานยังอยู่ในคลังและนำกลับมาตั้งเวลาได้',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onRestore, child: const Text('นำกลับ')),
      ],
    ),
  );
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

String _updatedText(JobStatus status, DateTime scheduledAt) => switch (status) {
  JobStatus.processing ||
  JobStatus.uploading ||
  JobStatus.queued => 'อัปเดตเมื่อครู่',
  JobStatus.failed => 'พบปัญหา 12 นาทีที่แล้ว',
  JobStatus.published => 'เผยแพร่วันนี้',
  JobStatus.scheduled => _ScheduleCard._format(scheduledAt),
  JobStatus.cancelled => 'ยกเลิกโดยคุณ',
  _ => 'แก้ไขล่าสุดวันนี้',
};
