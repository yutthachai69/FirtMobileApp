import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/relay_state_panel.dart';
import '../../../core/auth/auth_controller.dart';
import '../../showcase/domain/showcase_product.dart';
import '../../showcase/presentation/product_artwork.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.auth});
  final AuthController auth;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int step = 0;
  String goal = 'ปักตะกร้าให้คอนเทนต์ AI';
  final sources = <String>{'Google Flow'};
  ShowcaseProduct? product = ShowcaseProduct.available.isEmpty
      ? null
      : ShowcaseProduct.available.first;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('เริ่มใช้ RelayContent'),
      actions: [
        TextButton(onPressed: _skip, child: const Text('ข้าม')),
        const SizedBox(width: 6),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(3),
        child: LinearProgressIndicator(value: (step + 1) / 3),
      ),
    ),
    body: SafeArea(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: ListView(
          key: ValueKey(step),
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.lg,
            Spacing.lg,
            120,
          ),
          children: switch (step) {
            0 => _goalStep(context),
            1 => _sourceStep(context),
            _ => _productStep(context),
          },
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, 8, Spacing.lg, 14),
        child: Row(
          children: [
            if (step > 0) ...[
              IconButton.outlined(
                onPressed: () => setState(() => step--),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: FilledButton.icon(
                key: const Key('onboarding-next'),
                onPressed: step == 2 ? _finish : () => setState(() => step++),
                icon: Icon(
                  step == 2
                      ? Icons.rocket_launch_outlined
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(step == 2 ? 'เริ่มรับคอนเทนต์' : 'ถัดไป'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  List<Widget> _goalStep(BuildContext context) => [
    const _Heading(
      title: 'วันนี้คุณอยากทำอะไร?',
      detail: 'เลือกเป้าหมายหลัก เพื่อจัดทางลัดในแอปให้เหมาะกับงานของคุณ',
    ),
    const SizedBox(height: Spacing.lg),
    for (final item in const [
      (
        Icons.hub_outlined,
        'ปักตะกร้าให้คอนเทนต์ AI',
        'รับคลิปจากเครื่องมือ AI แล้วผูกสินค้าและตั้งเวลา',
      ),
      (
        Icons.video_camera_back_outlined,
        'ถ่ายรีวิวสินค้าเร็วขึ้น',
        'ใช้ shot list และโค้ชช่วยถ่ายทีละช่วง',
      ),
      (
        Icons.calendar_month_outlined,
        'จัดคิวคอนเทนต์หลายชิ้น',
        'รวมงานทั้งหมดไว้ในปฏิทินและติดตามสถานะ',
      ),
    ])
      _SelectCard(
        icon: item.$1,
        title: item.$2,
        detail: item.$3,
        selected: goal == item.$2,
        onTap: () => setState(() => goal = item.$2),
      ),
  ];

  List<Widget> _sourceStep(BuildContext context) => [
    const _Heading(
      title: 'รับคอนเทนต์จากที่ไหน?',
      detail:
          'เลือกบริการที่คุณใช้เป็นประจำ ตอนนี้เป็นการจำลอง UX การเชื่อมบัญชี',
    ),
    const SizedBox(height: Spacing.lg),
    for (final item in const [
      (Icons.auto_awesome_rounded, 'Google Flow', 'วิดีโอที่สร้างด้วย Veo'),
      (Icons.movie_filter_outlined, 'Sora', 'วิดีโอจากโปรเจกต์ของคุณ'),
      (
        Icons.motion_photos_auto_outlined,
        'Runway',
        'งาน Gen-3 และโปรเจกต์ล่าสุด',
      ),
    ])
      _SourceCard(
        icon: item.$1,
        name: item.$2,
        detail: item.$3,
        connected: sources.contains(item.$2),
        onChanged: () => setState(
          () => sources.contains(item.$2)
              ? sources.remove(item.$2)
              : sources.add(item.$2),
        ),
      ),
    const SizedBox(height: 10),
    Text(
      'คุณเปลี่ยนแหล่งเชื่อมได้ภายหลังในหน้าโปรไฟล์',
      style: TextStyle(color: context.t.textSecondary, fontSize: 12),
    ),
  ];

  List<Widget> _productStep(BuildContext context) => [
    const _Heading(
      title: 'เลือกสินค้าชิ้นแรก',
      detail: 'คอนเทนต์ที่รับเข้ามาจะถูกพาไปตรวจตะกร้ากับสินค้านี้ก่อนเผยแพร่',
    ),
    const SizedBox(height: Spacing.lg),
    for (final item in ShowcaseProduct.available.where((item) => item.inStock))
      _ProductChoice(
        product: item,
        selected: product?.id == item.id,
        onTap: () => setState(() => product = item),
      ),
    if (ShowcaseProduct.available.isEmpty)
      const RelayStatePanel(
        kind: RelayStateKind.empty,
        title: 'ยังไม่มีสินค้าจาก Showcase',
        message: 'เข้าแอปก่อน แล้วเชื่อม TikTok Shop เพื่อซิงก์สินค้าจริง',
      ),
    const SizedBox(height: 12),
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.t.success.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: context.t.success),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'พร้อมเริ่ม: $goal',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  ];

  void _skip() {
    widget.auth.completeOnboarding();
    context.go('/');
  }

  void _finish() {
    widget.auth.completeOnboarding();
    final selected = product;
    if (selected == null) {
      context.go('/showcase');
      return;
    }
    context.go('/create/import-ai', extra: selected);
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.detail});
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(
        detail,
        style: TextStyle(color: context.t.textSecondary, height: 1.5),
      ),
    ],
  );
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    color: selected ? context.t.primary.withValues(alpha: .1) : null,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? context.t.primary : context.t.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(detail, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? context.t.primary : context.t.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.name,
    required this.detail,
    required this.connected,
    required this.onChanged,
  });
  final IconData icon;
  final String name;
  final String detail;
  final bool connected;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: SwitchListTile(
      value: connected,
      onChanged: (_) => onChanged(),
      secondary: Icon(icon, color: connected ? context.t.primary : null),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(detail),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    ),
  );
}

class _ProductChoice extends StatelessWidget {
  const _ProductChoice({
    required this.product,
    required this.selected,
    required this.onTap,
  });
  final ShowcaseProduct product;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    color: selected ? context.t.success.withValues(alpha: .08) : null,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ProductArtwork(product: product, width: 64, height: 72),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'คอมมิชชัน ฿${product.commissionBaht}/ชิ้น',
                    style: TextStyle(color: context.t.success, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? context.t.success : context.t.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );
}
