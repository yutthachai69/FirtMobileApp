import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/config/app_config.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/auth/presentation/onboarding_page.dart';
import '../features/composer/data/composer_api.dart';
import '../features/composer/presentation/composer_controller.dart';
import '../features/composer/presentation/tiktok_composer_page.dart';
import '../features/connections/presentation/connections_page.dart';
import '../features/create/presentation/ai_create_page.dart';
import '../features/create/presentation/ai_sources_page.dart';
import '../features/create/presentation/create_hub_page.dart';
import '../features/create/presentation/create_page.dart';
import '../features/create/presentation/batch_create_page.dart';
import '../features/create/presentation/guided_film_page.dart';
import '../features/create/presentation/publish_review_page.dart';
import '../features/home/domain/content_store.dart';
import '../features/home/domain/home_data.dart' as home;
import '../features/home/presentation/content_detail_page.dart';
import '../features/home/presentation/content_library_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/home/presentation/notifications_page.dart';
import '../features/home/presentation/review_queue_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/showcase/domain/showcase_product.dart';
import '../features/showcase/presentation/product_detail_page.dart';
import '../features/showcase/presentation/showcase_page.dart';
import 'main_shell.dart';
import 'motion/motion_tokens.dart';
import 'navigation/relay_page.dart';
import 'providers.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'widgets/relay_state_panel.dart';

class RelayApp extends ConsumerStatefulWidget {
  const RelayApp({super.key});
  @override
  ConsumerState<RelayApp> createState() => _RelayAppState();
}

class _RelayAppState extends ConsumerState<RelayApp> {
  late final AuthController auth;
  late final ContentStore contentStore;
  late final GoRouter router;
  ThemeMode themeMode = ThemeMode.dark;
  bool reducedMotion = false;
  @override
  void initState() {
    super.initState();
    auth = ref.read(authProvider);
    contentStore = ref.read(contentStoreProvider);
    // Starts optional FCM token registration; it is a no-op until Firebase is
    // configured for the current mobile build.
    ref.read(pushNotificationsProvider);
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
            auth.justRegistered
                ? (path == '/onboarding' ? null : '/onboarding')
                : (path == '/login' || path == '/session')
                ? '/'
                : null,
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
          path: '/onboarding',
          builder: (_, _) => OnboardingPage(auth: auth),
        ),
        StatefulShellRoute.indexedStack(
          builder: (_, _, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => HomePage(
                    auth: auth,
                    controller: ref.read(homeProvider),
                    store: contentStore,
                    notifications: ref.read(notificationsProvider),
                  ),
                ),
                GoRoute(
                  path: '/notifications',
                  pageBuilder: (_, state) => relayPage(
                    state,
                    NotificationsPage(
                      controller: ref.read(notificationsProvider),
                    ),
                    motion: RelayPageMotion.detail,
                  ),
                ),
                GoRoute(
                  path: '/review',
                  pageBuilder: (_, state) => relayPage(
                    state,
                    ReviewQueuePage(store: contentStore),
                    motion: RelayPageMotion.detail,
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/showcase',
                  builder: (_, _) => ShowcasePage(
                    store: contentStore,
                    controller: ref.read(productsProvider),
                  ),
                  routes: [
                    GoRoute(
                      path: 'import-ai',
                      pageBuilder: (_, state) => relayPage(
                        state,
                        AiSourcesPage(
                          product: state.extra is ShowcaseProduct
                              ? state.extra! as ShowcaseProduct
                              : null,
                          products: AppConfig.isLive
                              ? ref.read(productsProvider).items
                              : ShowcaseProduct.available,
                        ),
                      ),
                    ),
                    GoRoute(
                      path: ':productId',
                      pageBuilder: (_, state) {
                        ShowcaseProduct? product;
                        final catalog = AppConfig.isLive
                            ? ref.read(productsProvider).items
                            : ShowcaseProduct.available;
                        for (final item in catalog) {
                          if (item.id == state.pathParameters['productId']) {
                            product = item;
                            break;
                          }
                        }
                        return relayPage(
                          state,
                          product == null
                              ? ShowcasePage(
                                  store: contentStore,
                                  controller: ref.read(productsProvider),
                                )
                              : ProductDetailPage(
                                  product: product,
                                  store: contentStore,
                                ),
                          motion: RelayPageMotion.detail,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/create',
                  builder: (_, state) => CreateHubPage(
                    selectedProduct: state.extra is ShowcaseProduct
                        ? state.extra! as ShowcaseProduct
                        : null,
                  ),
                  routes: [
                    GoRoute(
                      path: 'import-ai',
                      pageBuilder: (_, state) => relayPage(
                        state,
                        AiSourcesPage(
                          product: state.extra is ShowcaseProduct
                              ? state.extra! as ShowcaseProduct
                              : null,
                          products: AppConfig.isLive
                              ? ref.read(productsProvider).items
                              : ShowcaseProduct.available,
                        ),
                      ),
                    ),
                    GoRoute(
                      path: 'ai',
                      pageBuilder: (_, state) {
                        final product = state.extra is ShowcaseProduct
                            ? state.extra! as ShowcaseProduct
                            : AppConfig.isDemo
                            ? ShowcaseProduct.available.first
                            : null;
                        return relayPage(
                          state,
                          product == null
                              ? const CreateHubPage()
                              : AiCreatePage(product: product),
                        );
                      },
                    ),
                    GoRoute(
                      path: 'upload',
                      pageBuilder: (_, state) => relayPage(
                        state,
                        CreatePage(
                          controller: ref.read(createProvider),
                          selectedProduct: state.extra is ShowcaseProduct
                              ? state.extra! as ShowcaseProduct
                              : null,
                        ),
                      ),
                    ),
                    GoRoute(
                      path: 'guided',
                      pageBuilder: (_, state) {
                        final product = state.extra is ShowcaseProduct
                            ? state.extra! as ShowcaseProduct
                            : AppConfig.isDemo
                            ? ShowcaseProduct.available.first
                            : null;
                        return relayPage(
                          state,
                          product == null
                              ? const CreateHubPage()
                              : GuidedFilmPage(product: product),
                        );
                      },
                    ),
                    GoRoute(
                      path: 'batch',
                      pageBuilder: (_, state) => relayPage(
                        state,
                        BatchCreatePage(
                          products: state.extra is List<ShowcaseProduct>
                              ? state.extra! as List<ShowcaseProduct>
                              : const [],
                          store: contentStore,
                        ),
                      ),
                    ),
                    GoRoute(
                      path: 'publish',
                      pageBuilder: (_, state) {
                        final extra = state.extra;
                        if (extra is PublishReviewArgs) {
                          return relayPage(
                            state,
                            PublishReviewPage(
                              product: extra.product,
                              initialCaption: extra.caption,
                              mediaName: extra.mediaName,
                              durationSec: extra.durationSec,
                              sourceLabel: extra.sourceLabel,
                              store: contentStore,
                              remixOfId: extra.remixOfId,
                              remixNote: extra.remixNote,
                            ),
                          );
                        }
                        return relayPage(
                          state,
                          extra is ShowcaseProduct
                              ? PublishReviewPage(
                                  product: extra,
                                  store: contentStore,
                                )
                              : AppConfig.isDemo
                              ? PublishReviewPage(
                                  product: ShowcaseProduct.available.first,
                                  store: contentStore,
                                )
                              : const CreateHubPage(),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/content',
                  builder: (_, _) => ContentLibraryPage(
                    controller: ref.read(homeProvider),
                    store: contentStore,
                  ),
                  routes: [
                    GoRoute(
                      path: ':jobId',
                      pageBuilder: (_, state) {
                        final extra = state.extra;
                        final job = extra is home.PublishJob
                            ? extra
                            : contentStore.byId(
                                state.pathParameters['jobId'] ?? '',
                              );
                        return relayPage(
                          state,
                          job == null && AppConfig.isLive
                              ? ContentDetailLoaderPage(
                                  load: () async {
                                    final jobId =
                                        state.pathParameters['jobId'] ?? '';
                                    return auth.authorized(
                                      (access) => ref
                                          .read(homeProvider)
                                          .api
                                          .get(access, jobId),
                                    );
                                  },
                                  store: contentStore,
                                  onRetryRemote: (jobId) async {
                                    await auth.authorized(
                                      (access) => ref
                                          .read(homeProvider)
                                          .api
                                          .retry(access, jobId),
                                    );
                                    await ref.read(homeProvider).load();
                                  },
                                  onCancelRemote: (jobId) async {
                                    await auth.authorized(
                                      (access) => ref
                                          .read(homeProvider)
                                          .api
                                          .cancel(access, jobId),
                                    );
                                    await ref.read(homeProvider).load();
                                  },
                                  onRescheduleRemote:
                                      (jobId, scheduledAt) async {
                                        await auth.authorized(
                                          (access) => ref
                                              .read(homeProvider)
                                              .api
                                              .reschedule(
                                                access,
                                                jobId,
                                                scheduledAt,
                                              ),
                                        );
                                        await ref.read(homeProvider).load();
                                      },
                                  onRestoreRemote: (jobId) async {
                                    await auth.authorized(
                                      (access) => ref
                                          .read(homeProvider)
                                          .api
                                          .restore(access, jobId),
                                    );
                                    await ref.read(homeProvider).load();
                                  },
                                )
                              : job == null
                              ? ContentLibraryPage(
                                  controller: ref.read(homeProvider),
                                  store: contentStore,
                                )
                              : ContentDetailPage(
                                  job: job,
                                  store: contentStore,
                                  onRetryRemote: AppConfig.isLive
                                      ? (jobId) async {
                                          await auth.authorized(
                                            (access) => ref
                                                .read(homeProvider)
                                                .api
                                                .retry(access, jobId),
                                          );
                                          await ref.read(homeProvider).load();
                                        }
                                      : null,
                                  onCancelRemote: AppConfig.isLive
                                      ? (jobId) async {
                                          await auth.authorized(
                                            (access) => ref
                                                .read(homeProvider)
                                                .api
                                                .cancel(access, jobId),
                                          );
                                          await ref.read(homeProvider).load();
                                        }
                                      : null,
                                  onRescheduleRemote: AppConfig.isLive
                                      ? (jobId, scheduledAt) async {
                                          await auth.authorized(
                                            (access) => ref
                                                .read(homeProvider)
                                                .api
                                                .reschedule(
                                                  access,
                                                  jobId,
                                                  scheduledAt,
                                                ),
                                          );
                                          final home = ref.read(homeProvider);
                                          await home.load();
                                          final data = home.data;
                                          if (data != null) {
                                            contentStore.replaceAll(data.jobs);
                                          }
                                        }
                                      : null,
                                  onRestoreRemote: AppConfig.isLive
                                      ? (jobId) async {
                                          await auth.authorized(
                                            (access) => ref
                                                .read(homeProvider)
                                                .api
                                                .restore(access, jobId),
                                          );
                                          final home = ref.read(homeProvider);
                                          await home.load();
                                          final data = home.data;
                                          if (data != null) {
                                            contentStore.replaceAll(data.jobs);
                                          }
                                        }
                                      : null,
                                ),
                          motion: RelayPageMotion.detail,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (_, _) => ProfilePage(
                    auth: auth,
                    themeMode: themeMode,
                    reducedMotion: reducedMotion,
                    onThemeModeChanged: (value) =>
                        setState(() => themeMode = value),
                    onReducedMotionChanged: (value) =>
                        setState(() => reducedMotion = value),
                  ),
                ),
                GoRoute(
                  path: '/connections',
                  pageBuilder: (_, state) => relayPage(
                    state,
                    ConnectionsPage(controller: ref.read(connectionsProvider)),
                    motion: RelayPageMotion.detail,
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/composer',
          pageBuilder: (context, state) {
            // Composer ต้องรู้ว่าโพสต์คอนเทนต์ไหน ด้วยบัญชีไหน และวิดีโอยาวเท่าไหร่
            // (ความยาวใช้ตรวจกฎ R7 ของ TikTok) จึงรับผ่าน extra แทน query param
            final args = state.extra as ComposerArgs?;
            if (args == null) {
              return relayPage(
                state,
                const _MissingArgs(),
                motion: RelayPageMotion.detail,
              );
            }

            final controller = ComposerController(
              auth: auth,
              api: HttpComposerApi(ref.read(apiClientProvider)),
              contentId: args.contentId,
              connectionId: args.connectionId,
              videoDurationSec: args.videoDurationSec,
              isAigc: args.isAigc,
              idempotencyKey: args.idempotencyKey,
            );
            return relayPage(
              state,
              TikTokComposerPage(
                controller: controller,
                onSubmitted: () async {
                  final home = ref.read(homeProvider);
                  await home.load();
                  final data = home.data;
                  if (data != null) contentStore.replaceAll(data.jobs);
                },
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
    themeMode: themeMode,
    scrollBehavior: const _MobileFirstScrollBehavior(),
    builder: (context, child) =>
        _ResponsiveAppViewport(reducedMotion: reducedMotion, child: child),
    routerConfig: router,
  );
}

class _MobileFirstScrollBehavior extends MaterialScrollBehavior {
  const _MobileFirstScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

/// Keeps the web preview at a real mobile width without browser device
/// emulation. Edge/Chrome device emulation can briefly report a negative
/// visual viewport while dismissing its virtual keyboard, which crashes the
/// Flutter web engine in debug mode. Real phones are left untouched.
class _ResponsiveAppViewport extends StatelessWidget {
  const _ResponsiveAppViewport({
    required this.child,
    required this.reducedMotion,
  });

  final Widget? child;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final content = MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
      child: child ?? const SizedBox.shrink(),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) return content;
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 430,
              height: constraints.maxHeight,
              child: content,
            ),
          ),
        );
      },
    );
  }
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
                    const _SessionOpening(),
                  ] else ...[
                    RelayStatePanel(
                      kind: RelayStateKind.offline,
                      title: 'ยังเปิดบัญชีไม่ได้',
                      message:
                          auth.error ?? 'กรุณาตรวจสอบการเชื่อมต่อแล้วลองใหม่',
                      actionLabel: 'ลองเปิดบัญชีอีกครั้ง',
                      onAction: auth.busy ? null : auth.restore,
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

class _SessionOpening extends StatelessWidget {
  const _SessionOpening();

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: context.motion(RelayMotion.journey),
    curve: RelayMotion.enter,
    builder: (context, progress, _) => Column(
      children: [
        Transform.scale(
          scale: .9 + progress * .1,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: context.t.primary.withValues(alpha: .12),
              shape: BoxShape.circle,
              border: Border.all(color: context.t.primary),
              boxShadow: [
                BoxShadow(
                  color: context.t.primary.withValues(alpha: .16 * progress),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(
              Icons.sync_lock_rounded,
              color: context.t.primary,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        const Text(
          'กำลังเปิดพื้นที่ทำงานของคุณ',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: context.t.primary.withValues(alpha: .1),
            ),
          ),
        ),
      ],
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
