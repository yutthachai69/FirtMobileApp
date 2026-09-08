import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../showcase/domain/showcase_product.dart';
import '../../showcase/presentation/product_artwork.dart';
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
  late final AiSourcesController _c =
      widget.controller ?? AiSourcesController();
  final Set<String> _selectedItems = {};
  bool _selecting = false;
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
              product: widget.product,
              onOpen: _openPreview,
              selecting: _selecting,
              selectedItems: _selectedItems,
              onStartSelecting: () => setState(() => _selecting = true),
              onCancelSelecting: () => setState(() {
                _selecting = false;
                _selectedItems.clear();
              }),
              onToggle: (id) => setState(() {
                if (!_selectedItems.add(id)) _selectedItems.remove(id);
              }),
              onSelectAll: () => setState(() {
                _selectedItems
                  ..clear()
                  ..addAll(_c.readyItems.map((item) => item.id));
              }),
              onDeleteSelected: _deleteSelected,
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

  Future<void> _openPreview(InboxItem item) async {
    final useContent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.black,
      builder: (_) => _InboxPreviewSheet(item: item, product: widget.product),
    );
    if (useContent == true && mounted) _openContent(context, item);
  }

  Future<void> _deleteSelected() async {
    if (_selectedItems.isEmpty) return;
    final count = _selectedItems.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: context.t.error),
        title: Text('ลบคอนเทนต์ $count รายการ?'),
        content: const Text(
          'รายการจะถูกนำออกจาก Inbox เท่านั้น ไฟล์ต้นฉบับในเครื่องมือ AI จะไม่ถูกลบ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('เก็บไว้'),
          ),
          FilledButton(
            key: const Key('confirm-delete-inbox-items'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบจาก Inbox'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    for (final id in _selectedItems) {
      _c.dismiss(id);
    }
    setState(() {
      _selectedItems.clear();
      _selecting = false;
    });
    _toast('ลบ $count รายการออกจาก Inbox แล้ว');
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
  const _InboxSection({
    required this.controller,
    required this.product,
    required this.onOpen,
    required this.selecting,
    required this.selectedItems,
    required this.onStartSelecting,
    required this.onCancelSelecting,
    required this.onToggle,
    required this.onSelectAll,
    required this.onDeleteSelected,
  });
  final AiSourcesController controller;
  final ShowcaseProduct? product;
  final void Function(InboxItem) onOpen;
  final bool selecting;
  final Set<String> selectedItems;
  final VoidCallback onStartSelecting;
  final VoidCallback onCancelSelecting;
  final ValueChanged<String> onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onDeleteSelected;

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
            Expanded(
              child: Text(
                selecting
                    ? 'เลือกแล้ว ${selectedItems.length} รายการ'
                    : 'คอนเทนต์ล่าสุด',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (ready.isNotEmpty)
              TextButton(
                key: const Key('toggle-inbox-selection'),
                onPressed: selecting ? onCancelSelecting : onStartSelecting,
                child: Text(selecting ? 'ยกเลิก' : 'เลือก'),
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
        if (selecting) ...[
          _BulkActions(
            selectedCount: selectedItems.length,
            allSelected: selectedItems.length == ready.length,
            onSelectAll: onSelectAll,
            onDelete: onDeleteSelected,
          ),
          const SizedBox(height: 10),
        ],
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
            _ReadyItem(
              item: item,
              product: product,
              selecting: selecting,
              selected: selectedItems.contains(item.id),
              onTap: () => selecting ? onToggle(item.id) : onOpen(item),
              onLongPress: () {
                if (!selecting) onStartSelecting();
                onToggle(item.id);
              },
            ),
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
            border: Border.all(color: connected ? accent : context.t.border),
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
  const _ReadyItem({
    required this.item,
    required this.product,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });
  final InboxItem item;
  final ShowcaseProduct? product;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  @override
  Widget build(BuildContext context) => _Panel(
    child: InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        children: [
          if (selecting) ...[
            Checkbox(
              key: Key('select-inbox-${item.id}'),
              value: selected,
              onChanged: (_) => onTap(),
            ),
            const SizedBox(width: 4),
          ],
          _InboxArtwork(item: item, product: product, width: 64, height: 82),
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
          Icon(
            selecting
                ? (selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded)
                : Icons.chevron_right_rounded,
            color: selected ? context.t.primary : null,
          ),
        ],
      ),
    ),
  );
}

class _BulkActions extends StatelessWidget {
  const _BulkActions({
    required this.selectedCount,
    required this.allSelected,
    required this.onSelectAll,
    required this.onDelete,
  });

  final int selectedCount;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
    decoration: BoxDecoration(
      color: context.t.primary.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(Radii.md),
      border: Border.all(color: context.t.primary.withValues(alpha: .3)),
    ),
    child: Row(
      children: [
        TextButton.icon(
          key: const Key('select-all-inbox'),
          onPressed: allSelected ? null : onSelectAll,
          icon: const Icon(Icons.select_all_rounded),
          label: Text(allSelected ? 'เลือกทั้งหมดแล้ว' : 'เลือกทั้งหมด'),
        ),
        const Spacer(),
        IconButton(
          key: const Key('delete-selected-inbox'),
          tooltip: 'ลบรายการที่เลือก',
          onPressed: selectedCount == 0 ? null : onDelete,
          icon: Icon(Icons.delete_outline_rounded, color: context.t.error),
        ),
      ],
    ),
  );
}

class _InboxArtwork extends StatelessWidget {
  const _InboxArtwork({
    required this.item,
    required this.product,
    this.width,
    this.height,
    this.borderRadius = Radii.md,
    this.showControls = true,
  });

  final InboxItem item;
  final ShowcaseProduct? product;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool showControls;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (product != null)
          ProductArtwork(product: product!, borderRadius: borderRadius)
        else
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.t.surfaceElevated,
                  context.t.primary.withValues(alpha: .45),
                ],
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0x99000000)],
            ),
          ),
        ),
        if (showControls) ...[
          Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          Positioned(
            left: 5,
            bottom: 4,
            child: Text(
              '${item.durationSec}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _InboxPreviewSheet extends StatefulWidget {
  const _InboxPreviewSheet({required this.item, required this.product});

  final InboxItem item;
  final ShowcaseProduct? product;

  @override
  State<_InboxPreviewSheet> createState() => _InboxPreviewSheetState();
}

class _InboxPreviewSheetState extends State<_InboxPreviewSheet> {
  bool playing = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        _InboxArtwork(
          item: widget.item,
          product: widget.product,
          borderRadius: 0,
          showControls: false,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x55000000), Color(0x22000000), Color(0xEE000000)],
              stops: [0, .5, 1],
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: IconButton.filledTonal(
            key: const Key('close-inbox-preview'),
            tooltip: 'ปิดตัวอย่าง',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        Positioned(
          top: 16,
          right: 18,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              widget.item.vertical ? '9:16 พร้อมใช้' : '16:9 ต้องครอป',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
        Center(
          child: IconButton.filled(
            key: const Key('inbox-preview-play-pause'),
            onPressed: () => setState(() => playing = !playing),
            iconSize: 40,
            icon: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${widget.item.sourceName} · ${widget.item.durationSec} วินาที',
                style: const TextStyle(color: Colors.white70),
              ),
              if (widget.product != null) ...[
                const SizedBox(height: 7),
                Text(
                  'จะปักตะกร้า: ${widget.product!.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('use-inbox-content'),
                  onPressed: () => Navigator.pop(context, true),
                  icon: Icon(
                    widget.product == null
                        ? Icons.add_shopping_cart_rounded
                        : Icons.arrow_forward_rounded,
                  ),
                  label: Text(
                    widget.product == null
                        ? 'เลือกสินค้าที่จะปักตะกร้า'
                        : 'ใช้คอนเทนต์นี้',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
        Icon(Icons.inbox_outlined, size: 36, color: context.t.textSecondary),
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
