import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// โครงร่างระหว่างโหลด — แทน CircularProgressIndicator กลางจอ
///
/// รูปทรงเลียนแบบการ์ดจริงที่กำลังจะแสดง ผู้ใช้จึงเดาได้ว่ากำลังรออะไร
/// เคารพ [MediaQueryData.disableAnimations] (ผู้ใช้เปิด "ลดการเคลื่อนไหว")
/// โดยหยุด shimmer แล้วแสดงเป็นพื้นทึบนิ่ง ๆ แทน
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = Radii.sm,
  });

  /// กล่องกลม ๆ ใช้ทำ avatar หรือ thumbnail
  const Skeleton.circle(double size, {Key? key})
    : this(key: key, width: size, height: size, radius: size / 2);

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ผู้ใช้สลับ "ลดการเคลื่อนไหว" ได้ระหว่างที่จอยังค้างโหลด
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final still = MediaQuery.of(context).disableAnimations;

    final box = ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ColoredBox(color: t.surfaceContainer),
      ),
    );

    if (still) {
      return box;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // -1 → 2 พาแถบไฮไลต์เลื่อนจากซ้ายสุดออกไปขวาสุดแล้ววน
        final shift = _controller.value * 3 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(shift - 1, 0),
              end: Alignment(shift + 1, 0),
              colors: [
                t.surfaceContainer,
                t.surfaceElevated,
                t.surfaceContainer,
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: box,
    );
  }
}

/// รายการการ์ดจำลองสำหรับหน้าที่โหลดเป็น list (หน้าหลัก, คอนเทนต์)
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.md,
        Spacing.md,
        Spacing.xl,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.md),
      itemBuilder: (context, _) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: t.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: t.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(width: 56, height: 56, radius: Radii.md),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Skeleton(height: 14),
                SizedBox(height: Spacing.sm),
                Skeleton(width: 160, height: 12),
                SizedBox(height: Spacing.md),
                Skeleton(width: 96, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
