import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../domain/connection.dart';
import 'connections_controller.dart';

/// หน้าเชื่อมบัญชีแพลตฟอร์ม
///
/// หน้านี้ต้องเสร็จก่อน Composer เพราะเป็นสิ่งที่ต้องใช้อัดวิดีโอสาธิต
/// ยื่น TikTok audit ซึ่งเป็น critical path ของโปรเจกต์
class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key, required this.controller});
  final ConnectionsController controller;

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          return Scaffold(
            appBar: AppBar(title: const Text('เชื่อมต่อบัญชี')),
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: c.load,
                child: ListView(
                  padding: const EdgeInsets.all(Spacing.md),
                  children: [
                    Text(
                      'เชื่อมบัญชีที่ต้องการให้ระบบโพสต์ให้',
                      style: TextStyle(color: context.t.textSecondary),
                    ),
                    const SizedBox(height: Spacing.lg),
                    if (c.error != null) ...[
                      _ErrorBanner(message: c.error!),
                      const SizedBox(height: Spacing.md),
                    ],
                    _TikTokCard(controller: c),
                    const SizedBox(height: Spacing.lg),
                    _ComingSoon(),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _TikTokCard extends StatelessWidget {
  const _TikTokCard({required this.controller});
  final ConnectionsController controller;

  @override
  Widget build(BuildContext context) {
    final list = controller.list;
    final connection = list?.tiktok;
    final serverReady = list?.tiktokEnabled ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Spacing.sm),
                  decoration: BoxDecoration(
                    color: context.t.surface,
                    borderRadius: BorderRadius.circular(Radii.sm),
                    border: Border.all(color: context.t.border),
                  ),
                  child: Icon(Icons.music_note_rounded,
                      color: context.t.textPrimary),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TikTok',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (connection != null && connection.displayName.isNotEmpty)
                        Text(
                          connection.displayName,
                          style: TextStyle(color: context.t.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (connection != null) _StatusChip(status: connection.status),
              ],
            ),

            if (connection != null) ...[
              const SizedBox(height: Spacing.md),
              _Capabilities(caps: connection.capabilities),
            ],

            const SizedBox(height: Spacing.md),

            if (!serverReady)
              // บอกเหตุผลตั้งแต่ตอนนี้ ดีกว่าปล่อยให้กดแล้วเจอ 503
              _Hint(
                icon: Icons.info_outline_rounded,
                text: 'ระบบยังไม่ได้ตั้งค่า TikTok — ยังเชื่อมต่อไม่ได้',
              )
            else if (connection == null)
              FilledButton.icon(
                onPressed: controller.connecting ? null : controller.connectTikTok,
                icon: controller.connecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_rounded),
                label: Text(
                  controller.connecting ? 'กำลังเชื่อมต่อ…' : 'เชื่อมต่อ TikTok',
                ),
              )
            else
              Row(
                children: [
                  if (!connection.status.isUsable)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: controller.connecting
                            ? null
                            : controller.connectTikTok,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('เชื่อมต่อใหม่'),
                      ),
                    ),
                  if (!connection.status.isUsable)
                    const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.loading
                          ? null
                          : () => _confirmDisconnect(context, connection),
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('ยกเลิกการเชื่อมต่อ'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDisconnect(
    BuildContext context,
    Connection connection,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยกเลิกการเชื่อมต่อ?'),
        content: const Text(
          'โพสต์ที่ตั้งเวลาไว้กับบัญชีนี้จะโพสต์ไม่ได้ '
          'จนกว่าคุณจะเชื่อมต่อใหม่',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ไม่ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ยกเลิกการเชื่อมต่อ'),
          ),
        ],
      ),
    );

    if (ok ?? false) await controller.disconnect(connection.id);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.isUsable ? context.t.success : context.t.warning;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm, vertical: Spacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.isUsable ? Icons.check_circle : Icons.error_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: Spacing.xs),
          Text(
            status.isUsable ? 'เชื่อมแล้ว' : 'ต้องเชื่อมใหม่',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// แสดงข้อจำกัดจริงของบัญชี ไม่ใช่ค่าที่แอปเดาเอง
class _Capabilities extends StatelessWidget {
  const _Capabilities({required this.caps});
  final ConnectionCapabilities caps;

  @override
  Widget build(BuildContext context) {
    if (caps.isEmpty) {
      return _Hint(
        icon: Icons.hourglass_empty_rounded,
        text: 'ยังไม่ได้ดึงข้อมูลบัญชี — จะอัปเดตเมื่อเปิดหน้าสร้างโพสต์',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!caps.canPublishPublic)
          // ข้อนี้สำคัญมาก: ก่อนแอปผ่าน TikTok audit จะโพสต์ได้แค่ "เฉพาะฉัน"
          // ต้องบอกล่วงหน้า ไม่ใช่ให้ผู้ใช้ไปเจอตอนกดโพสต์แล้วงงว่าทำไมไม่มีคนเห็น
          _Hint(
            icon: Icons.lock_outline_rounded,
            text: 'ตอนนี้โพสต์ได้เฉพาะแบบ "เฉพาะฉัน" เท่านั้น\n'
                'จะโพสต์สาธารณะได้เมื่อแอปผ่านการตรวจสอบจาก TikTok',
            emphasis: true,
          ),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.xs,
          children: [
            if (caps.maxVideoDurationSec > 0)
              _Fact('วิดีโอยาวสุด ${_minutes(caps.maxVideoDurationSec)}'),
            if (caps.maxPostsPerDay > 0)
              _Fact('โพสต์ได้ ${caps.maxPostsPerDay} คลิป/วัน'),
          ],
        ),
      ],
    );
  }

  String _minutes(int seconds) =>
      seconds >= 60 ? '${(seconds / 60).round()} นาที' : '$seconds วินาที';
}

class _Fact extends StatelessWidget {
  const _Fact(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm, vertical: Spacing.xs),
        decoration: BoxDecoration(
          color: context.t.surface,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: context.t.border),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 12, color: context.t.textSecondary)),
      );
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text, this.emphasis = false});
  final IconData icon;
  final String text;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final color = emphasis ? context.t.warning : context.t.textSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(text, style: TextStyle(color: color, fontSize: 13)),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: context.t.error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: context.t.error, size: 20),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(message, style: TextStyle(color: context.t.error)),
              ),
            ),
          ],
        ),
      );
}

class _ComingSoon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('เร็ว ๆ นี้',
                style: TextStyle(color: context.t.textSecondary, fontSize: 13)),
            const SizedBox(height: Spacing.sm),
            for (final name in ['Facebook', 'Instagram', 'YouTube'])
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.lock_clock_rounded,
                        size: 16, color: context.t.textSecondary),
                    const SizedBox(width: Spacing.sm),
                    Text(name,
                        style: TextStyle(color: context.t.textSecondary)),
                  ],
                ),
              ),
          ],
        ),
      );
}
