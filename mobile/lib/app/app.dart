import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/composer/data/composer_api.dart';
import '../features/composer/presentation/composer_controller.dart';
import '../features/composer/presentation/tiktok_composer_page.dart';
import '../features/connections/presentation/connections_page.dart';
import '../features/create/presentation/create_page.dart';
import '../features/home/presentation/content_library_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/showcase/presentation/showcase_page.dart';
import 'providers.dart';
import 'theme/app_theme.dart';

class RelayApp extends ConsumerStatefulWidget {
  const RelayApp({super.key});
  @override
  ConsumerState<RelayApp> createState() => _RelayAppState();
}

class _RelayAppState extends ConsumerState<RelayApp> {
  late final AuthController auth;
  late final GoRouter router;
  @override
  void initState() {
    super.initState();
    auth = ref.read(authProvider);
    router = GoRouter(
      initialLocation: '/session',
      refreshListenable: auth,
      redirect: (context, state) {
        final path = state.uri.path;

        // ล็อกอินแล้วต้องเดินไปหน้าไหนก็ได้ — เดิม redirect บังคับกลับ '/' เสมอ
        // ทำให้เปิดหน้าอื่นไม่ได้เลย
        return switch (auth.phase) {
          SessionPhase.starting ||
          SessionPhase.unavailable => path == '/session' ? null : '/session',
          SessionPhase.signedOut => path == '/login' ? null : '/login',
          SessionPhase.signedIn =>
            (path == '/login' || path == '/session') ? '/' : null,
        };
      },
      routes: [
        GoRoute(
          path: '/session',
          builder: (_, _) => SessionPage(auth: auth),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => AuthPage(auth: auth),
        ),
        GoRoute(
          path: '/',
          builder: (_, _) =>
              HomePage(auth: auth, controller: ref.read(homeProvider)),
        ),
        GoRoute(
          path: '/connections',
          builder: (_, _) =>
              ConnectionsPage(controller: ref.read(connectionsProvider)),
        ),
        GoRoute(
          path: '/create',
          builder: (_, _) => CreatePage(controller: ref.read(createProvider)),
        ),
        GoRoute(
          path: '/showcase',
          builder: (_, _) => const ShowcasePage(),
        ),
        GoRoute(
          path: '/content',
          builder: (_, _) =>
              ContentLibraryPage(controller: ref.read(homeProvider)),
        ),
        GoRoute(
          path: '/composer',
          builder: (context, state) {
            // Composer ต้องรู้ว่าโพสต์คอนเทนต์ไหน ด้วยบัญชีไหน และวิดีโอยาวเท่าไหร่
            // (ความยาวใช้ตรวจกฎ R7 ของ TikTok) จึงรับผ่าน extra แทน query param
            final args = state.extra as ComposerArgs?;
            if (args == null) return const _MissingArgs();

            return TikTokComposerPage(
              controller: ComposerController(
                auth: auth,
                api: HttpComposerApi(ref.read(apiClientProvider)),
                contentId: args.contentId,
                connectionId: args.connectionId,
                videoDurationSec: args.videoDurationSec,
                isAigc: args.isAigc,
              ),
            );
          },
        ),
      ],
    );
    auth.restore();
  }

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'RelayContent',
    debugShowCheckedModeBanner: false,
    theme: appTheme(Brightness.light),
    darkTheme: appTheme(Brightness.dark),
    themeMode: ThemeMode.dark,
    routerConfig: router,
  );
}

class SessionPage extends StatelessWidget {
  const SessionPage({super.key, required this.auth});
  final AuthController auth;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: auth,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.layers_rounded, size: 52),
                  const SizedBox(height: 20),
                  const Text(
                    'RelayContent',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  if (auth.phase == SessionPhase.starting) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('กำลังเปิดบัญชีของคุณ…'),
                  ] else ...[
                    Text(
                      auth.error ?? 'เชื่อมต่อไม่ได้',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: auth.busy ? null : auth.restore,
                      child: const Text('ลองอีกครั้ง'),
                    ),
                    TextButton(
                      onPressed: auth.busy ? null : auth.signOut,
                      child: const Text('ออกจากระบบในเครื่อง'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// _MissingArgs กันหน้า Composer พังเมื่อถูกเปิดตรง ๆ โดยไม่มีข้อมูล
/// (เช่นผู้ใช้ refresh หน้าเว็บตอนอยู่ที่ /composer)
class _MissingArgs extends StatelessWidget {
  const _MissingArgs();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('โพสต์ลง TikTok')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'เปิดหน้านี้ตรง ๆ ไม่ได้\nกรุณาเริ่มจากการเลือกวิดีโอ',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('กลับหน้าหลัก'),
            ),
          ],
        ),
      ),
    ),
  );
}
