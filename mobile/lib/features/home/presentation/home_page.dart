import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/relay_state_panel.dart';
import '../../../app/widgets/skeleton.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/config/app_config.dart';
import '../domain/content_store.dart';
import '../domain/home_data.dart';
import 'content_artwork.dart';
import 'home_controller.dart';
import 'notifications_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.auth,
    required this.controller,
    this.store,
    this.notifications,
  });
  final AuthController auth;
  final HomeController controller;

  /// เมื่อ backend ยังไม่มีข้อมูล หน้าหลักจะแสดงงานจากแหล่งกลางนี้แทนหน้าว่าง
  final ContentStore? store;
  final NotificationsController? notifications;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    final reduced = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _entrance = AnimationController(
      vsync: this,
      duration: reduced ? Duration.zero : const Duration(milliseconds: 620),
    )..forward();
    widget.controller.addListener(_syncStore);
    widget.controller.load();
    widget.controller.startPolling();
    if (AppConfig.isLive) {
      widget.notifications?.load();
      widget.notifications?.startPolling();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    widget.controller.removeListener(_syncStore);
    widget.controller.stopPolling();
    widget.notifications?.stopPolling();
    super.dispose();
  }

  void _syncStore() {
    final data = widget.controller.data;
    final store = widget.store;
    if (data == null || store == null) return;
    // In demo mode an empty backend response intentionally leaves the rich
    // fixture visible. Any real response, including an empty live account,
    // becomes the single snapshot shared by Home and Content.
    if (data.jobs.isNotEmpty || AppConfig.isLive) {
      store.replaceAll(data.jobs);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.auth,
      widget.controller,
      widget.store,
      if (widget.notifications != null) widget.notifications!,
    ]),
    builder: (context, _) {
      final rawName = widget.auth.account?.name.trim();
      final name = rawName == null || rawName.isEmpty ? 'คุณ' : rawName;
      final c = widget.controller;
      // ข้อมูล backend มาก่อน ถ้าไม่มีหรือว่างเปล่าใช้แหล่งกลาง (prototype)
      final backend = c.data;
      final data = (backend != null && !backend.isEmpty)
          ? backend
          : AppConfig.isDemo
          ? widget.store?.homeData() ?? backend
          : backend;
      final titleMotion = CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0, .55, curve: Curves.easeOutCubic),
      );
      final bodyMotion = CurvedAnimation(
        parent: _entrance,
        curve: const Interval(.16, 1, curve: Curves.easeOutCubic),
      );
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          titleSpacing: Spacing.md,
          title: FadeTransition(
            opacity: titleMotion,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-.08, 0),
                end: Offset.zero,
              ).animate(titleMotion),
              child: _CreatorTitle(
                name: name,
                subtitle: data == null || data.isEmpty
                    ? 'พร้อมรับคอนเทนต์ชิ้นแรก'
                    : data.needAction.isNotEmpty
                    ? 'มี ${data.needAction.length} งานรอคุณตรวจ'
                    : 'ทุกงานกำลังเดินตามแผน',
              ),
            ),
          ),
          actions: [
            Badge(
              label: Text(
                '${AppConfig.isLive ? widget.notifications?.unreadCount ?? 0 : data?.needAction.length ?? 0}',
              ),
              isLabelVisible: AppConfig.isLive
                  ? (widget.notifications?.unreadCount ?? 0) > 0
                  : data?.needAction.isNotEmpty ?? false,
              child: IconButton.filledTonal(
                onPressed: () => context.push('/notifications'),
                icon: const Icon(Icons.notifications_none_rounded),
                tooltip: 'การแจ้งเตือน',
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: FadeTransition(
          opacity: bodyMotion,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .035),
              end: Offset.zero,
            ).animate(bodyMotion),
            child: SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: () async {
                  await c.load();
                  if (AppConfig.isLive) await widget.notifications?.load();
                },
                child: _body(context, c, data),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _body(BuildContext context, HomeController c, HomeData? data) {
    final hasData = data != null && !data.isEmpty;
    if (!hasData) {
      if (!c.loaded && c.loading) return const SkeletonList();
      if (c.error != null &&
          !c.loaded &&
          (widget.store == null || AppConfig.isLive)) {
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
        // Keep cached data visible in live mode, but never hide that its
        // latest refresh failed just because a shared store exists.
        if (c.error != null &&
            c.loaded &&
            (AppConfig.isLive || widget.store == null)) ...[
          RelayStaleBanner(message: c.error!, onRetry: c.load),
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
            children: [
              for (final entry in data.working.asMap().entries)
                JobCard(job: entry.value, animationIndex: entry.key),
            ],
          ),
        if (data.scheduled.isNotEmpty)
          _Section(
            icon: Icons.schedule_rounded,
            color: context.t.warning,
            title: 'ตั้งเวลาไว้',
            count: data.scheduled.length,
            children: [
              for (final entry in data.scheduled.asMap().entries)
                JobCard(job: entry.value, animationIndex: entry.key),
            ],
          ),
        if (data.publishedToday.isNotEmpty)
          _Section(
            icon: Icons.check_circle_outline_rounded,
            color: context.t.success,
            title: 'โพสต์แล้ววันนี้',
            count: data.publishedToday.length,
            children: [
              for (final entry in data.publishedToday.asMap().entries)
                JobCard(job: entry.value, animationIndex: entry.key),
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
          children: [
            const Text(
              'เริ่มงานใหม่',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              'เลือกเส้นทาง',
              style: TextStyle(color: context.t.textSecondary, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _AiRelayAction(
                key: const Key('home-quick-import-ai'),
                onTap: onImportAi,
              ),
            ),
            const SizedBox(width: 8),
            _CompactHomeAction(
              key: const Key('home-quick-upload'),
              tooltip: 'อัปโหลดคลิป',
              icon: Icons.upload_file_rounded,
              color: context.t.success,
              signature: _QuickSignature.upload,
              onTap: onUpload,
            ),
            const SizedBox(width: 7),
            _CompactHomeAction(
              tooltip: 'เลือกสินค้า',
              icon: Icons.shopping_bag_outlined,
              color: context.t.warning,
              signature: _QuickSignature.product,
              onTap: onShowcase,
            ),
          ],
        ),
      ],
    ),
  );
}

class _AiRelayAction extends StatefulWidget {
  const _AiRelayAction({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AiRelayAction> createState() => _AiRelayActionState();
}

class _AiRelayActionState extends State<_AiRelayAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? .97 : 1,
    duration: const Duration(milliseconds: 90),
    child: Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.t.primary,
            Color.lerp(context.t.primary, context.t.creative, .22)!,
          ],
        ),
        borderRadius: BorderRadius.circular(Radii.md),
        boxShadow: _pressed
            ? null
            : [
                BoxShadow(
                  color: context.t.primary.withValues(alpha: .16),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Material(
        color: context.t.primary.withValues(alpha: 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onHighlightChanged: (value) {
            if (mounted) setState(() => _pressed = value);
          },
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          child: Stack(
            children: [
              Positioned(
                right: 9,
                top: 8,
                child: Icon(
                  Icons.hub_outlined,
                  color: context.t.onPrimary.withValues(alpha: .2),
                  size: 37,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: context.t.onPrimary,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'รับจาก AI',
                            style: TextStyle(
                              color: context.t.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Relay เข้า Inbox',
                            style: TextStyle(
                              color: context.t.onPrimary.withValues(alpha: .72),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: context.t.onPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

enum _QuickSignature { upload, product }

class _CompactHomeAction extends StatelessWidget {
  const _CompactHomeAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.signature,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final _QuickSignature signature;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: color.withValues(alpha: .1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: color.withValues(alpha: .28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: 54,
          height: 54,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: color, size: 23),
              if (signature == _QuickSignature.upload)
                Positioned(
                  bottom: 8,
                  child: Container(
                    width: 20,
                    height: 2,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                )
              else
                Positioned(
                  right: 9,
                  top: 9,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: .5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
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

class _ActionCard extends StatefulWidget {
  const _ActionCard({required this.item, required this.onTap});
  final ActionItem item;
  final VoidCallback onTap;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;

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
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 620),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Container(
                padding: EdgeInsets.all(8 + (value * 2)),
                decoration: BoxDecoration(
                  color: context.t.error.withValues(alpha: .1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.t.error.withValues(
                      alpha: .16 + (.28 * value),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.t.error.withValues(
                        alpha: .12 * (1 - value),
                      ),
                      blurRadius: 16 * value,
                      spreadRadius: 3 * value,
                    ),
                  ],
                ),
                child: child,
              ),
              child: Icon(
                widget.item.kind == ActionKind.needsReauth
                    ? Icons.link_off_rounded
                    : Icons.priority_high_rounded,
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
                    widget.item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    widget.item.detail,
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
          child: Listener(
            onPointerDown: (_) => setState(() => _pressed = true),
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: _pressed ? .975 : 1,
              duration: const Duration(milliseconds: 90),
              child: FilledButton.icon(
                key: Key('resolve-${widget.item.kind.name}'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.t.error.withValues(alpha: .13),
                  foregroundColor: context.t.error,
                  side: BorderSide(
                    color: context.t.error.withValues(alpha: .45),
                  ),
                  shadowColor: context.t.error.withValues(alpha: 0),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.onTap();
                },
                icon: Icon(
                  widget.item.kind == ActionKind.needsReauth
                      ? Icons.link_rounded
                      : Icons.troubleshoot_rounded,
                  size: 19,
                ),
                label: Text(widget.item.actionLabel),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class JobCard extends StatefulWidget {
  const JobCard({
    super.key,
    required this.job,
    this.onTap,
    this.animationIndex = 0,
  });
  final PublishJob job;
  final VoidCallback? onTap;
  final int animationIndex;

  @override
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    final reduced = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _entrance = AnimationController(
      vsync: this,
      duration: reduced ? Duration.zero : const Duration(milliseconds: 420),
    );
    if (reduced || widget.animationIndex == 0) {
      _entrance.forward();
    } else {
      Future<void>.delayed(
        Duration(milliseconds: widget.animationIndex * 70),
        () {
          if (mounted) _entrance.forward();
        },
      );
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final color = contentStatusColor(context, job.status);
    final slide = CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: slide,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .08),
          end: Offset.zero,
        ).animate(slide),
        child: AnimatedScale(
          scale: _pressed ? .985 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: Card(
            margin: const EdgeInsets.only(bottom: Spacing.sm),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onHighlightChanged: (value) {
                if (mounted) setState(() => _pressed = value);
              },
              onTap:
                  widget.onTap ??
                  () => context.go('/content/${job.id}', extra: job),
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
                    _JobStatusSignal(status: job.status, color: color),
                    const SizedBox(width: 6),
                    IconButton.outlined(
                      tooltip: 'จัดการคอนเทนต์',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(38, 38),
                        side: BorderSide(color: color.withValues(alpha: .3)),
                        foregroundColor: color,
                        backgroundColor: color.withValues(alpha: .07),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        showJobActions(context, job);
                      },
                      icon: const Icon(Icons.more_horiz_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JobStatusSignal extends StatelessWidget {
  const _JobStatusSignal({required this.status, required this.color});
  final JobStatus status;
  final Color color;

  double get _progress => switch (status) {
    JobStatus.queued => .28,
    JobStatus.uploading => .55,
    JobStatus.processing => .78,
    JobStatus.awaitingReview => .92,
    _ => 1,
  };

  IconData get _icon => switch (status) {
    JobStatus.scheduled => Icons.schedule_rounded,
    JobStatus.published => Icons.check_rounded,
    JobStatus.failed => Icons.priority_high_rounded,
    JobStatus.draft => Icons.edit_outlined,
    _ => Icons.auto_awesome_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _progress),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 780),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => SizedBox(
        width: 34,
        height: 34,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: status == JobStatus.published ? 2.6 : 2,
                color: color,
                backgroundColor: color.withValues(alpha: .12),
                strokeCap: StrokeCap.round,
              ),
            ),
            Icon(_icon, color: color, size: 16),
          ],
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
  final statusColor = contentStatusColor(context, job.status);
  showModalBottomSheet<void>(
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .11),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor.withValues(alpha: .28),
                    ),
                  ),
                  child: Icon(
                    job.status == JobStatus.scheduled
                        ? Icons.schedule_rounded
                        : job.status == JobStatus.published
                        ? Icons.check_rounded
                        : job.status == JobStatus.failed
                        ? Icons.priority_high_rounded
                        : Icons.auto_awesome_rounded,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job.status.label,
                        style: TextStyle(color: statusColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            for (final entry in actions.asMap().entries) ...[
              _JobActionTile(
                icon: entry.value.$1,
                label: entry.value.$2,
                color: entry.key == 0
                    ? statusColor
                    : sheetContext.t.textSecondary,
                prominent: entry.key == 0,
                onTap: () {
                  Navigator.pop(sheetContext);
                  HapticFeedback.selectionClick();
                  if (entry.key == 0) {
                    context.go('/content/${job.id}', extra: job);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${entry.value.$2}แล้ว')),
                    );
                  }
                },
              ),
              if (entry.key != actions.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    ),
  );
}

class _JobActionTile extends StatelessWidget {
  const _JobActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.prominent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool prominent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: prominent ? color.withValues(alpha: .1) : context.t.surfaceContainer,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      side: BorderSide(
        color: prominent ? color.withValues(alpha: .32) : context.t.border,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: prominent ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_rounded, size: 18, color: color),
          ],
        ),
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
