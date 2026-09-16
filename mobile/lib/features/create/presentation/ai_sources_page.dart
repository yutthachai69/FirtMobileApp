import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../showcase/domain/showcase_product.dart';
import '../../showcase/presentation/product_artwork.dart';
import '../domain/ai_source.dart';
import 'ai_sources_controller.dart';
import 'publish_review_page.dart';
import 'widgets/synaptic_beam_connect_tile.dart';

class AiSourcesPage extends StatefulWidget {
  const AiSourcesPage({
    super.key,
    this.product,
    this.controller,
    this.products,
  });

  final ShowcaseProduct? product;
  final List<ShowcaseProduct>? products;

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
  int _relayRun = 0;
  int _sourceRelayRun = 0;
  String? _arrivingSource;
  Timer? _arrivalDismissTimer;
  late ShowcaseProduct? _selectedProduct = widget.product;
  bool get _ownsController => widget.controller == null;

  @override
  void didUpdateWidget(covariant AiSourcesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product?.id != widget.product?.id) {
      _selectedProduct = widget.product;
    }
  }

  @override
  void dispose() {
    _arrivalDismissTimer?.cancel();
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
          onPressed: _showImportHelp,
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
            _RelayFlowPanel(
              run: _relayRun,
              syncing: _c.syncing,
              importingCount: _c.importingItems.length,
              readyCount: _c.readyItems.length,
            ),
            const SizedBox(height: Spacing.md),
            AnimatedSwitcher(
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 320),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: .97, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: _selectedProduct != null
                  ? _ProductContext(
                      key: ValueKey(_selectedProduct!.id),
                      product: _selectedProduct!,
                      onTap: _showProductPicker,
                    )
                  : _NeedProduct(
                      key: const ValueKey('no-product'),
                      onTap: _showProductPicker,
                    ),
            ),
            const SizedBox(height: Spacing.lg),
            _SourcesSection(
              controller: _c,
              onManage: () => _showConnections(context),
              onConnect: _connect,
            ),
            AnimatedSwitcher(
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.topCenter,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: _arrivingSource == null
                  ? const SizedBox.shrink()
                  : Padding(
                      key: ValueKey(_sourceRelayRun),
                      padding: const EdgeInsets.only(top: 10),
                      child: _SourceArrivalBanner(sourceName: _arrivingSource!),
                    ),
            ),
            const SizedBox(height: Spacing.lg),
            _InboxSection(
              controller: _c,
              product: _selectedProduct,
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
              onSync: _syncInbox,
            ),
            const SizedBox(height: Spacing.lg),
            OutlinedButton.icon(
              onPressed: _showImportHelp,
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('ส่งคลิปเข้า RelayContent ด้วย Share'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _openContent(InboxItem item) async {
    var product = _selectedProduct;
    if (product == null) {
      product = await _showProductPicker();
      if (product == null || !mounted) return;
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
      builder: (_) => _InboxPreviewSheet(item: item, product: _selectedProduct),
    );
    if (useContent == true && mounted) await _openContent(item);
  }

  Future<ShowcaseProduct?> _showProductPicker() async {
    final product = await showModalBottomSheet<ShowcaseProduct>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ProductPickerSheet(
        current: _selectedProduct,
        products: widget.products ?? ShowcaseProduct.available,
      ),
    );
    if (product == null || !mounted) return null;
    HapticFeedback.mediumImpact();
    setState(() => _selectedProduct = product);
    return product;
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
    if (_c.busySourceId != null || _c.sourceById(id).isConnected) return;
    HapticFeedback.selectionClick();
    await _c.connect(id);
    if (!mounted) return;
    final source = _c.sourceById(id);
    final run = ++_sourceRelayRun;
    setState(() => _arrivingSource = source.name);
    HapticFeedback.mediumImpact();
    _toast(
      source.status == SourceStatus.needsAttention
          ? 'เชื่อม ${source.name} แล้ว — ตรวจข้อจำกัดก่อนใช้งาน'
          : 'เชื่อม ${source.name} แล้ว',
    );
    _arrivalDismissTimer?.cancel();
    _arrivalDismissTimer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted || run != _sourceRelayRun) return;
      setState(() => _arrivingSource = null);
    });
  }

  /// ยืนยันก่อนเริ่มแอนิเมชันตัดการเชื่อม — ไม่แตะสถานะจริง
  Future<bool> _confirmDisconnect(AiSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.link_off_rounded, color: context.t.error),
        title: Text('ตัดการเชื่อม ${source.name}?'),
        content: const Text(
          'ระบบจะหยุดรับงานใหม่จากแหล่งนี้ แต่งานที่เข้ามาแล้วจะยังอยู่ใน Inbox',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('เชื่อมไว้ก่อน'),
          ),
          FilledButton.icon(
            key: const Key('confirm-disconnect-source'),
            style: FilledButton.styleFrom(
              backgroundColor: context.t.error,
              foregroundColor: context.t.surface,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.link_off_rounded),
            label: const Text('ตัดการเชื่อม'),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  /// เรียกหลังแอนิเมชันตัดการเชื่อมของ [SynapticBeamConnectTile] เล่นจบ
  /// เพื่อผลักสถานะจริงและแจ้งผลลัพธ์
  Future<void> _disconnect(AiSource source) async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _c.disconnect(source.id);
    _toast('ตัดการเชื่อม ${source.name} แล้ว · งานเดิมยังอยู่ใน Inbox');
  }

  Future<void> _syncInbox() async {
    if (_c.syncing) return;
    HapticFeedback.selectionClick();
    setState(() => _relayRun++);
    await _c.sync();
    if (!mounted) return;
    HapticFeedback.lightImpact();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _showConnections(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
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
            for (final source in _c.sources) ...[
              SynapticBeamConnectTile(
                key: ValueKey('beam-source-${source.id}'),
                sourceId: source.id,
                name: source.name,
                icon: Icons.hub_outlined,
                isConnected: source.isConnected,
                constraintNote: source.note,
                onConnect: () => _connect(source.id),
                confirmDisconnect: () => _confirmDisconnect(source),
                onDisconnect: () => _disconnect(source),
              ),
              const SizedBox(height: Spacing.sm),
            ],
          ],
        ),
      ),
    ),
  );

  Future<void> _showImportHelp() async {
    final method = await showModalBottomSheet<_ImportMethod>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ImportActionSheet(),
    );
    if (!mounted || method == null) return;
    HapticFeedback.selectionClick();

    switch (method) {
      case _ImportMethod.connect:
        _showConnections(context);
      case _ImportMethod.share:
        _showShareGuide();
      case _ImportMethod.file:
        context.go('/create/upload', extra: _selectedProduct);
    }
  }

  void _showShareGuide() => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ShareGuideSheet(),
  );
}

enum _ImportMethod { connect, share, file }

class _ImportActionSheet extends StatelessWidget {
  const _ImportActionSheet();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return SafeArea(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: t.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.move_to_inbox_rounded, color: t.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เลือกวิธีนำเข้าคอนเทนต์',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text('แต่ละวิธีพาคุณไปทำต่อได้ทันที'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            _ImportActionTile(
              actionKey: const Key('import-via-ai-connection'),
              icon: Icons.hub_outlined,
              color: t.primary,
              eyebrow: 'AUTO SYNC',
              title: 'เชื่อมบัญชี AI',
              subtitle: 'ตั้งค่าแหล่งสร้าง แล้วดึงงานที่คุณเลือกเข้ามา',
              onTap: () => Navigator.pop(context, _ImportMethod.connect),
            ),
            const SizedBox(height: 10),
            _ImportActionTile(
              actionKey: const Key('import-via-share'),
              icon: Icons.ios_share_rounded,
              color: t.success,
              eyebrow: 'FASTEST',
              title: 'Share to RelayContent',
              subtitle: 'แชร์คลิปจากแอปต้นทางเข้ากล่องนี้โดยตรง',
              onTap: () => Navigator.pop(context, _ImportMethod.share),
            ),
            const SizedBox(height: 10),
            _ImportActionTile(
              actionKey: const Key('import-via-file'),
              icon: Icons.upload_file_rounded,
              color: t.warning,
              eyebrow: 'MANUAL',
              title: 'เลือกไฟล์จากเครื่อง',
              subtitle: 'เปิดขั้นตอนเลือกวิดีโอและอัปโหลดด้วยตัวเอง',
              onTap: () => Navigator.pop(context, _ImportMethod.file),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'ไฟล์ต้นฉบับจะไม่ถูกลบออกจากแอปต้นทาง',
                style: TextStyle(color: t.textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportActionTile extends StatelessWidget {
  const _ImportActionTile({
    required this.actionKey,
    required this.icon,
    required this.color,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key actionKey;
  final IconData icon;
  final Color color;
  final String eyebrow;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Material(
      color: t.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: color.withValues(alpha: .28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: actionKey,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: .2)),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: t.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 19, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareGuideSheet extends StatelessWidget {
  const _ShareGuideSheet();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          2,
          Spacing.lg,
          Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.success.withValues(alpha: .12),
                ),
                child: Icon(
                  Icons.ios_share_rounded,
                  color: t.success,
                  size: 27,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'แชร์จากแอปต้นทาง',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'ส่งคลิปเข้ากล่อง RelayContent ได้ใน 3 ขั้นตอน',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textSecondary),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            const _ShareStep(
              number: '1',
              text: 'เปิดคลิปในแอป AI ที่คุณใช้อยู่',
            ),
            const _ShareStep(
              number: '2',
              text: 'แตะ Share แล้วเลือก RelayContent',
            ),
            const _ShareStep(
              number: '3',
              text: 'กลับมาดูสถานะนำเข้าใน AI Content Inbox',
            ),
            const SizedBox(height: Spacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('close-share-guide'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_rounded),
                label: const Text('เข้าใจแล้ว'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareStep extends StatelessWidget {
  const _ShareStep({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.t.primary.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              color: context.t.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _RelayFlowPanel extends StatefulWidget {
  const _RelayFlowPanel({
    required this.run,
    required this.syncing,
    required this.importingCount,
    required this.readyCount,
  });

  final int run;
  final bool syncing;
  final int importingCount;
  final int readyCount;

  @override
  State<_RelayFlowPanel> createState() => _RelayFlowPanelState();
}

class _RelayFlowPanelState extends State<_RelayFlowPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  late final Animation<double> _progress;

  bool get _reduced => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: _reduced ? Duration.zero : const Duration(milliseconds: 1900),
    );
    _progress = CurvedAnimation(parent: _motion, curve: Curves.easeInOutCubic);
    _motion.forward();
  }

  @override
  void didUpdateWidget(covariant _RelayFlowPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.run != widget.run) {
      if (_reduced) {
        _motion.value = 1;
      } else {
        _motion.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  String _status(double progress) {
    if (progress < .34) return 'กำลังรับลิงก์และไฟล์';
    if (progress < .72) return 'AI กำลังตรวจรูปแบบคอนเทนต์';
    if (widget.syncing) return 'กำลังจัดคิวเข้ากล่องของคุณ';
    return 'พร้อมเลือกไปสร้างโพสต์';
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    builder: (context, _) {
      final progress = _progress.value;
      return Container(
        key: const Key('ai-relay-flow'),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.t.surfaceElevated,
              context.t.primary.withValues(alpha: .055),
            ],
          ),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: context.t.primary.withValues(alpha: .25 + progress * .15),
          ),
          boxShadow: [
            BoxShadow(
              color: context.t.primary.withValues(alpha: .03 + progress * .04),
              blurRadius: 14,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: context.t.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: context.t.success.withValues(alpha: .6),
                        blurRadius: 7,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                const Text(
                  'RELAY FLOW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.readyCount} พร้อมใช้',
                  style: TextStyle(
                    color: context.t.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 68,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RelayPathPainter(
                        color: context.t.primary,
                        progress: progress,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _RelayStage(
                          icon: Icons.move_to_inbox_rounded,
                          label: 'รับเข้ามา',
                          active: progress >= .06,
                        ),
                      ),
                      Expanded(
                        child: _RelayStage(
                          icon: Icons.auto_awesome_rounded,
                          label: 'AI วิเคราะห์',
                          active: progress >= .4,
                        ),
                      ),
                      Expanded(
                        child: _RelayStage(
                          icon: Icons.rocket_launch_rounded,
                          label: 'พร้อมโพสต์',
                          active: progress >= .78,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: _reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: Text(
                _status(progress),
                key: ValueKey(_status(progress)),
                style: TextStyle(
                  color: progress >= .78
                      ? context.t.success
                      : context.t.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _RelayStage extends StatelessWidget {
  const _RelayStage({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AnimatedContainer(
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 240),
        width: active ? 33 : 29,
        height: active ? 33 : 29,
        decoration: BoxDecoration(
          color: active
              ? context.t.primary.withValues(alpha: .16)
              : context.t.surfaceContainer,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? context.t.primary : context.t.border,
            width: active ? 1.6 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: context.t.primary.withValues(alpha: .23),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 16,
          color: active ? context.t.primary : context.t.textSecondary,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        style: TextStyle(
          color: active ? context.t.textPrimary : context.t.textSecondary,
          fontSize: 9.5,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ],
  );
}

class _RelayPathPainter extends CustomPainter {
  const _RelayPathPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = 17.5;
    final start = Offset(size.width / 6, y);
    final end = Offset(size.width * 5 / 6, y);
    final base = Paint()
      ..color = color.withValues(alpha: .16)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, base);

    final activeEnd = Offset(start.dx + (end.dx - start.dx) * progress, y);
    canvas.drawLine(
      start,
      activeEnd,
      Paint()
        ..shader = LinearGradient(colors: [color.withValues(alpha: .35), color])
            .createShader(Rect.fromPoints(start, end))
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    if (progress > .02 && progress < .99) {
      canvas.drawCircle(
        activeEnd,
        9,
        Paint()
          ..color = color.withValues(alpha: .2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(activeEnd, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_RelayPathPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _SourcesSection extends StatelessWidget {
  const _SourcesSection({
    required this.controller,
    required this.onManage,
    required this.onConnect,
  });
  final AiSourcesController controller;
  final VoidCallback onManage;
  final ValueChanged<String> onConnect;

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
            TextButton(
              key: const Key('manage-ai-sources'),
              onPressed: onManage,
              child: const Text('จัดการ'),
            ),
          ],
        ),
        SizedBox(
          height: 108,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final source in controller.sources)
                _SourceChip(
                  key: Key('ai-source-${source.id}'),
                  source: source,
                  busy: controller.busySourceId == source.id,
                  onTap: () =>
                      source.isConnected ? onManage() : onConnect(source.id),
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

class _SourceArrivalBanner extends StatelessWidget {
  const _SourceArrivalBanner({required this.sourceName});

  final String sourceName;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 680),
    curve: Curves.easeOutCubic,
    builder: (context, progress, _) => Container(
      key: const Key('source-arrival-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: context.t.success.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: context.t.success.withValues(alpha: .25 + progress * .2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.hub_outlined, size: 18, color: context.t.primary),
          const SizedBox(width: 5),
          SizedBox(
            width: 38,
            height: 12,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 1.5,
                    color: context.t.primary.withValues(alpha: .2),
                  ),
                  Container(
                    width: constraints.maxWidth * progress,
                    height: 1.5,
                    color: context.t.primary,
                  ),
                  Align(
                    alignment: Alignment(-1 + progress * 2, 0),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: context.t.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: context.t.primary.withValues(alpha: .7),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),
          Icon(Icons.move_to_inbox_rounded, size: 18, color: context.t.success),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'รับงานใหม่จาก $sourceName เข้ากล่องแล้ว',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'พร้อมเปิดตัวอย่างและส่งต่อไปสร้างโพสต์',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.t.textSecondary, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
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
    required this.onSync,
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
  final VoidCallback onSync;

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
                key: const Key('sync-ai-inbox'),
                tooltip: 'ซิงก์ใหม่',
                onPressed: onSync,
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
          for (var index = 0; index < ready.length; index++) ...[
            _ReadyItem(
              key: ValueKey('ready-${ready[index].id}'),
              item: ready[index],
              index: index,
              product: product,
              selecting: selecting,
              selected: selectedItems.contains(ready[index].id),
              onTap: () =>
                  selecting ? onToggle(ready[index].id) : onOpen(ready[index]),
              onLongPress: () {
                if (!selecting) onStartSelecting();
                onToggle(ready[index].id);
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
  const _ProductContext({
    super.key,
    required this.product,
    required this.onTap,
  });
  final ShowcaseProduct product;
  final VoidCallback onTap;
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
          key: const Key('open-product-picker'),
          onPressed: onTap,
          child: const Text('เปลี่ยน'),
        ),
      ],
    ),
  );
}

class _NeedProduct extends StatelessWidget {
  const _NeedProduct({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      children: [
        Icon(Icons.add_shopping_cart_rounded, color: context.t.warning),
        const SizedBox(width: 10),
        const Expanded(child: Text('เลือกสินค้าที่จะปักตะกร้ากับคอนเทนต์')),
        TextButton(
          key: const Key('open-product-picker'),
          onPressed: onTap,
          child: const Text('เลือก'),
        ),
      ],
    ),
  );
}

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({required this.current, required this.products});

  final ShowcaseProduct? current;
  final List<ShowcaseProduct> products;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _search = TextEditingController();
  ShowcaseProduct? _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
    _search.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final next = _search.text;
    if (_query == next || !mounted) return;
    setState(() => _query = next);
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  List<ShowcaseProduct> get _products {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.products;
    return widget.products
        .where(
          (product) =>
              product.name.toLowerCase().contains(query) ||
              product.shopName.toLowerCase().contains(query),
        )
        .toList();
  }

  void _select(ShowcaseProduct product) {
    if (!product.inStock || _selected?.id == product.id) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = product);
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;
    final reduced = MediaQuery.of(context).disableAnimations;
    return FractionallySizedBox(
      heightFactor: .76,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Spacing.md,
          0,
          Spacing.md,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เลือกสินค้าที่จะปักตะกร้า',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'เลือกได้ 1 ชิ้นสำหรับคอนเทนต์นี้',
                        style: TextStyle(
                          color: context.t.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'ปิด',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('product-picker-search'),
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'ค้นหาชื่อสินค้า หรือร้านค้า',
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: products.isEmpty
                  ? Center(
                      child: Text(
                        'ไม่พบสินค้าที่ค้นหา',
                        style: TextStyle(color: context.t.textSecondary),
                      ),
                    )
                  : ListView(
                      children: [
                        for (
                          var index = 0;
                          index < products.length;
                          index++
                        ) ...[
                          _ProductPickerTile(
                            product: products[index],
                            selected: _selected?.id == products[index].id,
                            reduced: reduced,
                            onTap: () => _select(products[index]),
                          ),
                          if (index != products.length - 1)
                            const SizedBox(height: 9),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('confirm-product-selection'),
                onPressed: _selected == null
                    ? null
                    : () => Navigator.pop(context, _selected),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: Text(
                  _selected == null
                      ? 'เลือกสินค้าเพื่อดำเนินการต่อ'
                      : 'ใช้สินค้านี้กับคอนเทนต์',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPickerTile extends StatelessWidget {
  const _ProductPickerTile({
    required this.product,
    required this.selected,
    required this.reduced,
    required this.onTap,
  });

  final ShowcaseProduct product;
  final bool selected;
  final bool reduced;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('product-picker-${product.id}'),
    onTap: product.inStock ? onTap : null,
    borderRadius: BorderRadius.circular(Radii.lg),
    child: AnimatedContainer(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected
            ? context.t.primary.withValues(alpha: .08)
            : context.t.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: selected ? context.t.primary : context.t.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          ProductArtwork(
            product: product,
            width: 56,
            height: 64,
            borderRadius: Radii.md,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '฿${product.priceBaht} · คอม ฿${product.commissionBaht}/ชิ้น',
                  style: TextStyle(
                    color: product.inStock
                        ? context.t.primary
                        : context.t.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  product.inStock
                      ? product.shopName
                      : 'สินค้าหมด · ยังเลือกไม่ได้',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: product.inStock
                        ? context.t.textSecondary
                        : context.t.error,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: Icon(
              selected
                  ? Icons.check_circle_rounded
                  : product.inStock
                  ? Icons.radio_button_unchecked_rounded
                  : Icons.block_rounded,
              key: ValueKey('$selected-${product.inStock}'),
              color: selected
                  ? context.t.primary
                  : product.inStock
                  ? context.t.textSecondary
                  : context.t.error,
            ),
          ),
        ],
      ),
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

class _SourceChip extends StatefulWidget {
  const _SourceChip({
    super.key,
    required this.source,
    required this.busy,
    required this.onTap,
  });
  final AiSource source;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_SourceChip> createState() => _SourceChipState();
}

class _SourceChipState extends State<_SourceChip> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.source.isConnected;
    final attention = widget.source.status == SourceStatus.needsAttention;
    final accent = widget.busy
        ? context.t.primary
        : attention
        ? context.t.warning
        : connected
        ? context.t.primary
        : context.t.textSecondary;
    final reduced = MediaQuery.of(context).disableAnimations;

    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: Listener(
        onPointerDown: widget.busy ? null : (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: reduced || !_pressed ? 1 : .96,
          duration: const Duration(milliseconds: 90),
          child: InkWell(
            onTap: widget.busy ? null : widget.onTap,
            borderRadius: BorderRadius.circular(Radii.md),
            child: AnimatedContainer(
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              width: 122,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.busy
                    ? context.t.primary.withValues(alpha: .07)
                    : context.t.surfaceContainer,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                  color: widget.busy || connected ? accent : context.t.border,
                  width: widget.busy ? 1.5 : 1,
                ),
                boxShadow: widget.busy
                    ? [
                        BoxShadow(
                          color: context.t.primary.withValues(alpha: .16),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedRotation(
                        turns: widget.busy ? .125 : 0,
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        child: Icon(
                          Icons.hub_outlined,
                          size: 19,
                          color: accent,
                        ),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: widget.busy
                            ? SizedBox(
                                key: const ValueKey('busy'),
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.t.primary,
                                ),
                              )
                            : Icon(
                                attention
                                    ? Icons.error_outline_rounded
                                    : connected
                                    ? Icons.check_circle
                                    : Icons.add_circle_outline,
                                key: ValueKey(widget.source.status),
                                size: 16,
                                color: attention
                                    ? context.t.warning
                                    : connected
                                    ? context.t.success
                                    : context.t.textSecondary,
                              ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    widget.source.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    child: Text(
                      widget.busy
                          ? 'กำลัง handshake…'
                          : connected
                          ? (attention ? 'เชื่อมแล้ว · ต้องตรวจ' : 'เชื่อมแล้ว')
                          : 'แตะเพื่อเชื่อม',
                      key: ValueKey('${widget.busy}-${widget.source.status}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadyItem extends StatefulWidget {
  const _ReadyItem({
    super.key,
    required this.item,
    required this.index,
    required this.product,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });
  final InboxItem item;
  final int index;
  final ShowcaseProduct? product;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_ReadyItem> createState() => _ReadyItemState();
}

class _ReadyItemState extends State<_ReadyItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  Timer? _entranceDelay;
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
    if (reduced) {
      _entrance.value = 1;
    } else {
      final delay = 65 * widget.index.clamp(0, 4);
      if (delay == 0) {
        _entrance.forward();
      } else {
        _entranceDelay = Timer(Duration(milliseconds: delay), () {
          if (mounted) _entrance.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _entranceDelay?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _entrance,
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: reduced || !_pressed ? 1 : .982,
          duration: const Duration(milliseconds: 90),
          child: _Panel(
            child: InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              child: Row(
                children: [
                  if (widget.selecting) ...[
                    Checkbox(
                      key: Key('select-inbox-${widget.item.id}'),
                      value: widget.selected,
                      onChanged: (_) => widget.onTap(),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _InboxArtwork(
                        item: widget.item,
                        product: widget.product,
                        width: 64,
                        height: 82,
                      ),
                      const Positioned.fill(child: _PreviewHalo()),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.item.sourceName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.t.primary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            if (widget.item.progress >= 1) ...[
                              const SizedBox(width: 6),
                              _ImportSuccessBadge(entrance: _entrance),
                            ],
                          ],
                        ),
                        Text(
                          'พร้อมใช้ · ${widget.item.durationSec} วินาที'
                          '${widget.item.vertical ? '' : ' · 16:9 ต้องครอป'}',
                          style: TextStyle(
                            color: context.t.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    widget.selecting
                        ? (widget.selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded)
                        : Icons.chevron_right_rounded,
                    color: widget.selected ? context.t.primary : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(_entrance.value);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, (1 - progress) * 12),
            child: child,
          ),
        );
      },
    );
  }
}

class _PreviewHalo extends StatelessWidget {
  const _PreviewHalo();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 720),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => Center(
        child: Container(
          width: 34 + progress * 20,
          height: 34 + progress * 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: context.t.primary.withValues(alpha: .5 * (1 - progress)),
              width: 1.4,
            ),
          ),
        ),
      ),
    ),
  );
}

class _ImportSuccessBadge extends StatelessWidget {
  const _ImportSuccessBadge({required this.entrance});

  final Animation<double> entrance;

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: CurvedAnimation(
      parent: entrance,
      curve: const Interval(.55, 1, curve: Curves.easeOutBack),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: context.t.success.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 10, color: context.t.success),
          const SizedBox(width: 2),
          Text(
            'รับสำเร็จ',
            style: TextStyle(
              color: context.t.success,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
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

class _InboxPreviewSheetState extends State<_InboxPreviewSheet>
    with SingleTickerProviderStateMixin {
  bool playing = false;
  late final AnimationController _playback = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void dispose() {
    _playback.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    HapticFeedback.selectionClick();
    setState(() => playing = !playing);
    if (playing) {
      _playback.repeat();
    } else {
      _playback.stop();
    }
  }

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
          child: AnimatedScale(
            scale: playing ? .88 : 1,
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: IconButton.filled(
              key: const Key('inbox-preview-play-pause'),
              onPressed: _togglePlayback,
              iconSize: 40,
              icon: AnimatedSwitcher(
                duration: MediaQuery.of(context).disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey(playing),
                ),
              ),
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
              const SizedBox(height: 10),
              AnimatedBuilder(
                animation: _playback,
                builder: (context, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    key: const Key('inbox-preview-progress'),
                    value: _playback.value,
                    minHeight: 3,
                    backgroundColor: context.t.textPrimary.withValues(
                      alpha: .24,
                    ),
                    color: context.t.primary,
                  ),
                ),
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

  String _stage(double progress) {
    if (progress < .34) return 'กำลังรับไฟล์';
    if (progress < .67) return 'AI กำลังตรวจสัดส่วน';
    return 'กำลังเตรียมพร้อมใช้';
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: item.progress),
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    color: context.t.warning,
                    backgroundColor: context.t.warning.withValues(alpha: .12),
                  ),
                  Center(
                    child: Icon(
                      progress < .34
                          ? Icons.download_rounded
                          : progress < .67
                          ? Icons.auto_awesome_rounded
                          : Icons.inventory_2_outlined,
                      size: 20,
                      color: context.t.warning,
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
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  AnimatedSwitcher(
                    duration: MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    child: Text(
                      '${_stage(progress)} · ${(progress * 100).round()}%',
                      key: ValueKey(_stage(progress)),
                      style: TextStyle(
                        color: context.t.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'กำลังรับไฟล์จาก ${item.sourceName}',
                    style: TextStyle(
                      color: context.t.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
                style: FilledButton.styleFrom(
                  backgroundColor: context.t.primary.withValues(alpha: .12),
                  foregroundColor: context.t.primary,
                  side: BorderSide(
                    color: context.t.primary.withValues(alpha: .3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('ลองใหม่'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDismiss,
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: const Text('ลบออก'),
              ),
            ),
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
