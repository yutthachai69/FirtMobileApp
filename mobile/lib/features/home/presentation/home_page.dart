import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/auth/auth_controller.dart';
import '../domain/home_data.dart';
import 'home_controller.dart';

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
      final rawName = widget.auth.account?.name.trim();
      final name = rawName == null || rawName.isEmpty ? 'คุณ' : rawName;
      final c = widget.controller;
      final data = c.data;
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          titleSpacing: Spacing.md,
          title: _CreatorTitle(name: name),
          actions: [
            IconButton.filledTonal(
              onPressed: () => context.push('/connections'),
              icon: const Icon(Icons.notifications_none_rounded),
              tooltip: 'การเชื่อมต่อและการแจ้งเตือน',
            ),
            const SizedBox(width: Spacing.sm),
            IconButton(
              onPressed: widget.auth.busy ? null : widget.auth.signOut,
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'ออกจากระบบ',
            ),
            const SizedBox(width: Spacing.sm),
          ],
        ),
        bottomNavigationBar: _BottomNav(onCreate: () => _create(context)),
        body: SafeArea(
          top: false,
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
        Spacing.md,
        Spacing.sm,
        Spacing.md,
        Spacing.xl,
      ),
      children: [
        if (c.error != null) ...[
          _InlineError(message: c.error!),
          const SizedBox(height: Spacing.md),
        ],
        _Overview(data: data),
        const SizedBox(height: Spacing.lg),
        Row(
          children: [
            Text(
              'คอนเทนต์ของคุณ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            TextButton(onPressed: c.load, child: const Text('อัปเดต')),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        if (data.needAction.isNotEmpty)
          _Section(
            icon: Icons.priority_high_rounded,
            color: context.t.error,
            title: 'ต้องทำ',
            count: data.needAction.length,
            children: [
              for (final action in data.needAction)
                _ActionCard(
                  item: action,
                  onTap: () => _handle(context, action),
                ),
            ],
          ),
        if (data.working.isNotEmpty)
          _Section(
            icon: Icons.auto_awesome_rounded,
            color: context.t.primary,
            title: 'กำลังสร้าง',
            count: data.working.length,
            children: [for (final job in data.working) JobCard(job: job)],
          ),
        if (data.scheduled.isNotEmpty)
          _Section(
            icon: Icons.schedule_rounded,
            color: context.t.warning,
            title: 'ตั้งเวลาไว้',
            count: data.scheduled.length,
            children: [for (final job in data.scheduled) JobCard(job: job)],
          ),
        if (data.publishedToday.isNotEmpty)
          _Section(
            icon: Icons.check_circle_outline_rounded,
            color: context.t.success,
            title: 'โพสต์แล้ววันนี้',
            count: data.publishedToday.length,
            children: [
              for (final job in data.publishedToday) JobCard(job: job),
            ],
          ),
      ],
    );
  }

  void _handle(BuildContext context, ActionItem action) {
    if (action.kind == ActionKind.needsReauth) {
      context.push('/connections');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('รายละเอียดงานจะพร้อมในหน้าคอนเทนต์')),
    );
  }

  Future<void> _create(BuildContext context) async {
    await context.push('/create');
    if (context.mounted) await widget.controller.load();
  }
}

class _CreatorTitle extends StatelessWidget {
  const _CreatorTitle({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [context.t.primary, context.t.success],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          name.characters.first.toUpperCase(),
          style: TextStyle(
            color: context.t.onPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'สวัสดี, $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'มาดูว่าวันนี้มีอะไรต้องทำ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ],
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.data});
  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final clear = data.needAction.isEmpty;
    final statusColor = clear ? context.t.success : context.t.warning;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.t.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.t.surfaceElevated, context.t.surfaceContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: .35),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  clear
                      ? 'ทุกอย่างเรียบร้อย'
                      : 'มี ${data.needAction.length} รายการรอคุณตรวจ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              _Metric(
                value: '${data.working.length}',
                label: 'กำลังสร้าง',
                color: context.t.primary,
              ),
              _Metric(
                value: '${data.scheduled.length}',
                label: 'ตั้งเวลา',
                color: context.t.warning,
              ),
              _Metric(
                value: '${data.publishedToday.length}',
                label: 'โพสต์วันนี้',
                color: context.t.success,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: context.t.surface.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: context.t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

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
          Icon(icon, size: 20, color: color),
          const SizedBox(width: Spacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: Spacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
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
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: Spacing.sm),
    padding: const EdgeInsets.all(Spacing.md),
    decoration: BoxDecoration(
      color: context.t.error.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: context.t.error.withValues(alpha: .38)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.t.error.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.priority_high_rounded,
                color: context.t.error,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    item.detail,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.t.error,
              foregroundColor: Colors.white,
            ),
            onPressed: onTap,
            child: Text(item.actionLabel),
          ),
        ),
      ],
    ),
  );
}

class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job});
  final PublishJob job;

  @override
  Widget build(BuildContext context) {
    final color = switch (job.status) {
      JobStatus.published => context.t.success,
      JobStatus.failed => context.t.error,
      _ when job.status.isWorking => context.t.primary,
      _ => context.t.warning,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: .24)),
              ),
              child: Icon(Icons.play_circle_outline_rounded, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(
                    '${_when(job.scheduledAt)} · ${job.status.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (job.status.isWorking) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(Spacing.md),
    children: [
      const SizedBox(height: Spacing.lg),
      Container(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.t.border),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.t.surfaceElevated, context.t.surfaceContainer],
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: context.t.primary.withValues(alpha: .12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.t.primary.withValues(alpha: .35),
                ),
              ),
              child: Icon(
                Icons.movie_creation_outlined,
                size: 36,
                color: context.t.primary,
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'ยังไม่มีคอนเทนต์เลย',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'เลือกสินค้าหรือวิดีโอ แล้วเตรียมคลิปที่มีตะกร้าสินค้าพร้อมโพสต์บน TikTok',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.t.textSecondary, height: 1.55),
            ),
            const SizedBox(height: Spacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: context.t.creative,
                  foregroundColor: Colors.white,
                ),
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('สร้างคลิปแรก'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: Spacing.lg),
      Text(
        'เริ่มต้นใน 3 ขั้นตอน',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: Spacing.sm),
      const _GuideStep(
        number: '1',
        title: 'เลือกสินค้าใน Showcase',
        detail: 'เลือกสินค้าที่ต้องการทำคอนเทนต์',
      ),
      const _GuideStep(
        number: '2',
        title: 'สร้างด้วย AI หรือใช้วิดีโอของคุณ',
        detail: 'ปรับสคริปต์ เสียง และข้อความก่อนเผยแพร่',
      ),
      const _GuideStep(
        number: '3',
        title: 'ตรวจคลิปและยืนยันตะกร้า',
        detail: 'คุณเป็นผู้อนุมัติทุกครั้งก่อนโพสต์',
      ),
    ],
  );
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.title,
    required this.detail,
  });
  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.t.primary.withValues(alpha: .10),
            shape: BoxShape.circle,
            border: Border.all(color: context.t.primary.withValues(alpha: .3)),
          ),
          child: Text(
            number,
            style: TextStyle(
              color: context.t.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: 0,
    onDestinationSelected: (index) {
      switch (index) {
        case 0:
          return;
        case 1:
          context.push('/showcase');
        case 2:
          onCreate();
        case 3:
          context.push('/content');
        case 4:
          context.push('/connections');
      }
    },
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.grid_view_rounded),
        label: 'หน้าหลัก',
      ),
      NavigationDestination(
        icon: Icon(Icons.shopping_bag_outlined),
        label: 'สินค้า',
      ),
      NavigationDestination(
        icon: Icon(Icons.add_circle_rounded),
        label: 'สร้าง',
      ),
      NavigationDestination(
        icon: Icon(Icons.video_library_outlined),
        label: 'คอนเทนต์',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        label: 'โปรไฟล์',
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
    padding: const EdgeInsets.all(Spacing.lg),
    children: [
      SizedBox(height: MediaQuery.sizeOf(context).height * .18),
      Icon(Icons.cloud_off_rounded, size: 48, color: context.t.textSecondary),
      const SizedBox(height: Spacing.md),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: Spacing.lg),
      FilledButton(onPressed: onRetry, child: const Text('ลองใหม่')),
    ],
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.t.error.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(Radii.md),
      border: Border.all(color: context.t.error.withValues(alpha: .25)),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline, size: 18, color: context.t.error),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: context.t.error, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

String _when(DateTime time) {
  final now = DateTime.now();
  final clock =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  final difference = DateTime(
    time.year,
    time.month,
    time.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (difference == 0) return 'วันนี้ $clock';
  if (difference == 1) return 'พรุ่งนี้ $clock';
  if (difference == -1) return 'เมื่อวาน $clock';
  const months = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];
  return '${time.day} ${months[time.month - 1]} $clock';
}
