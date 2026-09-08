import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme/tokens.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) {
        navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        );
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          label: 'หน้าหลัก',
        ),
        const NavigationDestination(
          icon: Icon(Icons.shopping_bag_outlined),
          selectedIcon: Icon(Icons.shopping_bag_rounded),
          label: 'สินค้า',
        ),
        NavigationDestination(
          icon: _CreateIcon(color: context.t.creative),
          selectedIcon: _CreateIcon(color: context.t.creative, selected: true),
          label: 'สร้าง',
        ),
        const NavigationDestination(
          icon: Icon(Icons.video_library_outlined),
          selectedIcon: Icon(Icons.video_library_rounded),
          label: 'คอนเทนต์',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'โปรไฟล์',
        ),
      ],
    ),
  );
}

class _CreateIcon extends StatelessWidget {
  const _CreateIcon({required this.color, this.selected = false});
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: selected
          ? [BoxShadow(color: color.withValues(alpha: .35), blurRadius: 14)]
          : null,
    ),
    child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
  );
}

class ProductsLandingPage extends StatelessWidget {
  const ProductsLandingPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('สินค้าใน Showcase')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.lg),
          child: _LandingCard(
            icon: Icons.shopping_bag_outlined,
            title: 'เตรียมสินค้าสำหรับทำคลิป',
            description: 'เชื่อมบัญชี TikTok Shop Creator แล้วสินค้าจาก Showcase จะปรากฏที่นี่',
            actionLabel: 'จัดการการเชื่อมต่อ',
            onPressed: () => context.go('/connections'),
          ),
        ),
      ),
    ),
  );
}

class ContentLandingPage extends StatelessWidget {
  const ContentLandingPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('คอนเทนต์')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.lg),
          child: _LandingCard(
            icon: Icons.video_library_outlined,
            title: 'คลิปทั้งหมดจะอยู่ที่นี่',
            description: 'ติดตามฉบับร่าง คลิปที่กำลังสร้าง ตั้งเวลาไว้ และโพสต์สำเร็จได้ในที่เดียว',
            actionLabel: 'สร้างคลิปใหม่',
            onPressed: () => context.go('/create'),
            creative: true,
          ),
        ),
      ),
    ),
  );
}

class _LandingCard extends StatelessWidget {
  const _LandingCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
    this.creative = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;
  final bool creative;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 420),
    padding: const EdgeInsets.all(Spacing.lg),
    decoration: BoxDecoration(
      color: context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: context.t.border),
    ),
    child: Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: context.t.primary.withValues(alpha: .12),
            shape: BoxShape.circle,
            border: Border.all(color: context.t.primary.withValues(alpha: .3)),
          ),
          child: Icon(icon, color: context.t.primary, size: 34),
        ),
        const SizedBox(height: Spacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          description,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.t.textSecondary, height: 1.55),
        ),
        const SizedBox(height: Spacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: creative
                ? FilledButton.styleFrom(
                    backgroundColor: context.t.creative,
                    foregroundColor: Colors.white,
                  )
                : null,
            onPressed: onPressed,
            child: Text(actionLabel),
          ),
        ),
      ],
    ),
  );
}
