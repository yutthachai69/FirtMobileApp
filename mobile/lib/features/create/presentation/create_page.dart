import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme/tokens.dart';
import '../../composer/domain/composer_state.dart';
import '../../showcase/domain/showcase_product.dart';
import '../../showcase/presentation/product_artwork.dart';
import 'create_controller.dart';
import 'publish_review_page.dart';

/// หน้าสร้างคอนเทนต์: เลือกวิดีโอ → อัป → เขียนคำบรรยาย → ตรวจตะกร้า
class CreatePage extends StatefulWidget {
  const CreatePage({super.key, required this.controller, this.selectedProduct});
  final CreateController controller;
  final ShowcaseProduct? selectedProduct;

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  final _caption = TextEditingController();
  VideoPlayerController? _player;

  /// ความยาววิดีโอ อ่านจากไฟล์ที่อัปแล้ว
  /// ส่งต่อให้หน้า Composer ใช้ตรวจกฎ R7 (ห้ามยาวเกินที่บัญชีรองรับ)
  int _durationSec = 0;
  double _trimStart = 0;
  double _trimEnd = 1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStep);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStep);
    _caption.dispose();
    _player?.dispose();
    super.dispose();
  }

  /// _onStep เตรียม preview ทันทีที่อัปเสร็จ
  void _onStep() {
    final url = widget.controller.previewUrl;
    if (url == null || url.isEmpty || _player != null) return;

    final p = VideoPlayerController.networkUrl(Uri.parse(url));
    _player = p;
    p
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _durationSec = p.value.duration.inSeconds);
        })
        .catchError((_) {
          // อ่าน metadata ไม่ได้ก็ไม่ควรบล็อกผู้ใช้
          // หน้า Composer จะข้ามการตรวจความยาวไปเอง (ส่ง 0)
          if (mounted) setState(() {});
        });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;

      return Scaffold(
        appBar: AppBar(
          title: const Text('สร้างคอนเทนต์'),
          actions: [
            if (c.step != CreateStep.pick && !c.busy)
              TextButton(
                onPressed: () {
                  _player?.dispose();
                  _player = null;
                  _caption.clear();
                  _durationSec = 0;
                  _trimStart = 0;
                  _trimEnd = 1;
                  c.reset();
                },
                child: const Text('เริ่มใหม่'),
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(Spacing.md),
            children: [
              if (widget.selectedProduct != null) ...[
                _SelectedProduct(product: widget.selectedProduct!),
                const SizedBox(height: Spacing.md),
              ] else ...[
                const _ProductRequired(),
                const SizedBox(height: Spacing.md),
              ],

              if (c.error != null) ...[
                _ErrorBox(message: c.error!),
                const SizedBox(height: Spacing.md),
              ],

              switch (c.step) {
                CreateStep.pick => _PickStep(controller: c),
                CreateStep.uploading => _UploadingStep(controller: c),
                _ => _DescribeStep(
                  controller: c,
                  caption: _caption,
                  player: _player,
                  durationSec: _durationSec,
                  trimStart: _trimStart,
                  trimEnd: _trimEnd,
                  hasProduct: widget.selectedProduct != null,
                  onReplace: _replaceVideo,
                  onTrim: _openTrimSheet,
                  onContinue: () => _goToComposer(context),
                ),
              },
            ],
          ),
        ),
      );
    },
  );

  Future<void> _goToComposer(BuildContext context) async {
    final c = widget.controller;
    final product = widget.selectedProduct;
    if (product == null) {
      context.go('/showcase');
      return;
    }

    await _player?.pause();
    if (!context.mounted) return;

    context.go(
      '/create/publish',
      extra: PublishReviewArgs(
        product: product,
        caption: c.caption,
        mediaName: c.video?.name,
        durationSec: _trimmedDuration,
        sourceLabel: 'อัปโหลดจากมือถือ',
      ),
    );
  }

  int get _trimmedDuration {
    if (_durationSec <= 0) return 30;
    return (_durationSec * (_trimEnd - _trimStart)).round().clamp(1, 600);
  }

  void _replaceVideo() {
    _player?.dispose();
    _player = null;
    _durationSec = 0;
    _trimStart = 0;
    _trimEnd = 1;
    widget.controller.reset();
  }

  Future<void> _openTrimSheet() async {
    if (_durationSec <= 1) return;
    var values = RangeValues(_trimStart, _trimEnd);
    final result = await showModalBottomSheet<RangeValues>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ตัดช่วงคลิป',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'เลือกช่วง ${(values.start * _durationSec).round()}–${(values.end * _durationSec).round()} วินาที',
                  style: TextStyle(color: context.t.textSecondary),
                ),
                RangeSlider(
                  values: values,
                  min: 0,
                  max: 1,
                  divisions: _durationSec.clamp(2, 120),
                  labels: RangeLabels(
                    '${(values.start * _durationSec).round()} วิ',
                    '${(values.end * _durationSec).round()} วิ',
                  ),
                  onChanged: (next) => setSheetState(() => values = next),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, values),
                    child: const Text('ใช้ช่วงนี้'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _trimStart = result.start;
        _trimEnd = result.end;
      });
    }
  }
}

/// ComposerArgs ส่งข้อมูลข้ามหน้าให้ Composer
class ComposerArgs {
  const ComposerArgs({
    required this.contentId,
    required this.connectionId,
    required this.videoDurationSec,
    required this.isAigc,
  });

  final String contentId;
  final String connectionId;
  final int videoDurationSec;
  final bool isAigc;
}

class _SelectedProduct extends StatelessWidget {
  const _SelectedProduct({required this.product});

  final ShowcaseProduct product;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Spacing.md),
    decoration: BoxDecoration(
      color: context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: context.t.creative.withValues(alpha: .35)),
    ),
    child: Row(
      children: [
        ProductArtwork(product: product, width: 54, height: 64),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'สินค้าที่เลือก',
                style: TextStyle(
                  color: context.t.creative,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'คอมมิชชัน ฿${product.commissionBaht} ต่อชิ้น',
                style: TextStyle(
                  color: context.t.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'เปลี่ยนสินค้า',
          onPressed: () => context.go('/showcase'),
          icon: const Icon(Icons.swap_horiz_rounded),
        ),
      ],
    ),
  );
}

class _ProductRequired extends StatelessWidget {
  const _ProductRequired();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Spacing.md),
    decoration: BoxDecoration(
      color: context.t.warning.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: context.t.warning.withValues(alpha: .35)),
    ),
    child: Row(
      children: [
        Icon(Icons.add_shopping_cart_rounded, color: context.t.warning),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ยังไม่ได้เลือกสินค้าปักตะกร้า',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 3),
              Text(
                'เลือกสินค้าก่อน เพื่อพาคลิปนี้ไปตรวจตะกร้าและตั้งเวลา',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => context.go('/showcase'),
          child: const Text('เลือก'),
        ),
      ],
    ),
  );
}

// ── ขั้นตอนที่ 1: เลือกวิดีโอ ─────────────────────────────────

class _PickStep extends StatelessWidget {
  const _PickStep({required this.controller});
  final CreateController controller;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: Spacing.xl),
      Icon(
        Icons.video_library_outlined,
        size: 56,
        color: context.t.textSecondary,
      ),
      const SizedBox(height: Spacing.md),
      Text(
        'เลือกวิดีโอที่จะโพสต์',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: Spacing.sm),
      Text(
        'รองรับ MP4 และ MOV ขนาดไม่เกิน 100 MB',
        style: TextStyle(color: context.t.textSecondary),
      ),
      const SizedBox(height: Spacing.xl),
      FilledButton.icon(
        onPressed: controller.busy ? null : controller.pickAndUpload,
        icon: const Icon(Icons.add_rounded),
        label: const Text('เลือกวิดีโอ'),
      ),
    ],
  );
}

// ── ขั้นตอนที่ 2: กำลังอัป ────────────────────────────────────

class _UploadingStep extends StatelessWidget {
  const _UploadingStep({required this.controller});
  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    final pct = (controller.progress * 100).clamp(0, 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.xl),
        Text('กำลังอัปโหลด…', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: Spacing.sm),
        Text(
          controller.video?.name ?? '',
          style: TextStyle(color: context.t.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: Spacing.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.sm),
          child: LinearProgressIndicator(
            value: controller.progress > 0 ? controller.progress : null,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          '$pct% · ${controller.video?.readableSize ?? ''}',
          style: TextStyle(color: context.t.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: Spacing.lg),
        // ไฟล์ไปที่ storage ตรง ๆ ไม่ผ่านเซิร์ฟเวอร์เรา จึงเร็วกว่าและไม่กินแบนด์วิดท์เรา
        Text(
          'วิดีโอถูกส่งขึ้นที่เก็บไฟล์โดยตรง ไม่ผ่านเซิร์ฟเวอร์ของเรา',
          style: TextStyle(color: context.t.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

// ── ขั้นตอนที่ 3: เขียนคำบรรยาย ───────────────────────────────

class _DescribeStep extends StatelessWidget {
  const _DescribeStep({
    required this.controller,
    required this.caption,
    required this.player,
    required this.durationSec,
    required this.trimStart,
    required this.trimEnd,
    required this.hasProduct,
    required this.onReplace,
    required this.onTrim,
    required this.onContinue,
  });

  final CreateController controller;
  final TextEditingController caption;
  final VideoPlayerController? player;
  final int durationSec;
  final double trimStart;
  final double trimEnd;
  final bool hasProduct;
  final VoidCallback onReplace;
  final VoidCallback onTrim;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final over = c.caption.runes.length > kMaxCaptionRunes;
    final ready = player?.value.isInitialized ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: context.t.success, size: 18),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                'อัปโหลดเสร็จแล้ว${durationSec > 0 ? ' · ${_len(durationSec)}' : ''}',
                style: TextStyle(color: context.t.success),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),

        if (ready)
          _Preview(player: player!)
        else
          Container(
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.t.surfaceContainer,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: context.t.border),
            ),
            child: const CircularProgressIndicator(),
          ),

        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.t.surfaceContainer,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: context.t.border),
          ),
          child: Row(
            children: [
              Icon(Icons.movie_outlined, color: context.t.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.video?.name ?? 'วิดีโอที่เลือก',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${c.video?.readableSize ?? ''}${durationSec > 0 ? ' · ช่วงที่ใช้ ${_len((durationSec * (trimEnd - trimStart)).round())}' : ''}',
                      style: TextStyle(
                        color: context.t.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'จัดการคลิป',
                onSelected: (value) =>
                    value == 'replace' ? onReplace() : onTrim(),
                itemBuilder: (_) => [
                  if (durationSec > 1)
                    const PopupMenuItem(
                      value: 'trim',
                      child: Text('ตัดช่วงคลิป'),
                    ),
                  const PopupMenuItem(
                    value: 'replace',
                    child: Text('เปลี่ยนคลิป'),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: Spacing.lg),
        Text('คำบรรยาย', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: Spacing.sm),
        TextField(
          controller: caption,
          onChanged: c.setCaption,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'เขียนคำบรรยาย… ใส่ #แฮชแท็ก ได้',
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${c.caption.runes.length} / $kMaxCaptionRunes',
            style: TextStyle(
              fontSize: 12,
              color: over ? context.t.error : context.t.textSecondary,
            ),
          ),
        ),

        const SizedBox(height: Spacing.lg),
        FilledButton(
          onPressed: (c.busy || over || !hasProduct) ? null : onContinue,
          child: c.busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('ตรวจตะกร้าและการเผยแพร่'),
        ),
        if (!hasProduct) ...[
          const SizedBox(height: Spacing.sm),
          Text(
            'เลือกสินค้าที่ต้องการปักตะกร้าก่อนดำเนินการต่อ',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.t.warning, fontSize: 13),
          ),
        ],
      ],
    );
  }

  static String _len(int s) => s >= 60
      ? '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')} นาที'
      : '$s วินาที';
}

class _Preview extends StatefulWidget {
  const _Preview({required this.player});
  final VideoPlayerController player;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  @override
  Widget build(BuildContext context) {
    final p = widget.player;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.md),
      child: AspectRatio(
        aspectRatio: p.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(p),
            IconButton.filled(
              onPressed: () {
                setState(() => p.value.isPlaying ? p.pause() : p.play());
              },
              icon: Icon(
                p.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ส่วนประกอบเล็ก ๆ ──────────────────────────────────────────

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Spacing.md),
    decoration: BoxDecoration(
      color: context.t.error.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(Radii.md),
    ),
    child: Row(
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
