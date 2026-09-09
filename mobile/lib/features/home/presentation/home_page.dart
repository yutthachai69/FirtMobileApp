import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/skeleton.dart';
import '../../../core/auth/auth_controller.dart';
import '../domain/content_store.dart';
import '../domain/home_data.dart';
import 'content_artwork.dart';
import 'home_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.auth,
    required this.controller,
    this.store,
  });
  final AuthController auth;
  final HomeController controller;

  /// เมื่อ backend ยังไม่มีข้อมูล หน้าหลักจะแสดงงานจากแหล่งกลางนี้แทนหน้าว่าง
  final ContentStore? store;

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
    listenable: Listenable.merge([
      widget.auth,
      widget.controller,
      widget.store,
    ]),
    builder: (context, _) {
      final rawName = widget.auth.account?.name.trim();
      final name = rawName == null || rawName.isEmpty ? 'คุณ' : rawName;
      final c = widget.controller;
      // ข้อมูล backend มาก่อน ถ้าไม่มีหรือว่างเปล่าใช้แหล่งกลาง (prototype)
      final backend = c.data;
      final data = (backend != null && !backend.isEmpty)
          ? backend
          : widget.store?.homeData() ?? backend;
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          titleSpacing: Spacing.md,
          title: _CreatorTitle(
            name: name,
            subtitle: data == null || data.isEmpty
                ? 'พร้อมรับคอนเทนต์ชิ้นแรก'
                : data.needAction.isNotEmpty
                ? 'มี ${data.needAction.length} งานรอคุณตรวจ'
                : 'ทุกงานกำลังเดินตามแผน',
          ),
          actions: [
            Badge(
              isLabelVisible: data?.needAction.isNotEmpty ?? false,
              child: IconButton.filledTonal(
                onPressed: () => context.push('/notifications'),
                icon: const Icon(Icons.notifications_none_rounded),
                tooltip: 'การแจ้งเตือน',
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
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
    final hasData = data != null && !data.isEmpty;
    if (!hasData) {
      if (!c.loaded && c.loading) return const SkeletonList();
      if (c.error != null && !c.loaded && widget.store == null) {
        return _ErrorView(message: c.error!, onRetry: c.load);
      }
      return _EmptyState(
        onImportAi: () => context.go('/create/import-ai'),
        onUpload: () => context.go('/create/upload'),
        onCreateAi: () => context.go('/create/ai'),
        onShowcase: () => context.go('/showcase'),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.sm,
        Spacing.md,
        Spacing.xl,
      ),
      children: [
        // แสดง inline error เฉพาะตอนพึ่ง backend ล้วน ไม่ใช่ตอน fallback ไป store
        if (c.error != null && widget.store == null) ...[
          _InlineError(message: c.error!),
          const SizedBox(height: Spacing.md),
        ],
        _Overview(data: data),
        const SizedBox(height: Spacing.md),
        _QuickRelayBar(
          onImportAi: () => context.go('/create/import-ai'),
          onUpload: () => context.go('/create/upload'),
          onShowcase: () => context.go('/showcase'),
        ),
        if (data.reviewQueue.isNotEmpty) ...[
          const SizedBox(height: Spacing.md),
          _ReviewQueueBar(
            count: data.reviewQueue.length,
            onOpen: () => context.push('/review'),
          ),
        ],
        const SizedBox(height: Spacing.lg),
        Row(
          children: [
            Text(
              'คอนเทนต์ของคุณ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/content'),
              child: const Text('ดูทั้งหมด'),
            ),
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
}

class _CreatorTitle extends StatelessWidget {
  const _CreatorTitle({required this.name, required this.subtitle});
  final String name;
  final String subtitle;

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
              subtitle,
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

class _ReviewQueueBar extends StatelessWidget {
  const _ReviewQueueBar({required this.count, required this.onOpen});
  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: context.t.creative.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: context.t.creative.withValues(alpha: .4)),
        ),
        child: Row(
          children: [
            Icon(Icons.swipe_rounded, color: context.t.creative),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'มี $count งานรอตรวจ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'ปัดอนุมัติหรือส่งกลับแก้ทีละชิ้น',
                    style: TextStyle(
                      color: context.t.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _QuickRelayBar extends StatelessWidget {
  const _QuickRelayBar({
    required this.onImportAi,
    required this.onUpload,
    required this.onShowcase,
  });

  final VoidCallback onImportAi;
  final VoidCallback onUpload;
  final VoidCallback onShowcase;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: context.t.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const Key('home-quick-import-ai'),
            onPressed: onImportAi,
            icon: const Icon(Icons.auto_awesome_rounded, size: 19),
            label: const Text('รับจาก AI'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          key: const Key('home-quick-upload'),
          tooltip: 'อัปโหลดคลิป',
          onPressed: onUpload,
          icon: const Icon(Icons.upload_file_rounded),
        ),
        const SizedBox(width: 5),
        IconButton.filledTonal(
          tooltip: 'เลือกสินค้า',
          onPressed: onShowcase,
          icon: const Icon(Icons.shopping_bag_outlined),
        ),
      ],
    ),
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
  const JobCard({super.key, required this.job, this.onTap});
  final PublishJob job;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = contentStatusColor(context, job.status);
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () => context.go('/content/${job.id}', extra: job),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ContentArtwork(
                job: job,
                status: job.status,
                width: 66,
                height: 82,
                compact: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'จัดการคอนเทนต์',
                onPressed: () => showJobActions(context, job),
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showJobActions(BuildContext context, PublishJob job) {
  final actions = switch (job.status) {
    JobStatus.draft => const [
      (Icons.edit_outlined, 'ทำฉบับร่างต่อ'),
      (Icons.copy_rounded, 'สร้างสำเนา'),
    ],
    JobStatus.scheduled => const [
      (Icons.edit_calendar_outlined, 'เปลี่ยนเวลาเผยแพร่'),
      (Icons.pause_circle_outline_rounded, 'พักการเผยแพร่'),
    ],
    JobStatus.published => const [
      (Icons.open_in_new_rounded, 'เปิดผลงาน'),
      (Icons.copy_rounded, 'สร้างคอนเทนต์คล้ายกัน'),
    ],
    JobStatus.failed => const [
      (Icons.build_outlined, 'ดูสาเหตุและแก้ไข'),
      (Icons.refresh_rounded, 'ลองส่งใหม่'),
    ],
    _ => const [
      (Icons.notifications_outlined, 'แจ้งเตือนเมื่อเสร็จ'),
      (Icons.visibility_outlined, 'ดูความคืบหน้า'),
    ],
  };
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              job.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(job.status.label),
          ),
          for (final action in actions)
            ListTile(
              leading: Icon(action.$1),
              title: Text(action.$2),
              onTap: () {
                Navigator.pop(sheetContext);
                if (action == actions.first) {
                  context.go('/content/${job.id}', extra: job);
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('${action.$2}แล้ว')));
                }
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onImportAi,
    required this.onUpload,
    required this.onCreateAi,
    required this.onShowcase,
  });
  final VoidCallback onImportAi;
  final VoidCallback onUpload;
  final VoidCallback onCreateAi;
  final VoidCallback onShowcase;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(Spacing.md),
    children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.t.primary.withValues(alpha: .35)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.t.primary.withValues(alpha: .16),
              context.t.surfaceContainer,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: context.t.primary.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.t.primary.withValues(alpha: .35),
                    ),
                  ),
                  child: Icon(
                    Icons.move_to_inbox_outlined,
                    size: 25,
                    color: context.t.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: context.t.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'AI CONTENT RELAY',
                    style: TextStyle(
                      color: context.t.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'เปลี่ยนคอนเทนต์ให้พร้อมขาย',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'รับคลิปจากเครื่องมือ AI ที่คุณใช้อยู่ หรืออัปโหลดจากมือถือ แล้วผูกสินค้า ตรวจตะกร้า และตั้งเวลาในที่เดียว',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.t.textSecondary, height: 1.55),
            ),
            const SizedBox(height: Spacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('home-import-ai'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.t.primary,
                  foregroundColor: context.t.onPrimary,
                ),
                onPressed: onImportAi,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('รับคอนเทนต์จาก AI'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onShowcase,
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('เลือกสินค้าใน Showcase'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: Spacing.md),
      Text('เริ่มด้วยวิธีอื่น', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: Spacing.sm),
      Row(
        children: [
          Expanded(
            child: _StartPath(
              icon: Icons.video_file_outlined,
              title: 'อัปโหลดคลิป',
              detail: 'จากมือถือ',
              onTap: onUpload,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StartPath(
              icon: Icons.auto_fix_high_rounded,
              title: 'สร้างด้วย AI',
              detail: 'เมื่อยังไม่มีคลิป',
              creative: true,
              onTap: onCreateAi,
            ),
          ),
        ],
      ),
      const SizedBox(height: Spacing.lg),
      Text(
        'เส้นทางสู่โพสต์ขาย',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: Spacing.sm),
      const _GuideStep(
        number: '1',
        title: 'นำคอนเทนต์เข้ามา',
        detail: 'รับจาก AI หรือเลือกไฟล์จากมือถือ',
      ),
      const _GuideStep(
        number: '2',
        title: 'ผูกสินค้าจาก Showcase',
        detail: 'เลือกสินค้าที่ต้องการปักตะกร้ากับคลิป',
      ),
      const _GuideStep(
        number: '3',
        title: 'Preview และยืนยันเผยแพร่',
        detail: 'ตรวจคลิป แคปชัน ตะกร้า และเวลาโพสต์',
      ),
    ],
  );
}

class _StartPath extends StatelessWidget {
  const _StartPath({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.creative = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final bool creative;

  @override
  Widget build(BuildContext context) {
    final color = creative ? context.t.creative : context.t.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.t.surfaceContainer,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: color.withValues(alpha: .35)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
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
