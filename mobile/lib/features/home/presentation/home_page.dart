import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/auth/auth_controller.dart';
import '../domain/home_data.dart';
import 'home_controller.dart';

/// หน้าหลัก = ห้องควบคุม
///
/// ตอบคำถามเดียว: "ตอนนี้มีอะไรต้องทำ"
/// เรียงตามความเร่งด่วนของสิ่งที่ผู้ใช้ต้องลงมือ ไม่ใช่ตามเวลา
/// กลุ่มไหนว่างให้ซ่อนทั้งกลุ่ม ไม่ต้องโชว์ empty state ย่อย
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.auth, required this.controller});

  final AuthController auth;
  final HomeController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([widget.auth, widget.controller]),
        builder: (context, _) {
          final account = widget.auth.account;
          final c = widget.controller;
          final data = c.data;

          return Scaffold(
            appBar: AppBar(
              title: Text('สวัสดี, ${account?.name.isEmpty ?? true ? 'คุณ' : account!.name}'),
              actions: [
                IconButton(
                  onPressed: () => context.push('/connections'),
                  icon: const Icon(Icons.link_rounded),
                  tooltip: 'เชื่อมต่อบัญชี',
                ),
                IconButton(
                  onPressed: widget.auth.busy ? null : widget.auth.signOut,
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'ออกจากระบบ',
                ),
              ],
            ),
            // ซ่อน FAB ตอนหน้าว่าง เพราะ empty state มีปุ่มเดียวกันอยู่แล้ว
            // ปุ่มซ้ำสองที่ทำให้ผู้ใช้ลังเลว่าต่างกันไหม
            floatingActionButton: (data?.isEmpty ?? true)
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => _create(context),
                    icon: const Icon(Icons.add),
                    label: const Text('สร้างคอนเทนต์'),
                  ),
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: c.load,
                child: _body(context, c, data),
              ),
            ),
          );
        },
      );

  Widget _body(BuildContext context, HomeController c, HomeData? data) {
    if (!c.loaded && c.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (c.error != null && !c.loaded) {
      return _ErrorView(message: c.error!, onRetry: c.load);
    }

    if (data == null || data.isEmpty) {
      return _EmptyState(onCreate: () => _create(context));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Spacing.md, Spacing.md, Spacing.md, Spacing.xl * 2),
      children: [
        if (c.error != null) ...[
          _InlineError(message: c.error!),
          const SizedBox(height: Spacing.md),
        ],

        // ต้องทำ — ขึ้นบนสุดเสมอ เพราะเป็นสิ่งเดียวที่รอผู้ใช้อยู่
        if (data.needAction.isNotEmpty)
          _Section(
            icon: Icons.warning_amber_rounded,
            color: context.t.warning,
            title: 'ต้องทำ',
            count: data.needAction.length,
            children: [
              for (final a in data.needAction)
                _ActionCard(item: a, onTap: () => _handle(context, a)),
            ],
          ),

        if (data.working.isNotEmpty)
          _Section(
            icon: Icons.hourglass_top_rounded,
            color: context.t.warning,
            title: 'กำลังทำงาน',
            count: data.working.length,
            children: [for (final j in data.working) _JobTile(job: j)],
          ),

        if (data.scheduled.isNotEmpty)
          _Section(
            icon: Icons.event_rounded,
            color: context.t.primary,
            title: 'ตั้งเวลาไว้',
            count: data.scheduled.length,
            children: [for (final j in data.scheduled) _JobTile(job: j)],
          ),

        if (data.publishedToday.isNotEmpty)
          _Section(
            icon: Icons.check_circle_rounded,
            color: context.t.success,
            title: 'โพสต์แล้ววันนี้',
            count: data.publishedToday.length,
            children: [for (final j in data.publishedToday) _JobTile(job: j)],
          ),
      ],
    );
  }

  void _handle(BuildContext context, ActionItem a) {
    if (a.kind == ActionKind.needsReauth) {
      context.push('/connections');
    }
  }

  /// กลับมาถึงหน้าหลักแล้วโหลดใหม่ เพราะอาจมีงานใหม่เพิ่มเข้ามา
  Future<void> _create(BuildContext context) async {
    await context.push('/create');
    if (context.mounted) await widget.controller.load();
  }
}

// ── ส่วนประกอบ ────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.color,
    required this.title,
    required this.count,
    required this.children,
  });

  final IconData icon;
  final Color color;
  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: Spacing.sm),
              Text('$title ($count)',
                  style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          ...children,
          const SizedBox(height: Spacing.lg),
        ],
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.item, required this.onTap});
  final ActionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: Spacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: context.t.error, size: 20),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      item.detail,
                      style: TextStyle(
                          color: context.t.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: Spacing.sm),
                    // ทุก error ต้องมีปุ่มให้กดต่อ ไม่ใช่ข้อความลอย ๆ
                    FilledButton(
                      onPressed: onTap,
                      child: Text(item.actionLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job});
  final PublishJob job;

  @override
  Widget build(BuildContext context) {
    final color = switch (job.status) {
      JobStatus.published => context.t.success,
      JobStatus.failed => context.t.error,
      _ when job.status.isWorking => context.t.warning,
      _ => context.t.primary,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: ListTile(
        leading: Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: Spacing.sm),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(job.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${_when(job.scheduledAt)} · ${job.status.label}',
          style: TextStyle(color: context.t.textSecondary, fontSize: 12),
        ),
        trailing: job.status.isWorking
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
    );
  }

  /// _when แสดงเวลาแบบที่คนอ่านเข้าใจทันที
  /// "วันนี้ 19:00" มีประโยชน์กว่า "2026-09-05T19:00:00Z"
  static String _when(DateTime t) {
    final now = DateTime.now();
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    final d = DateTime(t.year, t.month, t.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    return switch (d) {
      0 => 'วันนี้ $time',
      1 => 'พรุ่งนี้ $time',
      -1 => 'เมื่อวาน $time',
      _ => '${t.day} ${_month(t.month)} $time',
    };
  }

  static String _month(int m) => const [
        'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
        'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
      ][m - 1];
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => ListView(
        // ต้องเป็น scrollable เพื่อให้ pull-to-refresh ยังใช้ได้ตอนว่าง
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                children: [
                  // ใช้ไอคอนแทนอิโมจิ — ฟอนต์ไทยไม่มี glyph อิโมจิ
                  // การพึ่งฟอนต์อิโมจิของระบบทำให้บางเครื่องขึ้นเป็นกล่องสี่เหลี่ยม
                  Icon(Icons.video_library_outlined,
                      size: 44, color: context.t.textSecondary),
                  const SizedBox(height: Spacing.md),
                  Text('ยังไม่มีคอนเทนต์เลย',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'เริ่มจากเลือกวิดีโอแรกของคุณ\n'
                    'แล้วระบบจะจัดการที่เหลือให้',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.t.textSecondary),
                  ),
                  const SizedBox(height: Spacing.lg),
                  FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('สร้างคอนเทนต์'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                children: [
                  Icon(Icons.cloud_off_rounded,
                      size: 40, color: context.t.textSecondary),
                  const SizedBox(height: Spacing.md),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: Spacing.lg),
                  FilledButton(onPressed: onRetry, child: const Text('ลองใหม่')),
                ],
              ),
            ),
          ),
        ],
      );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color: context.t.error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: context.t.error),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(message,
                  style: TextStyle(color: context.t.error, fontSize: 13)),
            ),
          ],
        ),
      );
}
