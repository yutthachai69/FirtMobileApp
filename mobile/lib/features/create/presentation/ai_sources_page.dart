import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../showcase/domain/showcase_product.dart';
import '../domain/ai_source.dart';
import 'ai_sources_controller.dart';
import 'publish_review_page.dart';

class AiSourcesPage extends StatefulWidget {
  const AiSourcesPage({super.key, this.product, this.controller});

  final ShowcaseProduct? product;

  /// ฉีดจากเทสเพื่อคุมเวลาเอง ปกติหน้าเพจสร้างเอง
  final AiSourcesController? controller;

  @override
  State<AiSourcesPage> createState() => _AiSourcesPageState();
}

class _AiSourcesPageState extends State<AiSourcesPage> {
  late final AiSourcesController _c = widget.controller ?? AiSourcesController();
  bool get _ownsController => widget.controller == null;

  @override
  void dispose() {
    if (_ownsController) _c.dispose();
    super.dispose();
  }

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
      child: ListenableBuilder(
        listenable: _c,
        builder: (context, _) => ListView(
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
            _SourcesSection(
              controller: _c,
              onManage: () => _showConnections(context),
            ),
            const SizedBox(height: Spacing.lg),
            _InboxSection(
              controller: _c,
              onOpen: (item) => _openContent(context, item),
            ),
            const SizedBox(height: Spacing.lg),
            OutlinedButton.icon(
              onPressed: () => _showImportHelp(context),
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('ส่งคลิปเข้า RelayContent ด้วย Share'),
            ),
          ],
        ),
      ),
    ),
  );

  void _openContent(BuildContext context, InboxItem item) {
    final product = widget.product;
    if (product == null) {
      _toast('เลือกสินค้าที่ต้องการปักตะกร้าก่อน');
      context.go('/showcase');
      return;
    }
    context.go(
      '/create/publish',
      extra: PublishReviewArgs(
        product: product,
        mediaName: item.title,
        durationSec: item.durationSec,
        sourceLabel: 'AI Content Inbox · ${item.sourceName}',
      ),
    );
  }

  Future<void> _connect(String id) async {
    await _c.connect(id);
    if (!mounted) return;
    final source = _c.sourceById(id);
    _toast(
      source.status == SourceStatus.needsAttention
          ? 'เชื่อม ${source.name} แล้ว — ตรวจข้อจำกัดก่อนใช้งาน'
          : 'เชื่อม ${source.name} แล้ว',
    );
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _showConnections(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => ListenableBuilder(
      listenable: _c,
      builder: (context, _) => Padding(
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
              'RelayContent จะขอสิทธิ์อ่านเฉพาะงานที่คุณเลือกนำเข้า '
              'ไม่ขอ API key และไม่สร้างงานแทนโดยอัตโนมัติ',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.md),
            for (final source in _c.sources)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.hub_outlined),
                title: Text(source.name),
                subtitle: source.note != null
                    ? Text(source.note!, style: const TextStyle(fontSize: 12))
                    : null,
                trailing: source.isConnected
                    ? TextButton(
                        onPressed: () {
                          _c.disconnect(source.id);
                          _toast('ตัดการเชื่อม ${source.name} แล้ว');
                        },
                        child: const Text('ตัดการเชื่อม'),
                      )
                    : _c.busySourceId == source.id
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(72, 40),
                        ),
                        onPressed: () => _connect(source.id),
                        child: const Text('เชื่อม'),
                      ),
              ),
          ],
        ),
      ),
    ),
  );

  void _showImportHelp(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const Padding(
      padding: EdgeInsets.fromLTRB(Spacing.lg, 4, Spacing.lg, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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

class _SourcesSection extends StatelessWidget {
  const _SourcesSection({required this.controller, required this.onManage});
  final AiSourcesController controller;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final warnings = controller.sources
        .where((s) => s.status == SourceStatus.needsAttention && s.note != null)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'แหล่งคอนเทนต์ · เชื่อมแล้ว ${controller.connectedCount}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(onPressed: onManage, child: const Text('จัดการ')),
          ],
        ),
        SizedBox(
          height: 108,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final source in controller.sources)
                _SourceChip(
                  source: source,
                  busy: controller.busySourceId == source.id,
                  onTap: () => source.isConnected
                      ? onManage()
                      : controller.connect(source.id),
                ),
            ],
          ),
        ),
        for (final source in warnings) ...[
          const SizedBox(height: 8),
          _CapabilityNote(text: '${source.name}: ${source.note}'),
        ],
      ],
    );
  }
}

class _InboxSection extends StatelessWidget {
  const _InboxSection({required this.controller, required this.onOpen});
  final AiSourcesController controller;
  final void Function(InboxItem) onOpen;

  @override
  Widget build(BuildContext context) {
    final importing = controller.importingItems;
    final failed = controller.failedItems;
    final ready = controller.readyItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'คอนเทนต์ล่าสุด',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (controller.syncing)
              const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                tooltip: 'ซิงก์ใหม่',
                onPressed: controller.sync,
                icon: const Icon(Icons.sync_rounded),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (controller.isEmpty)
          _EmptyInbox()
        else ...[
          for (final item in failed) ...[
            _FailedItem(
              item: item,
              onRetry: () => controller.retry(item.id),
              onDismiss: () => controller.dismiss(item.id),
            ),
            const SizedBox(height: 10),
          ],
          for (final item in importing) ...[
            _ImportingItem(item: item),
            const SizedBox(height: 10),
          ],
          for (final item in ready) ...[
            _ReadyItem(item: item, onTap: () => onOpen(item)),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
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

class _CapabilityNote extends StatelessWidget {
  const _CapabilityNote({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: context.t.warning.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(Radii.md),
      border: Border.all(color: context.t.warning.withValues(alpha: .4)),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 18, color: context.t.warning),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.source,
    required this.busy,
    required this.onTap,
  });
  final AiSource source;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final connected = source.isConnected;
    final attention = source.status == SourceStatus.needsAttention;
    final accent = attention
        ? context.t.warning
        : connected
        ? context.t.primary
        : context.t.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Container(
          width: 122,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.t.surfaceContainer,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: connected ? accent : context.t.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.hub_outlined, size: 19, color: accent),
                  const Spacer(),
                  if (busy)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      attention
                          ? Icons.error_outline_rounded
                          : connected
                          ? Icons.check_circle
                          : Icons.add_circle_outline,
                      size: 16,
                      color: attention
                          ? context.t.warning
                          : connected
                          ? context.t.success
                          : context.t.textSecondary,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                source.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                connected
                    ? (attention ? 'ต้องตรวจ' : 'เชื่อมแล้ว')
                    : 'แตะเพื่อเชื่อม',
                style: TextStyle(fontSize: 10, color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadyItem extends StatelessWidget {
  const _ReadyItem({required this.item, required this.onTap});
  final InboxItem item;
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
                  context.t.primary.withValues(alpha: .35),
                ],
              ),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(
              Icons.play_circle_fill,
              color: context.t.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(
                  item.sourceName,
                  style: TextStyle(color: context.t.primary, fontSize: 11),
                ),
                Text(
                  'พร้อมใช้ · ${item.durationSec} วินาที'
                  '${item.vertical ? '' : ' · 16:9 ต้องครอป'}',
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

class _ImportingItem extends StatelessWidget {
  const _ImportingItem({required this.item});
  final InboxItem item;
  @override
  Widget build(BuildContext context) {
    final percent = (item.progress * 100).round();
    return _Panel(
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              value: item.progress,
              color: context.t.warning,
              backgroundColor: context.t.warning.withValues(alpha: .12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'กำลังรับไฟล์จาก ${item.sourceName} · $percent%',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedItem extends StatelessWidget {
  const _FailedItem({
    required this.item,
    required this.onRetry,
    required this.onDismiss,
  });
  final InboxItem item;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: context.t.error.withValues(alpha: .5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline_rounded, color: context.t.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'นำเข้าไม่สำเร็จ · ${item.failureReason ?? 'ไม่ทราบสาเหตุ'}',
          style: TextStyle(color: context.t.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('ลองใหม่'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onDismiss, child: const Text('ลบออก')),
          ],
        ),
      ],
    ),
  );
}

class _EmptyInbox extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 36,
          color: context.t.textSecondary,
        ),
        const SizedBox(height: 8),
        const Text(
          'ยังไม่มีคอนเทนต์ใน Inbox',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'เชื่อมบัญชี AI หรือ Share คลิปเข้ามาเพื่อเริ่มผูกสินค้า',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.t.textSecondary, fontSize: 12),
        ),
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
