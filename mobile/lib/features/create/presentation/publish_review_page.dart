import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.remixOfId,
    this.remixNote,
  });

  final ShowcaseProduct product;
  final String? caption;
  final String? mediaName;
  final int durationSec;
  final String sourceLabel;

  /// id ของงานต้นทางเมื่อมาจากการรีมิกซ์ และคำอธิบายว่ารีมิกซ์แบบไหน
  final String? remixOfId;
  final String? remixNote;
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
    this.remixOfId,
    this.remixNote,
  });
  final ShowcaseProduct product;
  final String? initialCaption;
  final String? mediaName;
  final int durationSec;
  final String sourceLabel;

  /// เมื่อส่งเข้ามา การกดยืนยันจะเพิ่มงานเข้าแหล่งข้อมูลกลาง
  /// งานจึงไปโผล่ในแท็บคอนเทนต์และหน้าหลักจริง
  final ContentStore? store;

  /// งานต้นทางและคำอธิบายเมื่อหน้านี้เปิดจากการรีมิกซ์
  final String? remixOfId;
  final String? remixNote;

  @override
  State<PublishReviewPage> createState() => _PublishReviewPageState();
}

class _PublishReviewPageState extends State<PublishReviewPage>
    with TickerProviderStateMixin {
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
  late final AnimationController _arrivalController;
  late final Animation<double> _arrival;
  late final AnimationController _launchController;

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
    final reduced = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _arrivalController = AnimationController(
      vsync: this,
      duration: reduced ? Duration.zero : const Duration(milliseconds: 760),
    )..forward();
    _arrival = CurvedAnimation(
      parent: _arrivalController,
      curve: Curves.easeOutCubic,
    );
    _launchController = AnimationController(
      vsync: this,
      duration: reduced ? Duration.zero : const Duration(milliseconds: 980),
    );
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    scheduledAt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19, 30);
    caption.text = widget.initialCaption?.trim().isNotEmpty == true
        ? widget.initialCaption!.trim()
        : '${widget.product.name} ที่อยากให้ลอง ✨ '
              '${widget.product.sellingPoints.first} ดูโปรล่าสุดได้ที่ตะกร้า';
  }

  @override
  void dispose() {
    _launchController.dispose();
    _arrivalController.dispose();
    caption.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (submitted) return _Accepted(mode: mode, product: widget.product);
    return Stack(
      children: [
        Scaffold(
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
                if (widget.remixNote != null) ...[
                  _RemixBanner(note: widget.remixNote!),
                  const SizedBox(height: Spacing.md),
                ],
                _VideoSummary(
                  product: widget.product,
                  mediaName: widget.mediaName,
                  durationSec: widget.durationSec,
                  sourceLabel: widget.sourceLabel,
                  onPreview: _openPreview,
                  arrival: _arrival,
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
                _Checklist(
                  basket: basket,
                  mode: mode,
                  scheduledAt: scheduledAt,
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.md, 8, Spacing.md, 12),
              child: _PublishCta(
                onPressed: caption.text.trim().isEmpty || submitting
                    ? null
                    : _submit,
                mode: mode,
                submitting: submitting,
                label: submitting
                    ? 'กำลังส่งเข้าคิว…'
                    : mode == PublishMode.schedule
                    ? 'ยืนยัน ${_shortDate(scheduledAt)} ${_clock(scheduledAt)}'
                    : 'ยืนยันโพสต์ทันที',
              ),
            ),
          ),
        ),
        if (submitting)
          Positioned.fill(
            child: _PublishLaunchOverlay(
              animation: _launchController,
              scheduled: mode == PublishMode.schedule,
            ),
          ),
      ],
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
    HapticFeedback.mediumImpact();
    setState(() => submitting = true);
    await _launchController.forward(from: 0);
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
        remixOfId: widget.remixOfId,
      ),
    );
    setState(() {
      submitting = false;
      submitted = true;
    });
    HapticFeedback.heavyImpact();
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

/// CTA ปล่อยงาน: โหมดทันทีใช้เส้นแรงส่ง ส่วนโหมดตั้งเวลาใช้หน้าปัดจับเวลา
/// ตั้งใจไม่ใช้ visual language แบบ handshake ของปุ่มเชื่อมบัญชี
class _PublishCta extends StatefulWidget {
  const _PublishCta({
    required this.onPressed,
    required this.mode,
    required this.submitting,
    required this.label,
  });

  final VoidCallback? onPressed;
  final PublishMode mode;
  final bool submitting;
  final String label;

  @override
  State<_PublishCta> createState() => _PublishCtaState();
}

class _PublishCtaState extends State<_PublishCta> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted || widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final scheduled = widget.mode == PublishMode.schedule;
    final accent = scheduled
        ? Color.lerp(t.primary, t.warning, .22)!
        : Color.lerp(t.primary, t.success, .25)!;
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: reduced || !_pressed ? 1 : .97,
        duration: const Duration(milliseconds: 90),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [t.primary, accent],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(Radii.md),
            boxShadow: widget.onPressed == null || _pressed
                ? null
                : [
                    BoxShadow(
                      color: accent.withValues(alpha: .2),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                right: 14,
                top: 0,
                bottom: 0,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: scheduled
                      ? _ClockSignature(
                          key: const ValueKey('schedule'),
                          color: t.onPrimary,
                        )
                      : _LaunchSignature(
                          key: const ValueKey('now'),
                          color: t.onPrimary,
                        ),
                ),
              ),
              FilledButton.icon(
                key: const Key('publish-submit'),
                onPressed: widget.onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: t.primary.withValues(alpha: 0),
                  disabledBackgroundColor: t.surfaceElevated.withValues(
                    alpha: .82,
                  ),
                  foregroundColor: t.onPrimary,
                  disabledForegroundColor: t.textSecondary,
                  shadowColor: t.primary.withValues(alpha: 0),
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    widget.submitting
                        ? Icons.sync_rounded
                        : scheduled
                        ? Icons.event_available_rounded
                        : Icons.rocket_launch_outlined,
                    key: ValueKey('${widget.submitting}-$scheduled'),
                  ),
                ),
                label: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LaunchSignature extends StatelessWidget {
  const _LaunchSignature({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 54,
    child: Stack(
      alignment: Alignment.centerRight,
      children: [
        for (var i = 0; i < 3; i++)
          Positioned(
            right: 4.0 + (i * 9),
            child: Container(
              width: 16.0 - (i * 3),
              height: 2,
              color: color.withValues(alpha: .1 + (i * .05)),
            ),
          ),
        Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: .24)),
      ],
    ),
  );
}

class _ClockSignature extends StatelessWidget {
  const _ClockSignature({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 46,
    child: Center(
      child: Container(
        width: 27,
        height: 27,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: .2), width: 2),
        ),
        child: Icon(
          Icons.schedule_rounded,
          size: 16,
          color: color.withValues(alpha: .28),
        ),
      ),
    ),
  );
}

class _RemixBanner extends StatelessWidget {
  const _RemixBanner({required this.note});
  final String note;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.t.creative.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(Radii.md),
      border: Border.all(color: context.t.creative.withValues(alpha: .4)),
    ),
    child: Row(
      children: [
        Icon(Icons.auto_awesome_motion_outlined, color: context.t.creative),
        const SizedBox(width: 10),
        Expanded(
          child: Text(note, style: const TextStyle(fontSize: 12, height: 1.4)),
        ),
      ],
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
    required this.arrival,
  });
  final ShowcaseProduct product;
  final String? mediaName;
  final int durationSec;
  final String sourceLabel;
  final VoidCallback onPreview;
  final Animation<double> arrival;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: arrival,
    child: Material(
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
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: _RelayHandoffStrip(
                  animation: arrival,
                  sourceLabel: sourceLabel,
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
    ),
    builder: (context, child) {
      final progress = arrival.value;
      return Opacity(
        opacity: .35 + progress * .65,
        child: Transform.translate(
          offset: Offset((1 - progress) * -28, 0),
          child: Transform.scale(
            alignment: Alignment.centerLeft,
            scale: .975 + progress * .025,
            child: child,
          ),
        ),
      );
    },
  );

  static String _duration(int seconds) {
    final safe = seconds <= 0 ? 30 : seconds;
    return '${(safe ~/ 60).toString().padLeft(2, '0')}:${(safe % 60).toString().padLeft(2, '0')}';
  }
}

class _RelayHandoffStrip extends StatelessWidget {
  const _RelayHandoffStrip({
    required this.animation,
    required this.sourceLabel,
  });

  final Animation<double> animation;
  final String sourceLabel;

  String get _source =>
      sourceLabel.toLowerCase().contains('inbox') ? 'AI INBOX' : 'MEDIA';

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final progress = animation.value;
      final arrived = progress > .88;
      return Container(
        key: const Key('publish-relay-strip'),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: context.t.surface.withValues(alpha: .84),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: context.t.primary.withValues(alpha: .45)),
          boxShadow: [
            BoxShadow(
              color: context.t.primary.withValues(alpha: .13 * progress),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.move_to_inbox_rounded,
              size: 14,
              color: context.t.primary,
            ),
            const SizedBox(width: 5),
            Text(
              _source,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 2,
                      color: context.t.primary.withValues(alpha: .18),
                    ),
                    Container(
                      width: constraints.maxWidth * progress,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.t.primary.withValues(alpha: .3),
                            context.t.primary,
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment(-1 + progress * 2, 0),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: context.t.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.t.primary.withValues(alpha: .7),
                              blurRadius: 7,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 7),
            AnimatedSwitcher(
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              child: Row(
                key: ValueKey(arrived),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    arrived
                        ? Icons.verified_rounded
                        : Icons.arrow_forward_rounded,
                    size: 14,
                    color: arrived
                        ? context.t.success
                        : context.t.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    arrived ? 'พร้อมตรวจ' : 'กำลังส่งต่อ',
                    style: TextStyle(
                      color: arrived
                          ? context.t.success
                          : context.t.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
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

class _PublishLaunchOverlay extends StatelessWidget {
  const _PublishLaunchOverlay({
    required this.animation,
    required this.scheduled,
  });

  final Animation<double> animation;
  final bool scheduled;

  String _status(double progress) {
    if (progress < .34) return 'กำลังตรวจความพร้อมครั้งสุดท้าย';
    if (progress < .7) return 'กำลังส่งงานเข้าคิวคอนเทนต์';
    return scheduled
        ? 'ล็อกเวลาที่ตั้งไว้เรียบร้อย'
        : 'เตรียมพร้อมเผยแพร่ทันที';
  }

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('publish-launch-overlay'),
    color: context.t.surface.withValues(alpha: .96),
    child: SafeArea(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final progress = Curves.easeInOutCubic.transform(animation.value);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: .9 + progress * .1,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.t.primary.withValues(alpha: .12),
                        border: Border.all(color: context.t.primary),
                        boxShadow: [
                          BoxShadow(
                            color: context.t.primary.withValues(
                              alpha: .12 + progress * .12,
                            ),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: Icon(
                        scheduled
                            ? Icons.event_available_rounded
                            : Icons.rocket_launch_rounded,
                        size: 34,
                        color: context.t.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  const Text(
                    'กำลังส่งต่อคอนเทนต์',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    child: Text(
                      _status(progress),
                      key: ValueKey(_status(progress)),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: progress > .7
                            ? context.t.success
                            : context.t.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  SizedBox(
                    width: 330,
                    height: 70,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _LaunchPathPainter(
                              color: context.t.primary,
                              progress: progress,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _LaunchStage(
                                icon: Icons.verified_outlined,
                                label: 'ตรวจพร้อม',
                                reached: progress >= .05,
                              ),
                            ),
                            Expanded(
                              child: _LaunchStage(
                                icon: Icons.queue_play_next_rounded,
                                label: 'เข้าคิว',
                                reached: progress >= .38,
                              ),
                            ),
                            Expanded(
                              child: _LaunchStage(
                                icon: scheduled
                                    ? Icons.schedule_rounded
                                    : Icons.send_rounded,
                                label: scheduled ? 'ตั้งเวลา' : 'พร้อมส่ง',
                                reached: progress >= .74,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  SizedBox(
                    width: 260,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: context.t.primary.withValues(
                          alpha: .12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'โหมดสาธิต · ยังไม่ได้ส่งไป TikTok จริง',
                    style: TextStyle(
                      color: context.t.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _LaunchStage extends StatelessWidget {
  const _LaunchStage({
    required this.icon,
    required this.label,
    required this.reached,
  });

  final IconData icon;
  final String label;
  final bool reached;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AnimatedContainer(
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 180),
        width: reached ? 38 : 34,
        height: reached ? 38 : 34,
        decoration: BoxDecoration(
          color: reached
              ? context.t.primary.withValues(alpha: .14)
              : context.t.surfaceContainer,
          shape: BoxShape.circle,
          border: Border.all(
            color: reached ? context.t.primary : context.t.border,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: reached ? context.t.primary : context.t.textSecondary,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        label,
        style: TextStyle(
          color: reached ? context.t.textPrimary : context.t.textSecondary,
          fontSize: 10,
          fontWeight: reached ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ],
  );
}

class _LaunchPathPainter extends CustomPainter {
  const _LaunchPathPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width / 6, 19);
    final end = Offset(size.width * 5 / 6, 19);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = color.withValues(alpha: .15)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    final activeEnd = Offset(
      start.dx + (end.dx - start.dx) * progress,
      start.dy,
    );
    canvas.drawLine(
      start,
      activeEnd,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    if (progress < .99) {
      canvas.drawCircle(
        activeEnd,
        8,
        Paint()
          ..color = color.withValues(alpha: .2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(activeEnd, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_LaunchPathPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _Accepted extends StatefulWidget {
  const _Accepted({required this.mode, required this.product});
  final PublishMode mode;
  final ShowcaseProduct product;

  @override
  State<_Accepted> createState() => _AcceptedState();
}

class _AcceptedState extends State<_Accepted>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _icon;
  late final Animation<double> _body;

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
      duration: reduced ? Duration.zero : const Duration(milliseconds: 900),
    )..forward();
    _icon = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0, .55, curve: Curves.easeOutBack),
    );
    _body = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(.25, 1, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _icon,
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.t.success.withValues(alpha: .14),
                    border: Border.all(color: context.t.success, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: context.t.success.withValues(alpha: .25),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.done_all_rounded,
                    size: 54,
                    color: context.t.success,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              FadeTransition(
                opacity: _body,
                child: Column(
                  children: [
                    Text(
                      widget.mode == PublishMode.schedule
                          ? 'ตั้งเวลาเรียบร้อย'
                          : 'รับงานเผยแพร่แล้ว',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.product.name}\nถูกเพิ่มในคิวคอนเทนต์แล้ว',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.t.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                    _DemoPublishTimeline(
                      scheduled: widget.mode == PublishMode.schedule,
                    ),
                    const SizedBox(height: Spacing.xl),
                    FilledButton.icon(
                      onPressed: () => context.go('/content'),
                      icon: const Icon(Icons.video_library_outlined),
                      label: const Text('ติดตามสถานะคอนเทนต์'),
                    ),
                  ],
                ),
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

class _DemoPublishTimeline extends StatelessWidget {
  const _DemoPublishTimeline({required this.scheduled});

  final bool scheduled;

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('สร้างคอนเทนต์แล้ว', Icons.check_rounded),
      ('เข้าคิวเผยแพร่แล้ว', Icons.hourglass_top_rounded),
      (
        scheduled ? 'รอถึงเวลาที่ตั้งไว้' : 'พร้อมส่งไปยัง TikTok',
        Icons.rocket_launch_outlined,
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: context.t.success.withValues(alpha: .14),
                  shape: BoxShape.circle,
                  border: Border.all(color: context.t.success),
                ),
                child: Icon(steps[i].$2, size: 16, color: context.t.success),
              ),
              const SizedBox(width: Spacing.md),
              Text(steps[i].$1),
            ],
          ),
          if (i != steps.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 2,
                  height: 22,
                  color: context.t.success.withValues(alpha: .4),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
