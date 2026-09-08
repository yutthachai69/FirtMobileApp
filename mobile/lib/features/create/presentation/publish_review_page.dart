import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../home/domain/content_store.dart';
import '../../home/domain/home_data.dart';
import '../../showcase/domain/showcase_product.dart';
import '../../showcase/presentation/product_artwork.dart';
import '../domain/readiness.dart';

enum PublishMode { schedule, now }

class PublishReviewArgs {
  const PublishReviewArgs({
    required this.product,
    this.caption,
    this.mediaName,
    this.durationSec = 30,
    this.sourceLabel = 'AI Content Inbox',
  });

  final ShowcaseProduct product;
  final String? caption;
  final String? mediaName;
  final int durationSec;
  final String sourceLabel;
}

class PublishReviewPage extends StatefulWidget {
  const PublishReviewPage({
    super.key,
    required this.product,
    this.initialCaption,
    this.mediaName,
    this.durationSec = 30,
    this.sourceLabel = 'AI Content Inbox',
    this.store,
  });
  final ShowcaseProduct product;
  final String? initialCaption;
  final String? mediaName;
  final int durationSec;
  final String sourceLabel;

  /// เมื่อส่งเข้ามา การกดยืนยันจะเพิ่มงานเข้าแหล่งข้อมูลกลาง
  /// งานจึงไปโผล่ในแท็บคอนเทนต์และหน้าหลักจริง
  final ContentStore? store;

  @override
  State<PublishReviewPage> createState() => _PublishReviewPageState();
}

class _PublishReviewPageState extends State<PublishReviewPage> {
  final caption = TextEditingController();
  final scrollController = ScrollController();
  final _captionKey = GlobalKey();
  final _basketKey = GlobalKey();
  PublishMode mode = PublishMode.schedule;
  late DateTime scheduledAt;
  bool basket = true;
  bool submitted = false;
  bool submitting = false;
  bool _acknowledgedLowScore = false;
  final tags = <String>{'#รีวิวของดี', '#TikTokป้ายยา'};

  ReadinessReport get _readiness => ReadinessReport.evaluate(
    caption: caption.text,
    tags: tags,
    durationSec: widget.durationSec,
    basketEnabled: basket,
    product: widget.product,
  );

  void _jumpTo(ReadinessTarget target) {
    final key = switch (target) {
      ReadinessTarget.caption => _captionKey,
      ReadinessTarget.basket => _basketKey,
      ReadinessTarget.none => null,
    };
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      alignment: 0.1,
    );
  }

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    scheduledAt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19, 30);
    caption.text = widget.initialCaption?.trim().isNotEmpty == true
        ? widget.initialCaption!.trim()
        : '${widget.product.name} ที่อยากให้ลอง ✨ '
              '${widget.product.sellingPoints.first} ดูโปรล่าสุดได้ที่ตะกร้า';
  }

  @override
  void dispose() {
    caption.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (submitted) return _Accepted(mode: mode, product: widget.product);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตรวจสอบก่อนเผยแพร่'),
        actions: [
          IconButton(
            key: const Key('open-video-preview'),
            tooltip: 'ดูตัวอย่างวิดีโอ',
            onPressed: _openPreview,
            icon: const Icon(Icons.play_circle_outline_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(Spacing.md, 8, Spacing.md, 24),
          children: [
            _VideoSummary(
              product: widget.product,
              mediaName: widget.mediaName,
              durationSec: widget.durationSec,
              sourceLabel: widget.sourceLabel,
              onPreview: _openPreview,
            ),
            const SizedBox(height: Spacing.lg),
            const _DestinationCard(),
            const SizedBox(height: Spacing.lg),
            _Title(
              Icons.shopping_bag_outlined,
              'ตะกร้าสินค้า',
              key: _basketKey,
            ),
            const SizedBox(height: 10),
            _Basket(
              product: widget.product,
              enabled: basket,
              onChanged: _changeBasket,
            ),
            const SizedBox(height: Spacing.lg),
            const _Title(Icons.send_outlined, 'เลือกเวลาที่เผยแพร่'),
            const SizedBox(height: 10),
            SegmentedButton<PublishMode>(
              segments: const [
                ButtonSegment(
                  value: PublishMode.schedule,
                  icon: Icon(Icons.schedule_rounded),
                  label: Text('ตั้งเวลา'),
                ),
                ButtonSegment(
                  value: PublishMode.now,
                  icon: Icon(Icons.bolt_rounded),
                  label: Text('โพสต์ทันที'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (v) => setState(() => mode = v.first),
            ),
            if (mode == PublishMode.schedule) ...[
              const SizedBox(height: 12),
              _Schedule(
                scheduledAt: scheduledAt,
                onChanged: (value) => setState(() => scheduledAt = value),
                onPickDate: _pickDate,
                onPickTime: _pickTime,
              ),
            ],
            const SizedBox(height: Spacing.lg),
            _Title(Icons.notes_rounded, 'แคปชัน', key: _captionKey),
            const SizedBox(height: 10),
            TextField(
              key: const Key('publish-caption'),
              controller: caption,
              onChanged: (_) => setState(() {}),
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                hintText: 'เขียนข้อความดึงดูดผู้ชมและรายละเอียดสินค้า',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final tag in const [
                  '#รีวิวของดี',
                  '#TikTokป้ายยา',
                  '#ของมันต้องมี',
                  '#โปรวันนี้',
                ])
                  FilterChip(
                    label: Text(tag),
                    selected: tags.contains(tag),
                    onSelected: (selected) => setState(
                      () => selected ? tags.add(tag) : tags.remove(tag),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _PostPreview(caption: caption.text, tags: tags),
            const SizedBox(height: Spacing.lg),
            const _Title(Icons.verified_outlined, 'ความพร้อมก่อนเผยแพร่'),
            const SizedBox(height: 10),
            _ReadinessCard(report: _readiness, onJump: _jumpTo),
            const SizedBox(height: Spacing.lg),
            _Checklist(basket: basket, mode: mode, scheduledAt: scheduledAt),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.md, 8, Spacing.md, 12),
          child: FilledButton.icon(
            key: const Key('publish-submit'),
            onPressed: caption.text.trim().isEmpty || submitting
                ? null
                : _submit,
            icon: Icon(
              submitting
                  ? Icons.sync_rounded
                  : mode == PublishMode.schedule
                  ? Icons.event_available_rounded
                  : Icons.rocket_launch_outlined,
            ),
            label: Text(
              submitting
                  ? 'กำลังส่งเข้าคิว…'
                  : mode == PublishMode.schedule
                  ? 'ยืนยัน ${_shortDate(scheduledAt)} ${_clock(scheduledAt)}'
                  : 'ยืนยันโพสต์ทันที',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeBasket(bool enabled) async {
    if (enabled) {
      setState(() => basket = true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.remove_shopping_cart_outlined,
          color: context.t.warning,
        ),
        title: const Text('เผยแพร่โดยไม่ปักตะกร้า?'),
        content: const Text(
          'ผู้ชมจะไม่เห็นปุ่มสินค้าในโพสต์นี้ และไม่สามารถกดซื้อจากคอนเทนต์ได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('คงตะกร้าไว้'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('เผยแพร่แบบไม่มีตะกร้า'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) setState(() => basket = false);
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (value != null && mounted) {
      setState(
        () => scheduledAt = DateTime(
          value.year,
          value.month,
          value.day,
          scheduledAt.hour,
          scheduledAt.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(scheduledAt),
    );
    if (value != null && mounted) {
      setState(
        () => scheduledAt = DateTime(
          scheduledAt.year,
          scheduledAt.month,
          scheduledAt.day,
          value.hour,
          value.minute,
        ),
      );
    }
  }

  Future<void> _submit() async {
    // เตือน ไม่บล็อก — คะแนนต่ำมากถามยืนยันครั้งเดียว แล้วจำว่าผู้ใช้เลือกข้าม
    if (_readiness.level == ReadinessLevel.poor && !_acknowledgedLowScore) {
      final proceed = await _confirmLowReadiness();
      if (proceed != true) return;
      _acknowledgedLowScore = true;
    }
    setState(() => submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    final now = DateTime.now();
    widget.store?.add(
      PublishJob(
        id: 'job-${now.microsecondsSinceEpoch}',
        contentId: 'content-${now.microsecondsSinceEpoch}',
        productId: widget.product.id,
        platform: 'tiktok',
        status: mode == PublishMode.now
            ? JobStatus.queued
            : JobStatus.scheduled,
        scheduledAt: mode == PublishMode.now ? now : scheduledAt,
        caption: caption.text.trim(),
        sourceLabel: widget.sourceLabel,
      ),
    );
    setState(() {
      submitting = false;
      submitted = true;
    });
  }

  Future<bool?> _confirmLowReadiness() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.rule_rounded, color: context.t.warning),
      title: const Text('คะแนนความพร้อมยังต่ำ'),
      content: Text(
        'ได้ ${_readiness.percent}/100 — คลิปนี้อาจไปได้ไม่ไกลเท่าที่ควร '
        'ต้องการกลับไปแก้ตามคำแนะนำก่อนไหม',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('กลับไปแก้'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('เผยแพร่เลย'),
        ),
      ],
    ),
  );

  void _openPreview() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.black,
    builder: (_) => _ClipPreviewSheet(
      product: widget.product,
      mediaName: widget.mediaName ?? widget.product.name,
      durationSec: widget.durationSec,
      sourceLabel: widget.sourceLabel,
    ),
  );
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard();

  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.music_note_rounded, color: Colors.black),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TikTok Shop',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text('@relay.demo · พร้อมรับงาน', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
        Icon(Icons.check_circle_rounded, color: context.t.success, size: 19),
      ],
    ),
  );
}

class _Title extends StatelessWidget {
  const _Title(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: context.t.primary, size: 20),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _VideoSummary extends StatelessWidget {
  const _VideoSummary({
    required this.product,
    required this.mediaName,
    required this.durationSec,
    required this.sourceLabel,
    required this.onPreview,
  });
  final ShowcaseProduct product;
  final String? mediaName;
  final int durationSec;
  final String sourceLabel;
  final VoidCallback onPreview;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: const Key('video-preview-card'),
      onTap: onPreview,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        height: 188,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: context.t.primary.withValues(alpha: .35)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ProductArtwork(product: product, borderRadius: Radii.lg),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x22000000), Color(0xDD00101E)],
                  stops: [.3, 1],
                ),
              ),
            ),
            Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .58),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .75),
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ตัวอย่างวิดีโอ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          mediaName ?? product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '$sourceLabel · ${_duration(durationSec)} · 1080P',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.fullscreen_rounded, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  static String _duration(int seconds) {
    final safe = seconds <= 0 ? 30 : seconds;
    return '${(safe ~/ 60).toString().padLeft(2, '0')}:${(safe % 60).toString().padLeft(2, '0')}';
  }
}

class _ClipPreviewSheet extends StatefulWidget {
  const _ClipPreviewSheet({
    required this.product,
    required this.mediaName,
    required this.durationSec,
    required this.sourceLabel,
  });
  final ShowcaseProduct product;
  final String mediaName;
  final int durationSec;
  final String sourceLabel;

  @override
  State<_ClipPreviewSheet> createState() => _ClipPreviewSheetState();
}

class _ClipPreviewSheetState extends State<_ClipPreviewSheet> {
  bool playing = false;
  double position = 0;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: ProductArtwork(product: widget.product, borderRadius: 0),
      ),
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x33000000), Color(0x33000000), Color(0xE6000000)],
              stops: [0, .55, 1],
            ),
          ),
        ),
      ),
      Positioned(
        top: 10,
        left: 10,
        child: IconButton.filledTonal(
          tooltip: 'ปิดตัวอย่าง',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      Center(
        child: IconButton.filled(
          key: const Key('preview-play-pause'),
          onPressed: () => setState(() {
            playing = !playing;
            position = playing ? .38 : position;
          }),
          iconSize: 40,
          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
        ),
      ),
      Positioned(
        left: 18,
        right: 18,
        bottom: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mediaName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.sourceLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: position, minHeight: 4),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  playing
                      ? '00:${(widget.durationSec * position).round().toString().padLeft(2, '0')}'
                      : '00:00',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const Spacer(),
                Text(
                  _VideoSummary._duration(widget.durationSec),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _Basket extends StatelessWidget {
  const _Basket({
    required this.product,
    required this.enabled,
    required this.onChanged,
  });
  final ShowcaseProduct product;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => _Panel(
    borderColor: enabled ? context.t.warning.withValues(alpha: .4) : null,
    child: Row(
      children: [
        ProductArtwork(product: product, width: 46, height: 54),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                '฿${product.priceBaht} · สต็อก ${product.stock} ชิ้น',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        Switch(value: enabled, onChanged: onChanged),
      ],
    ),
  );
}

class _Schedule extends StatelessWidget {
  const _Schedule({
    required this.scheduledAt,
    required this.onChanged,
    required this.onPickDate,
    required this.onPickTime,
  });
  final DateTime scheduledAt;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ช่วงเวลาที่ AI แนะนำ',
          style: TextStyle(color: context.t.primary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final offset in [0, 1, 2])
              ChoiceChip(
                label: Text(
                  offset == 0
                      ? 'วันนี้'
                      : offset == 1
                      ? 'พรุ่งนี้'
                      : 'อีก 2 วัน',
                ),
                selected: _sameDay(
                  scheduledAt,
                  DateTime.now().add(Duration(days: offset)),
                ),
                onSelected: (_) {
                  final date = DateTime.now().add(Duration(days: offset));
                  onChanged(
                    DateTime(
                      date.year,
                      date.month,
                      date.day,
                      scheduledAt.hour,
                      scheduledAt.minute,
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          children: [
            for (final value in ['12:00', '19:30', '21:00'])
              ChoiceChip(
                label: Text(value),
                selected: _clock(scheduledAt) == value,
                onSelected: (_) {
                  final parts = value.split(':');
                  onChanged(
                    DateTime(
                      scheduledAt.year,
                      scheduledAt.month,
                      scheduledAt.day,
                      int.parse(parts[0]),
                      int.parse(parts[1]),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('pick-publish-date'),
                onPressed: onPickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(_shortDate(scheduledAt)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('pick-publish-time'),
                onPressed: onPickTime,
                icon: const Icon(Icons.schedule_rounded),
                label: Text(_clock(scheduledAt)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PostPreview extends StatelessWidget {
  const _PostPreview({required this.caption, required this.tags});
  final String caption;
  final Set<String> tags;

  @override
  Widget build(BuildContext context) {
    final tagLine = tags.join(' ');
    final total = caption.trim().runes.length + tagLine.runes.length;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.t.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: context.t.primary.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 17,
                color: context.t.primary,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'ข้อความที่จะเผยแพร่',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$total ตัวอักษร',
                style: TextStyle(color: context.t.textSecondary, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            caption.trim(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, height: 1.45),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              tagLine,
              style: TextStyle(color: context.t.primary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.report, required this.onJump});
  final ReadinessReport report;
  final ValueChanged<ReadinessTarget> onJump;

  Color _color(BuildContext context) => switch (report.level) {
    ReadinessLevel.good => context.t.success,
    ReadinessLevel.fair => context.t.warning,
    ReadinessLevel.poor => context.t.error,
  };

  String get _levelLabel => switch (report.level) {
    ReadinessLevel.good => 'พร้อมเผยแพร่',
    ReadinessLevel.fair => 'พอเผยแพร่ได้',
    ReadinessLevel.poor => 'ควรปรับก่อน',
  };

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return _Panel(
      borderColor: color.withValues(alpha: .4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${report.percent}',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 10, left: 2),
                child: Text('/100', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _levelLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            report.level == ReadinessLevel.good
                ? 'ทุกหัวข้อผ่านเกณฑ์แล้ว'
                : 'แตะหัวข้อที่ยังไม่เต็มเพื่อไปแก้ตรงจุด',
            style: TextStyle(color: context.t.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 6),
          for (final check in report.checks)
            _ReadinessRow(check: check, onJump: onJump),
        ],
      ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({required this.check, required this.onJump});
  final ReadinessCheck check;
  final ValueChanged<ReadinessTarget> onJump;

  @override
  Widget build(BuildContext context) {
    final ok = check.isFull;
    final tappable = !ok && check.target != ReadinessTarget.none;
    final color = ok
        ? context.t.success
        : check.ratio >= .5
        ? context.t.warning
        : context.t.error;

    return InkWell(
      onTap: tappable ? () => onJump(check.target) : null,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.adjust_rounded,
              size: 17,
              color: color,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          check.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${check.score}/${check.maxScore}',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.t.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (!ok) ...[
                    const SizedBox(height: 2),
                    Text(
                      check.hint,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: context.t.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (tappable)
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.t.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist({
    required this.basket,
    required this.mode,
    required this.scheduledAt,
  });
  final bool basket;
  final PublishMode mode;
  final DateTime scheduledAt;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'สรุปก่อนยืนยัน',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        _Line(
          basket ? 'เปิดตะกร้าสินค้าแล้ว' : 'ไม่ได้ปักตะกร้าสินค้า',
          basket,
        ),
        const _Line('ผ่านการตรวจเนื้อหาและข้อมูลสินค้า', true),
        _Line(
          mode == PublishMode.schedule
              ? '${_shortDate(scheduledAt)} เวลา ${_clock(scheduledAt)}'
              : 'พร้อมโพสต์ทันที',
          true,
        ),
      ],
    ),
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _clock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _shortDate(DateTime value) {
  final now = DateTime.now();
  if (_sameDay(value, now)) return 'วันนี้';
  if (_sameDay(value, now.add(const Duration(days: 1)))) return 'พรุ่งนี้';
  return '${value.day}/${value.month}/${value.year}';
}

class _Line extends StatelessWidget {
  const _Line(this.text, this.ok);
  final String text;
  final bool ok;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.info_outline,
          color: ok ? context.t.success : context.t.warning,
          size: 17,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.borderColor});
  final Widget child;
  final Color? borderColor;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: borderColor ?? context.t.border),
    ),
    child: child,
  );
}

class _Accepted extends StatelessWidget {
  const _Accepted({required this.mode, required this.product});
  final PublishMode mode;
  final ShowcaseProduct product;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.done_all_rounded, size: 76, color: context.t.success),
              const SizedBox(height: Spacing.lg),
              Text(
                mode == PublishMode.schedule
                    ? 'ตั้งเวลาเรียบร้อย'
                    : 'รับงานเผยแพร่แล้ว',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${product.name}\nถูกเพิ่มในคิวคอนเทนต์แล้ว',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.t.textSecondary, height: 1.5),
              ),
              const SizedBox(height: Spacing.lg),
              FilledButton.icon(
                onPressed: () => context.go('/content'),
                icon: const Icon(Icons.video_library_outlined),
                label: const Text('ติดตามสถานะคอนเทนต์'),
              ),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('กลับหน้าหลัก'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
