import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/motion/motion_tokens.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/relay_state_panel.dart';
import '../../../app/widgets/skeleton.dart';
import '../../../core/config/app_config.dart';
import '../domain/app_notification.dart';
import 'notifications_controller.dart';

enum _NoticeFilter { all, action, update }

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.controller});

  final NotificationsController? controller;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  _NoticeFilter filter = _NoticeFilter.all;
  final Set<int> read = {};

  @override
  void initState() {
    super.initState();
    if (AppConfig.isLive && widget.controller != null) {
      widget.controller!.load();
    }
  }

  static const notices = [
    (
      'ต้องแก้ก่อนเผยแพร่',
      'สินค้าที่ผูกไว้หมดสต็อก คลิปและแคปชันยังถูกเก็บไว้',
      true,
      Icons.error_outline_rounded,
    ),
    (
      'รับคอนเทนต์จาก AI แล้ว',
      'Serum close-up พร้อมให้ตรวจและเลือกสินค้า',
      false,
      Icons.auto_awesome_rounded,
    ),
    (
      'ตั้งเวลาเรียบร้อย',
      'คลิปไมโครโฟนจะเผยแพร่พรุ่งนี้ เวลา 19:30',
      false,
      Icons.event_available_outlined,
    ),
    (
      'บัญชีต้องตรวจสอบใหม่',
      'สิทธิ์เผยแพร่ของ TikTok Shop ใกล้หมดอายุ',
      true,
      Icons.link_off_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (AppConfig.isLive && controller != null) {
      return _buildLive(context, controller);
    }
    return _buildDemo(context);
  }

  Widget _buildDemo(BuildContext context) {
    final visible = List.generate(notices.length, (i) => i).where((i) {
      final action = notices[i].$3;
      return filter == _NoticeFilter.all ||
          (filter == _NoticeFilter.action && action) ||
          (filter == _NoticeFilter.update && !action);
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('การแจ้งเตือน'),
        actions: [
          _MarkAllReadButton(
            enabled: read.length < notices.length,
            onPressed: () async {
              setState(
                () => read.addAll(List.generate(notices.length, (i) => i)),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Spacing.md, 4, Spacing.md, 110),
          children: [
            _NotificationPulseHeader(
              unreadCount: notices.length - read.length,
              actionCount: notices
                  .asMap()
                  .entries
                  .where((entry) => entry.value.$3 && !read.contains(entry.key))
                  .length,
            ),
            const SizedBox(height: Spacing.md),
            _filterBar(),
            const SizedBox(height: Spacing.md),
            for (final index in visible) ...[
              _NoticeCard(
                title: notices[index].$1,
                detail: notices[index].$2,
                action: notices[index].$3,
                icon: notices[index].$4,
                unread: !read.contains(index),
                onTap: () => _open(index),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  void _open(int index) {
    setState(() => read.add(index));
    if (index == 0) {
      // ปล่อยให้ route แกะงานจากแหล่งกลางตาม id เอง
      context.go('/content/demo-failed');
    } else if (index == 3) {
      context.go('/connections');
    } else {
      context.go('/content');
    }
  }

  Widget _buildLive(BuildContext context, NotificationsController controller) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final visible = controller.items
            .where((item) {
              final action = _isAction(item);
              return filter == _NoticeFilter.all ||
                  (filter == _NoticeFilter.action && action) ||
                  (filter == _NoticeFilter.update && !action);
            })
            .toList(growable: false);
        return Scaffold(
          appBar: AppBar(
            title: const Text('การแจ้งเตือน'),
            actions: [
              _MarkAllReadButton(
                enabled: controller.unreadCount > 0,
                onPressed: () async {
                  final ok = await controller.markAllRead();
                  if (!context.mounted || ok) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(controller.error ?? 'ทำรายการไม่สำเร็จ'),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: controller.loading && controller.items.isEmpty
                ? const _NotificationsLoading()
                : controller.error != null && controller.items.isEmpty
                ? _LiveError(
                    message: controller.error!,
                    onRetry: controller.load,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.md,
                      4,
                      Spacing.md,
                      110,
                    ),
                    children: [
                      _NotificationPulseHeader(
                        unreadCount: controller.unreadCount,
                        actionCount: controller.items
                            .where((item) => !item.isRead && _isAction(item))
                            .length,
                      ),
                      const SizedBox(height: Spacing.md),
                      _filterBar(),
                      const SizedBox(height: Spacing.md),
                      if (visible.isEmpty)
                        const RelayStatePanel(
                          kind: RelayStateKind.empty,
                          title: 'กล่องแจ้งเตือนว่างแล้ว',
                          message:
                              'เมื่อมีงานเสร็จ ตารางเผยแพร่ หรือเรื่องที่ต้องจัดการ จะแสดงที่นี่',
                        ),
                      for (final item in visible) ...[
                        _NoticeCard(
                          title: item.title,
                          detail: item.body,
                          action: _isAction(item),
                          icon: _iconFor(item.type),
                          unread: !item.isRead,
                          onTap: () => _openLive(item, controller),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _filterBar() => _NoticeFilterBar(
    selected: filter,
    onChanged: (value) {
      HapticFeedback.selectionClick();
      setState(() => filter = value);
    },
  );

  bool _isAction(AppNotification item) {
    final type = item.type.toLowerCase();
    return type.contains('failed') ||
        type.contains('error') ||
        type.contains('reauth') ||
        type.contains('action') ||
        type.contains('expired');
  }

  IconData _iconFor(String type) {
    final value = type.toLowerCase();
    if (value.contains('failed') || value.contains('error')) {
      return Icons.error_outline_rounded;
    }
    if (value.contains('connection') || value.contains('reauth')) {
      return Icons.link_off_rounded;
    }
    if (value.contains('schedule')) return Icons.event_available_outlined;
    if (value.contains('ai') || value.contains('content')) {
      return Icons.auto_awesome_rounded;
    }
    return Icons.notifications_none_rounded;
  }

  void _openLive(AppNotification item, NotificationsController controller) {
    controller.markRead(item.id);
    final jobId = item.data['job_id']?.toString();
    final connectionId = item.data['connection_id']?.toString();
    final type = item.type.toLowerCase();
    if (jobId != null && jobId.isNotEmpty) {
      context.go('/content/$jobId');
    } else if ((connectionId != null && connectionId.isNotEmpty) ||
        type.contains('connection') ||
        type.contains('reauth')) {
      context.go('/connections');
    } else {
      context.go('/content');
    }
  }
}

class _LiveError extends StatelessWidget {
  const _LiveError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => RelayStatePanel(
    kind: RelayStateKind.offline,
    title: 'ยังดึงการแจ้งเตือนไม่ได้',
    message: message,
    actionLabel: 'ลองเชื่อมต่อใหม่',
    onAction: () => onRetry(),
  );
}

class _NotificationsLoading extends StatelessWidget {
  const _NotificationsLoading();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(Spacing.md, 4, Spacing.md, 110),
    children: const [
      Skeleton(height: 80, radius: Radii.lg),
      SizedBox(height: Spacing.md),
      Skeleton(height: 44, radius: Radii.md),
      SizedBox(height: Spacing.md),
      Skeleton(height: 104, radius: Radii.lg),
      SizedBox(height: 10),
      Skeleton(height: 104, radius: Radii.lg),
      SizedBox(height: 10),
      Skeleton(height: 104, radius: Radii.lg),
    ],
  );
}

class _NoticeCard extends StatefulWidget {
  const _NoticeCard({
    required this.title,
    required this.detail,
    required this.action,
    required this.icon,
    required this.unread,
    required this.onTap,
  });
  final String title;
  final String detail;
  final bool action;
  final IconData icon;
  final bool unread;
  final VoidCallback onTap;

  @override
  State<_NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<_NoticeCard> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.action ? context.t.error : context.t.primary;
    return AnimatedScale(
      scale: pressed ? .985 : 1,
      duration: context.motion(RelayMotion.fast),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          onHighlightChanged: (value) => setState(() => pressed = value),
          borderRadius: BorderRadius.circular(Radii.lg),
          child: AnimatedContainer(
            duration: context.motion(RelayMotion.standard),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.unread
                  ? color.withValues(alpha: .075)
                  : context.t.surfaceContainer,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(
                color: widget.unread
                    ? color.withValues(alpha: .42)
                    : context.t.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: context.motion(RelayMotion.standard),
                      width: 3,
                      height: widget.unread ? 18 : 7,
                      decoration: BoxDecoration(
                        color: widget.unread ? color : context.t.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      child: Icon(widget.icon, color: color, size: 21),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: TextStyle(
                                fontWeight: widget.unread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: context.motion(RelayMotion.standard),
                            child: widget.unread
                                ? Container(
                                    key: const ValueKey('unread'),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: .14),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      'ใหม่',
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(key: ValueKey('read')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.detail,
                        style: TextStyle(
                          color: context.t.textSecondary,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Icon(
                            widget.action
                                ? Icons.bolt_rounded
                                : Icons.schedule_rounded,
                            color: color,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.action ? 'แตะเพื่อจัดการ' : 'เมื่อครู่',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: color,
                            size: 17,
                          ),
                        ],
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
}

class _NotificationPulseHeader extends StatelessWidget {
  const _NotificationPulseHeader({
    required this.unreadCount,
    required this.actionCount,
  });

  final int unreadCount;
  final int actionCount;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: context.motion(RelayMotion.standard),
    padding: const EdgeInsets.all(Spacing.md),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          context.t.primary.withValues(alpha: .16),
          context.t.surfaceContainer,
        ],
      ),
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: context.t.primary.withValues(alpha: .32)),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.t.primary.withValues(alpha: .12),
            border: Border.all(color: context.t.primary.withValues(alpha: .42)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                unreadCount == 0
                    ? Icons.done_all_rounded
                    : Icons.notifications_active_outlined,
                color: unreadCount == 0 ? context.t.success : context.t.primary,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 5,
                  top: 4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: actionCount > 0
                          ? context.t.error
                          : context.t.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: context.motion(RelayMotion.standard),
                child: Text(
                  unreadCount == 0
                      ? 'เคลียร์ครบแล้ว'
                      : '$unreadCount รายการยังไม่ได้อ่าน',
                  key: ValueKey(unreadCount),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                actionCount > 0
                    ? '$actionCount รายการรอให้คุณจัดการ'
                    : 'ไม่มีงานเร่งด่วนค้างอยู่',
                style: TextStyle(
                  color: actionCount > 0
                      ? context.t.error
                      : context.t.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NoticeFilterBar extends StatelessWidget {
  const _NoticeFilterBar({required this.selected, required this.onChanged});

  final _NoticeFilter selected;
  final ValueChanged<_NoticeFilter> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.md),
      border: Border.all(color: context.t.border),
    ),
    child: Row(
      children: [
        _item(context, _NoticeFilter.all, 'ทั้งหมด', Icons.inbox_outlined),
        _item(context, _NoticeFilter.action, 'ต้องทำ', Icons.bolt_rounded),
        _item(context, _NoticeFilter.update, 'อัปเดต', Icons.history_rounded),
      ],
    ),
  );

  Widget _item(
    BuildContext context,
    _NoticeFilter value,
    String label,
    IconData icon,
  ) {
    final active = selected == value;
    return Expanded(
      child: Semantics(
        selected: active,
        button: true,
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(Radii.sm),
          child: AnimatedContainer(
            duration: context.motion(RelayMotion.standard),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: active
                  ? context.t.primary.withValues(alpha: .16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: active ? context.t.primary : context.t.textSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? context.t.primary : context.t.textSecondary,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkAllReadButton extends StatefulWidget {
  const _MarkAllReadButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final Future<void> Function() onPressed;

  @override
  State<_MarkAllReadButton> createState() => _MarkAllReadButtonState();
}

class _MarkAllReadButtonState extends State<_MarkAllReadButton> {
  bool busy = false;

  Future<void> _run() async {
    if (!widget.enabled || busy) return;
    setState(() => busy = true);
    HapticFeedback.mediumImpact();
    await widget.onPressed();
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: widget.enabled && !busy ? _run : null,
    icon: AnimatedSwitcher(
      duration: context.motion(RelayMotion.standard),
      child: busy
          ? const SizedBox(
              key: ValueKey('busy'),
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              widget.enabled
                  ? Icons.done_all_rounded
                  : Icons.check_circle_rounded,
              key: ValueKey(widget.enabled),
              size: 17,
            ),
    ),
    label: const Text('อ่านทั้งหมด'),
  );
}
