import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../showcase/domain/showcase_product.dart';

class AiSourcesPage extends StatefulWidget {
  const AiSourcesPage({super.key, this.product});
  final ShowcaseProduct? product;

  @override
  State<AiSourcesPage> createState() => _AiSourcesPageState();
}

class _AiSourcesPageState extends State<AiSourcesPage> {
  final Set<String> connected = {'Google Flow'};

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('รับคอนเทนต์จาก AI'),
      actions: [
        IconButton(
          tooltip: 'วิธีส่งเข้า RelayContent',
          onPressed: () => _showImportHelp(context),
          icon: const Icon(Icons.help_outline_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Spacing.md, 4, Spacing.md, 110),
        children: [
          Text(
            'AI Content Inbox',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'รวมคลิปจากเครื่องมือที่คุณใช้อยู่ แล้วส่งต่อไปผูกสินค้าและเผยแพร่',
            style: TextStyle(color: context.t.textSecondary, height: 1.45),
          ),
          const SizedBox(height: Spacing.md),
          if (widget.product != null)
            _ProductContext(product: widget.product!)
          else
            _NeedProduct(onTap: () => context.go('/showcase')),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'แหล่งคอนเทนต์',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => _showConnections(context),
                child: const Text('จัดการ'),
              ),
            ],
          ),
          SizedBox(
            height: 86,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _SourceChip(
                  name: 'Google Flow',
                  icon: Icons.auto_awesome_rounded,
                  connected: connected.contains('Google Flow'),
                  onTap: () => _toggleSource('Google Flow'),
                ),
                _SourceChip(
                  name: 'Sora',
                  icon: Icons.blur_circular_rounded,
                  connected: connected.contains('Sora'),
                  onTap: () => _toggleSource('Sora'),
                ),
                _SourceChip(
                  name: 'Runway',
                  icon: Icons.movie_filter_outlined,
                  connected: connected.contains('Runway'),
                  onTap: () => _toggleSource('Runway'),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'คอนเทนต์ล่าสุด',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'ซิงก์ใหม่',
                onPressed: () => _toast('ซิงก์ Inbox ตัวอย่างแล้ว'),
                icon: const Icon(Icons.sync_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InboxItem(
            title: 'Serum close-up · Golden hour',
            source: 'Google Flow',
            time: 'พร้อมใช้ · 30 วินาที',
            color: context.t.primary,
            onTap: () => _openContent(context),
          ),
          const SizedBox(height: 10),
          _InboxItem(
            title: 'Unboxing vertical product shot',
            source: 'Sora',
            time: 'นำเข้าเมื่อ 18 นาทีที่แล้ว',
            color: context.t.creative,
            onTap: () => _openContent(context),
          ),
          const SizedBox(height: 10),
          _ProcessingItem(color: context.t.warning),
          const SizedBox(height: Spacing.lg),
          OutlinedButton.icon(
            onPressed: () => _showImportHelp(context),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('ส่งคลิปเข้า RelayContent ด้วย Share'),
          ),
        ],
      ),
    ),
  );

  void _openContent(BuildContext context) {
    final product = widget.product;
    if (product == null) {
      _toast('เลือกสินค้าที่ต้องการปักตะกร้าก่อน');
      context.go('/showcase');
      return;
    }
    context.go('/create/publish', extra: product);
  }

  void _toggleSource(String name) {
    if (connected.contains(name)) {
      _toast('$name เชื่อมต่ออยู่แล้ว');
      return;
    }
    setState(() => connected.add(name));
    _toast('เชื่อม $name ในโหมดตัวอย่างแล้ว');
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _showConnections(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 4, Spacing.lg, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'เชื่อมแหล่งสร้าง AI',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'RelayContent จะขอสิทธิ์อ่านเฉพาะงานที่คุณเลือกนำเข้า ไม่ขอ API key และไม่สร้างงานแทนโดยอัตโนมัติ',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.md),
          for (final name in ['Google Flow', 'Sora', 'Runway'])
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: Text(name),
              trailing: connected.contains(name)
                  ? Icon(Icons.check_circle, color: context.t.success)
                  : const Icon(Icons.add_circle_outline),
              onTap: () {
                Navigator.pop(context);
                _toggleSource(name);
              },
            ),
        ],
      ),
    ),
  );

  void _showImportHelp(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 4, Spacing.lg, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            'นำเข้าได้ 3 ทาง',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12),
          ListTile(
            leading: Icon(Icons.link_rounded),
            title: Text('เชื่อมบัญชี AI'),
            subtitle: Text('ดึงเฉพาะงานที่ผู้ใช้เลือก'),
          ),
          ListTile(
            leading: Icon(Icons.ios_share_rounded),
            title: Text('Share to RelayContent'),
            subtitle: Text('แชร์คลิปจากแอปต้นทางเข้ามาโดยตรง'),
          ),
          ListTile(
            leading: Icon(Icons.upload_file_outlined),
            title: Text('เลือกไฟล์จากเครื่อง'),
            subtitle: Text('ทางสำรองเมื่อผู้ให้บริการยังเชื่อมตรงไม่ได้'),
          ),
        ],
      ),
    ),
  );
}

class _ProductContext extends StatelessWidget {
  const _ProductContext({required this.product});
  final ShowcaseProduct product;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      children: [
        Icon(Icons.shopping_bag_outlined, color: context.t.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'จะปักตะกร้า: ${product.name}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: () => context.go('/showcase'),
          child: const Text('เปลี่ยน'),
        ),
      ],
    ),
  );
}

class _NeedProduct extends StatelessWidget {
  const _NeedProduct({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      children: [
        Icon(Icons.add_shopping_cart_rounded, color: context.t.warning),
        const SizedBox(width: 10),
        const Expanded(child: Text('เลือกสินค้าที่จะปักตะกร้ากับคอนเทนต์')),
        TextButton(onPressed: onTap, child: const Text('เลือก')),
      ],
    ),
  );
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.name,
    required this.icon,
    required this.connected,
    required this.onTap,
  });
  final String name;
  final IconData icon;
  final bool connected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 9),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        width: 118,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.t.surfaceContainer,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: connected ? context.t.primary : context.t.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: connected
                      ? context.t.primary
                      : context.t.textSecondary,
                ),
                const Spacer(),
                Icon(
                  connected ? Icons.check_circle : Icons.add_circle_outline,
                  size: 16,
                  color: connected
                      ? context.t.success
                      : context.t.textSecondary,
                ),
              ],
            ),
            const Spacer(),
            Text(
              name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InboxItem extends StatelessWidget {
  const _InboxItem({
    required this.title,
    required this.source,
    required this.time,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String source;
  final String time;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _Panel(
    child: InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 64,
            height: 82,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.t.surfaceElevated,
                  color.withValues(alpha: .35),
                ],
              ),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(Icons.play_circle_fill, color: color, size: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(source, style: TextStyle(color: color, fontSize: 11)),
                Text(
                  time,
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
  );
}

class _ProcessingItem extends StatelessWidget {
  const _ProcessingItem({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: CircularProgressIndicator(
            value: .68,
            color: color,
            backgroundColor: color.withValues(alpha: .12),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lifestyle product montage',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'กำลังรับไฟล์จาก Runway · 68%',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        const Icon(Icons.more_vert_rounded),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: context.t.border),
    ),
    child: child,
  );
}
