import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/config/app_config.dart';
import '../../showcase/domain/showcase_product.dart';
import '../../showcase/presentation/product_artwork.dart';

enum _CreatePath { inbox, upload, guided }

class CreateHubPage extends StatefulWidget {
  const CreateHubPage({super.key, this.selectedProduct});

  final ShowcaseProduct? selectedProduct;

  @override
  State<CreateHubPage> createState() => _CreateHubPageState();
}

class _CreateHubPageState extends State<CreateHubPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  _CreatePath _selected = _CreatePath.inbox;

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
      duration: reduced ? Duration.zero : const Duration(milliseconds: 760),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _select(_CreatePath path) {
    if (_selected == path) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = path);
  }

  void _continue() {
    HapticFeedback.lightImpact();
    final product = widget.selectedProduct;
    switch (_selected) {
      case _CreatePath.inbox:
        context.go('/create/import-ai', extra: product);
      case _CreatePath.upload:
        context.go('/create/upload', extra: product);
      case _CreatePath.guided:
        if (product == null) {
          context.go('/showcase');
        } else {
          context.go('/create/guided', extra: product);
        }
    }
  }

  String get _ctaLabel => switch (_selected) {
    _CreatePath.inbox => 'เปิด AI Content Inbox',
    _CreatePath.upload => 'เลือกคลิปจากเครื่อง',
    _CreatePath.guided =>
      widget.selectedProduct == null
          ? 'เลือกสินค้าก่อนถ่าย'
          : 'เปิด Guided Camera',
  };

  IconData get _ctaIcon => switch (_selected) {
    _CreatePath.inbox => Icons.hub_outlined,
    _CreatePath.upload => Icons.upload_file_rounded,
    _CreatePath.guided => Icons.video_camera_back_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final product = widget.selectedProduct;
    final choices = [
      (
        path: _CreatePath.inbox,
        icon: Icons.hub_outlined,
        title: 'รับคอนเทนต์จาก AI',
        description: 'รวมคลิปจากเครื่องมือ AI ที่ใช้อยู่ แล้วจัดคิวต่อในแอป',
        badge: 'แนะนำ',
        color: context.t.primary,
        tags: const ['นำเข้าเร็ว', 'หลายแหล่ง', 'พร้อมจัดคิว'],
      ),
      (
        path: _CreatePath.upload,
        icon: Icons.video_library_outlined,
        title: 'นำเข้าคลิปจากมือถือ',
        description: 'เลือกคลิป ตัดช่วงที่ต้องการ และเขียนแคปชันด้วยตัวเอง',
        badge: null,
        color: context.t.success,
        tags: const ['Trim', 'Preview', 'ควบคุมเอง'],
      ),
      (
        path: _CreatePath.guided,
        icon: Icons.video_camera_back_outlined,
        title: 'ถ่ายรีวิวแบบมีไกด์',
        description: 'ถ่ายตาม shot list ทีละช่วง แล้วเลือกเทคที่ดีที่สุด',
        badge: 'ใหม่',
        color: context.t.warning,
        tags: const ['Shot list', 'เลือกเทค', 'เหมาะกับมือใหม่'],
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างคอนเทนต์')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Spacing.md, 8, Spacing.md, 110),
          children: [
            Text(
              'อยากเริ่มจากตรงไหน?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'เลือกหนึ่งเส้นทาง แล้ว RelayContent จะพาไปจนพร้อมเผยแพร่',
              style: TextStyle(color: context.t.textSecondary),
            ),
            const SizedBox(height: Spacing.lg),
            if (product != null) ...[
              _ProductStrip(product: product),
              const SizedBox(height: Spacing.lg),
            ],
            for (var i = 0; i < choices.length; i++) ...[
              _StaggerEntry(
                animation: _entrance,
                index: i,
                child: _CreateChoice(
                  icon: choices[i].icon,
                  title: choices[i].title,
                  description: choices[i].description,
                  badge: choices[i].badge,
                  color: choices[i].color,
                  tags: choices[i].tags,
                  selected: _selected == choices[i].path,
                  onTap: () => _select(choices[i].path),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _StaggerEntry(
              animation: _entrance,
              index: 3,
              child: _AiLabCard(
                product: product,
                onTap: () {
                  if (product == null && AppConfig.isLive) {
                    context.go('/showcase');
                    return;
                  }
                  context.go(
                    '/create/ai',
                    extra: product ?? ShowcaseProduct.available.first,
                  );
                },
              ),
            ),
            if (product == null) ...[
              const SizedBox(height: Spacing.lg),
              OutlinedButton.icon(
                onPressed: () => context.go('/showcase'),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('เลือกสินค้าก่อนสร้าง'),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.md, 8, Spacing.md, 12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(.04, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: _PressCta(
              key: ValueKey(_selected),
              onPressed: _continue,
              path: _selected,
              icon: _ctaIcon,
              label: _ctaLabel,
            ),
          ),
        ),
      ),
    );
  }
}

class _StaggerEntry extends StatelessWidget {
  const _StaggerEntry({
    required this.animation,
    required this.index,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (.08 + index * .11).clamp(0.0, .72);
    final motion = CurvedAnimation(
      parent: animation,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: motion,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .08),
          end: Offset.zero,
        ).animate(motion),
        child: child,
      ),
    );
  }
}

class _ProductStrip extends StatelessWidget {
  const _ProductStrip({required this.product});
  final ShowcaseProduct product;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: context.t.border),
    ),
    child: Row(
      children: [
        ProductArtwork(product: product, width: 52, height: 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'กำลังสร้างให้สินค้านี้',
                style: TextStyle(fontSize: 11),
              ),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'รับ ฿${product.commissionBaht}/ชิ้น',
                style: TextStyle(color: context.t.success, fontSize: 12),
              ),
            ],
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

class _CreateChoice extends StatelessWidget {
  const _CreateChoice({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.tags,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final List<String> tags;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutCubic,
    decoration: BoxDecoration(
      color: selected
          ? Color.alphaBlend(
              color.withValues(alpha: .08),
              context.t.surfaceContainer,
            )
          : context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(
        color: color.withValues(alpha: selected ? .9 : .3),
        width: selected ? 1.5 : 1,
      ),
      boxShadow: selected
          ? [
              BoxShadow(
                color: color.withValues(alpha: .16),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ]
          : null,
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(selected ? 18 : Spacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    width: selected ? 54 : 48,
                    height: selected ? 54 : 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: selected ? .2 : .12),
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: Icon(icon, color: color, size: selected ? 29 : 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: .13),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  badge!,
                                  style: TextStyle(color: color, fontSize: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            color: context.t.textSecondary,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: selected ? .25 : 0,
                    duration: const Duration(milliseconds: 260),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: selected ? color : context.t.textSecondary,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 240),
                sizeCurve: Curves.easeOutCubic,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ChoiceSignal(color: color),
                        const SizedBox(height: 11),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            for (final tag in tags)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: color.withValues(alpha: .25),
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(color: color, fontSize: 10),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                crossFadeState: selected
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ChoiceSignal extends StatelessWidget {
  const _ChoiceSignal({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 680),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => SizedBox(
        height: 22,
        width: double.infinity,
        child: CustomPaint(
          painter: _ChoiceSignalPainter(color: color, progress: progress),
        ),
      ),
    );
  }
}

class _ChoiceSignalPainter extends CustomPainter {
  const _ChoiceSignalPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 7.0;
    final y = size.height / 2;
    final start = Offset(inset, y);
    final end = Offset(size.width - inset, y);
    final line = Paint()
      ..color = color.withValues(alpha: .24)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, line);

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

    for (final fraction in const [0.0, .5, 1.0]) {
      final center = Offset(start.dx + (end.dx - start.dx) * fraction, y);
      final reached = progress + .03 >= fraction;
      canvas.drawCircle(
        center,
        reached ? 4.2 : 3.2,
        Paint()..color = reached ? color : color.withValues(alpha: .25),
      );
    }
    canvas.drawCircle(
      activeEnd,
      8,
      Paint()
        ..color = color.withValues(alpha: .18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(activeEnd, 3.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ChoiceSignalPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _PressCta extends StatefulWidget {
  const _PressCta({
    super.key,
    required this.path,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final _CreatePath path;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_PressCta> createState() => _PressCtaState();
}

class _PressCtaState extends State<_PressCta> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final t = context.t;
    final accent = switch (widget.path) {
      _CreatePath.inbox => t.creative,
      _CreatePath.upload => t.success,
      _CreatePath.guided => t.warning,
    };
    final endColor = Color.lerp(accent, t.primary, .32)!;
    final darkFill =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark;
    final foreground = darkFill
        ? (Theme.of(context).brightness == Brightness.dark
              ? t.textPrimary
              : t.surfaceContainer)
        : (Theme.of(context).brightness == Brightness.dark
              ? t.surface
              : t.textPrimary);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 480),
      curve: Curves.easeOutBack,
      builder: (context, reveal, child) => Transform.scale(
        scale: .96 + (.04 * reveal),
        child: Opacity(opacity: reveal.clamp(0, 1), child: child),
      ),
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: reduced || !_pressed ? 1 : .968,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, endColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(Radii.md),
              boxShadow: _pressed
                  ? null
                  : [
                      BoxShadow(
                        color: accent.withValues(alpha: .22),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: _CtaSignature(
                    path: widget.path,
                    color: foreground,
                    pressed: _pressed,
                  ),
                ),
                FilledButton.icon(
                  onPressed: widget.onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent.withValues(alpha: 0),
                    foregroundColor: foreground,
                    shadowColor: accent.withValues(alpha: 0),
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                  ),
                  icon: AnimatedSlide(
                    duration: const Duration(milliseconds: 120),
                    offset: _pressed
                        ? switch (widget.path) {
                            _CreatePath.inbox => const Offset(.12, 0),
                            _CreatePath.upload => const Offset(0, -.14),
                            _CreatePath.guided => const Offset(.08, 0),
                          }
                        : Offset.zero,
                    child: Icon(widget.icon),
                  ),
                  label: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ลายเซ็นด้านขวาของ CTA เปลี่ยนตาม “ความหมาย” ของเส้นทาง ไม่ใช่สกินเดียวกัน
/// ทั้งหมด: AI = กลุ่มประกาย, upload = ข้อมูลไหลขึ้น, camera = live record
class _CtaSignature extends StatelessWidget {
  const _CtaSignature({
    required this.path,
    required this.color,
    required this.pressed,
  });

  final _CreatePath path;
  final Color color;
  final bool pressed;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: pressed ? .9 : 1,
    duration: const Duration(milliseconds: 120),
    child: SizedBox(
      width: 58,
      child: switch (path) {
        _CreatePath.inbox => Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 25,
              color: color.withValues(alpha: .2),
            ),
            Positioned(left: 7, top: 12, child: _dot(5)),
            Positioned(right: 5, bottom: 11, child: _dot(3)),
          ],
        ),
        _CreatePath.upload => Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Positioned(
                bottom: 12.0 + (i * 8),
                child: Container(
                  width: 24.0 - (i * 5),
                  height: 2,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12 + (i * .07)),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            Icon(
              Icons.arrow_upward_rounded,
              size: 20,
              color: color.withValues(alpha: .22),
            ),
          ],
        ),
        _CreatePath.guided => Center(
          child: Container(
            width: 30,
            height: 22,
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: .22)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: .38),
                ),
              ),
            ),
          ),
        ),
      },
    ),
  );

  Widget _dot(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .28),
      shape: BoxShape.circle,
    ),
  );
}

class _AiLabCard extends StatelessWidget {
  const _AiLabCard({required this.product, required this.onTap});

  final ShowcaseProduct? product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.t.creative.withValues(alpha: .07),
    borderRadius: BorderRadius.circular(Radii.lg),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: context.t.creative),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ทดลองสร้างด้วย AI ใน RelayContent',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    product == null
                        ? 'ทดลองกับสินค้าตัวอย่าง'
                        : 'สร้างไอเดียจาก ${product!.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.t.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.t.creative.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'LAB',
                style: TextStyle(color: context.t.creative, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
