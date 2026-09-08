import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';

enum _NoticeFilter { all, action, update }

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  _NoticeFilter filter = _NoticeFilter.all;
  final Set<int> read = {};

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
          TextButton(
            onPressed: () => setState(
              () => read.addAll(List.generate(notices.length, (i) => i)),
            ),
            child: const Text('อ่านทั้งหมด'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Spacing.md, 4, Spacing.md, 110),
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('ทั้งหมด'),
                  selected: filter == _NoticeFilter.all,
                  onSelected: (_) => setState(() => filter = _NoticeFilter.all),
                ),
                ChoiceChip(
                  label: const Text('ต้องทำ'),
                  selected: filter == _NoticeFilter.action,
                  onSelected: (_) =>
                      setState(() => filter = _NoticeFilter.action),
                ),
                ChoiceChip(
                  label: const Text('อัปเดต'),
                  selected: filter == _NoticeFilter.update,
                  onSelected: (_) =>
                      setState(() => filter = _NoticeFilter.update),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
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
}

class _NoticeCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final color = action ? context.t.error : context.t.primary;
    return Material(
      color: unread ? color.withValues(alpha: .07) : context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(
              color: unread ? color.withValues(alpha: .3) : context.t.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Icon(icon, color: color, size: 21),
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
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: TextStyle(
                        color: context.t.textSecondary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      action ? 'เปิดเพื่อแก้ไข' : 'เมื่อครู่',
                      style: TextStyle(color: color, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
