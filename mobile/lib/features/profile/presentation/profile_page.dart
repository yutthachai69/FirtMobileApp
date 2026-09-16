import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/motion/motion_tokens.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/auth/auth_controller.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.auth,
    this.themeMode = ThemeMode.dark,
    this.reducedMotion = false,
    this.onThemeModeChanged,
    this.onReducedMotionChanged,
  });
  final AuthController auth;
  final ThemeMode themeMode;
  final bool reducedMotion;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ValueChanged<bool>? onReducedMotionChanged;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool jobNotifications = true;
  bool actionNotifications = true;
  late ThemeMode themeMode = widget.themeMode;
  late bool reducedMotion = widget.reducedMotion;

  @override
  Widget build(BuildContext context) {
    final account = widget.auth.account;
    final name = account?.name.isNotEmpty == true
        ? account!.name
        : 'Relay Creator';
    return Scaffold(
      appBar: AppBar(title: const Text('โปรไฟล์')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Spacing.md, 4, Spacing.md, 110),
          children: [
            _ProfileHeader(
              name: name,
              email: account?.email ?? '',
              onEdit: () => _editProfile(context, name),
            ),
            const SizedBox(height: Spacing.md),
            const _SectionLabel('การเชื่อมต่อ'),
            _IntegrationPanel(
              children: [
                _IntegrationTile(
                  icon: Icons.music_note_rounded,
                  title: 'TikTok Shop Creator',
                  subtitle: 'ตรวจบัญชี สิทธิ์ และการซิงก์สินค้า',
                  color: context.t.primary,
                  status: 'พร้อมเผยแพร่',
                  onTap: () => context.go('/connections'),
                ),
                _IntegrationTile(
                  icon: Icons.hub_outlined,
                  title: 'แหล่งคอนเทนต์ AI',
                  subtitle: 'Google Flow เชื่อมแล้ว · เพิ่มแหล่งอื่น',
                  color: context.t.success,
                  status: 'เชื่อมแล้ว 1',
                  onTap: () => context.go('/create/import-ai'),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            const _SectionLabel('การตั้งค่าแอป'),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'การแจ้งเตือน',
                  subtitle: 'งานเสร็จ ปัญหาที่ต้องแก้ และตารางโพสต์',
                  onTap: () => _notificationSheet(context),
                ),
                _SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'หน้าตาแอป',
                  subtitle:
                      '${_themeLabel(themeMode)} · ${reducedMotion ? 'ลดการเคลื่อนไหว' : 'Motion ปกติ'}',
                  onTap: () => _appearanceSheet(context),
                ),
                _SettingsTile(
                  icon: Icons.schedule_rounded,
                  title: 'เขตเวลา',
                  subtitle: account?.timezone ?? 'Asia/Bangkok',
                  onTap: () => _timezoneSheet(context),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            const _SectionLabel('ช่วยเหลือและบัญชี'),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: 'ศูนย์ช่วยเหลือ',
                  subtitle: 'การนำเข้าคอนเทนต์ ตะกร้า และการเผยแพร่',
                  onTap: () => _helpSheet(context),
                ),
                _SettingsTile(
                  icon: Icons.shield_outlined,
                  title: 'ความเป็นส่วนตัว',
                  subtitle: 'ข้อมูลที่ RelayContent เข้าถึงและระยะเวลาเก็บ',
                  onTap: () => _privacySheet(context),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            _SignOutAction(
              key: const Key('profile-sign-out'),
              onTap: widget.auth.busy ? null : () => _confirmSignOut(context),
            ),
          ],
        ),
      ),
    );
  }

  void _notificationSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => StatefulBuilder(
      builder: (context, sheetSetState) => Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, 4, Spacing.lg, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('การแจ้งเตือน', style: Theme.of(context).textTheme.titleLarge),
            SwitchListTile(
              title: const Text('แจ้งเมื่องานเปลี่ยนสถานะ'),
              value: jobNotifications,
              onChanged: (v) {
                setState(() => jobNotifications = v);
                sheetSetState(() {});
              },
            ),
            SwitchListTile(
              title: const Text('แจ้งปัญหาที่ต้องแก้ทันที'),
              value: actionNotifications,
              onChanged: (v) {
                setState(() => actionNotifications = v);
                sheetSetState(() {});
              },
            ),
          ],
        ),
      ),
    ),
  );

  void _appearanceSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => StatefulBuilder(
      builder: (context, sheetSetState) => Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, 4, Spacing.lg, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('หน้าตาแอป', style: Theme.of(context).textTheme.titleLarge),
            for (final option in ['ตามระบบ', 'สว่าง', 'มืด'])
              ListTile(
                leading: Icon(
                  _themeLabel(themeMode) == option
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _themeLabel(themeMode) == option
                      ? context.t.primary
                      : context.t.textSecondary,
                ),
                title: Text(option),
                onTap: () {
                  final value = switch (option) {
                    'ตามระบบ' => ThemeMode.system,
                    'สว่าง' => ThemeMode.light,
                    _ => ThemeMode.dark,
                  };
                  setState(() => themeMode = value);
                  widget.onThemeModeChanged?.call(value);
                  sheetSetState(() {});
                },
              ),
            SwitchListTile(
              title: const Text('ลดการเคลื่อนไหว'),
              value: reducedMotion,
              onChanged: (v) {
                setState(() => reducedMotion = v);
                widget.onReducedMotionChanged?.call(v);
                sheetSetState(() {});
              },
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _editProfile(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('แก้ไขชื่อโปรไฟล์'),
        content: TextField(
          key: const Key('profile-name-input'),
          controller: controller,
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'ชื่อที่ใช้แสดง'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    if (value?.trim().isNotEmpty == true) {
      widget.auth.updateLocalProfile(name: value);
      if (mounted) setState(() {});
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
  }

  void _timezoneSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'เขตเวลาสำหรับตั้งโพสต์',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final zone in const [
            'Asia/Bangkok',
            'Asia/Singapore',
            'Asia/Tokyo',
          ])
            ListTile(
              leading: Icon(
                widget.auth.account?.timezone == zone
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(zone),
              subtitle: Text(
                zone == 'Asia/Bangkok'
                    ? 'เวลาไทย (GMT+7)'
                    : zone == 'Asia/Singapore'
                    ? 'GMT+8'
                    : 'GMT+9',
              ),
              onTap: () {
                widget.auth.updateLocalProfile(timezone: zone);
                setState(() {});
                Navigator.pop(sheetContext);
              },
            ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );

  void _helpSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ศูนย์ช่วยเหลือ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            ExpansionTile(
              title: Text('รับคอนเทนต์จาก AI อย่างไร?'),
              children: [
                ListTile(
                  title: Text(
                    'เชื่อมแหล่ง AI หรือแชร์ไฟล์เข้ามาที่ AI Content Inbox แล้วเลือกสินค้าที่ต้องการปักตะกร้า',
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: Text('ทำไมต้องตรวจตะกร้าก่อนโพสต์?'),
              children: [
                ListTile(
                  title: Text(
                    'เพื่อยืนยันว่าสินค้ายังพร้อมขายและเป็นสินค้าที่ตั้งใจโปรโมต',
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: Text('แก้งานที่ส่งไม่สำเร็จอย่างไร?'),
              children: [
                ListTile(
                  title: Text(
                    'เปิดแท็บคอนเทนต์ เลือกงานที่มีสถานะต้องแก้ แล้วทำตามสาเหตุที่แสดง',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  void _privacySheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          0,
          Spacing.lg,
          Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ข้อมูลและความเป็นส่วนตัว',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const _PrivacyLine(
              icon: Icons.video_library_outlined,
              title: 'ไฟล์คอนเทนต์',
              detail: 'ใช้เพื่อเตรียม ตรวจ และส่งงานที่คุณอนุมัติ',
            ),
            const _PrivacyLine(
              icon: Icons.shopping_bag_outlined,
              title: 'ข้อมูลสินค้า',
              detail: 'ใช้เพื่อแสดงและตรวจสินค้าที่ปักตะกร้า',
            ),
            const _PrivacyLine(
              icon: Icons.link_outlined,
              title: 'บัญชีที่เชื่อม',
              detail: 'ยกเลิกการเชื่อมต่อได้จากหน้าโปรไฟล์ทุกเมื่อ',
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('เข้าใจแล้ว'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ออกจากระบบ?'),
        content: const Text('งานฉบับร่างและตารางเผยแพร่ยังคงอยู่ในบัญชี'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.t.error,
              foregroundColor: context.t.onPrimary,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
    if (ok == true) await widget.auth.signOut();
  }
}

String _themeLabel(ThemeMode value) => switch (value) {
  ThemeMode.system => 'ตามระบบ',
  ThemeMode.light => 'สว่าง',
  ThemeMode.dark => 'มืด',
};

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.onEdit,
  });
  final String name;
  final String email;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Spacing.md),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          context.t.surfaceContainer,
          context.t.primary.withValues(alpha: .08),
        ],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: context.t.border),
    ),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [context.t.primary, context.t.success],
            ),
          ),
          child: Text(
            name.characters.first.toUpperCase(),
            style: TextStyle(
              color: context.t.onPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(name, style: Theme.of(context).textTheme.titleLarge),
        if (email.isNotEmpty)
          Text(
            email,
            style: TextStyle(color: context.t.textSecondary, fontSize: 12),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            HapticFeedback.selectionClick();
            onEdit();
          },
          icon: const Icon(Icons.tune_rounded, size: 16),
          label: const Text('แก้ไขโปรไฟล์'),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: context.t.success.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: context.t.success.withValues(alpha: .28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, color: context.t.success, size: 16),
              const SizedBox(width: 5),
              const Flexible(
                child: Text(
                  'Relay Creator พร้อมใช้งาน',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(detail),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        color: context.t.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: context.t.surfaceContainer,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.lg),
      side: BorderSide(color: context.t.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1)
            Divider(height: 1, indent: 56, color: context.t.border),
        ],
      ],
    ),
  );
}

class _SettingsTile extends StatefulWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: pressed ? .985 : 1,
    duration: context.motion(RelayMotion.fast),
    child: Listener(
      onPointerDown: (_) => setState(() => pressed = true),
      onPointerUp: (_) => setState(() => pressed = false),
      onPointerCancel: (_) => setState(() => pressed = false),
      child: ListTile(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: context.t.textSecondary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Icon(widget.icon, size: 20, color: context.t.textSecondary),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(widget.subtitle, style: const TextStyle(fontSize: 11)),
        trailing: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: context.t.border),
          ),
          child: const Icon(Icons.chevron_right_rounded, size: 18),
        ),
      ),
    ),
  );
}

class _IntegrationPanel extends StatelessWidget {
  const _IntegrationPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i < children.length - 1) const SizedBox(width: 10),
        ],
      ],
    ),
  );
}

class _IntegrationTile extends StatefulWidget {
  const _IntegrationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_IntegrationTile> createState() => _IntegrationTileState();
}

class _IntegrationTileState extends State<_IntegrationTile> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: pressed ? .98 : 1,
    duration: context.motion(RelayMotion.fast),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        onHighlightChanged: (value) => setState(() => pressed = value),
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.color.withValues(alpha: .12),
                context.t.surfaceContainer,
              ],
            ),
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: widget.color.withValues(alpha: .34)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(widget.icon, color: widget.color, size: 21),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: context.t.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: widget.color, width: 2),
                          ),
                          child: Icon(
                            Icons.check,
                            size: 7,
                            color: widget.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.north_east_rounded, color: widget.color, size: 18),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.t.textSecondary,
                  fontSize: 10,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      widget.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SignOutAction extends StatefulWidget {
  const _SignOutAction({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  State<_SignOutAction> createState() => _SignOutActionState();
}

class _SignOutActionState extends State<_SignOutAction> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: pressed ? .98 : 1,
    duration: context.motion(RelayMotion.fast),
    child: Material(
      color: context.t.error.withValues(alpha: .045),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: context.t.error.withValues(alpha: .42)),
      ),
      child: InkWell(
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onHighlightChanged: (value) => setState(() => pressed = value),
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(Icons.logout_rounded, color: context.t.error, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ออกจากระบบ',
                  style: TextStyle(
                    color: context.t.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: context.t.error.withValues(alpha: .8),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
