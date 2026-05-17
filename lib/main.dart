// ALTERA - Gemini 2.0 Flash tabanlı kişisel finans yönetim uygulaması
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/database/hive_boxes.dart';
import 'core/providers.dart';
import 'core/services/notification_service.dart';
import 'features/archive/archive_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/import/import_screen.dart';
import 'features/transactions/transactions_screen.dart';
import 'features/budget/budget_screen.dart';
import 'features/investments/investments_screen.dart';
import 'features/agent_log/agent_log_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/ai_chat/ai_chat_screen.dart';
import 'core/utils/app_snackbar.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/altera_bottom_nav.dart';

/// Uygulama giriş noktası.
/// Başlatma sırası:
/// 1. Flutter binding + global hata yakalayıcılar
/// 2. Hive başlat (kullanıcı profili, ayarlar)
/// 3. Bildirim servisi başlat
/// 4. Riverpod container oluştur
/// 5. MaterialApp çalıştır
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter framework hatalarını yakala — uygulamanın çökmesini önle
  FlutterError.onError = (details) {
    if (kDebugMode) FlutterError.presentError(details);
  };

  // Dart async hatalarını yakala (FlutterError yakalamadıkları)
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) debugPrint('Unhandled error: $error\n$stack');
    return true; // Hata işlendi, uygulama çökmüyor
  };

  // Dikey yönlendirmeyi tercih et
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Hive zorunlu — UI'ın kullandığı kutular bunu bekler
  await initHive();

  runApp(
    const ProviderScope(
      child: AlteraApp(),
    ),
  );

  // Bildirim servisi ilk frame'i bloklamasın — arka planda init
  // Hata olursa yutuluyor, uygulama yine de çalışır
  Future.microtask(() async {
    try {
      await NotificationService.initialize();
    } catch (e) {
      if (kDebugMode) debugPrint('Notification init hatası (kritik değil): $e');
    }
  });
}

/// GoRouter yapılandırması
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    // Ana scaffold - BottomNav ile
    ShellRoute(
      builder: (context, state, child) {
        return MainScaffold(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/transactions',
          builder: (context, state) => const TransactionsScreen(),
        ),
        GoRoute(
          path: '/budget',
          builder: (context, state) => const BudgetScreen(),
        ),
        GoRoute(
          path: '/investments',
          builder: (context, state) => const InvestmentsScreen(),
        ),
        GoRoute(
          path: '/agent-log',
          builder: (context, state) => const AgentLogScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/import',
      builder: (context, state) => const ImportScreen(),
    ),
    GoRoute(
      path: '/archive',
      builder: (context, state) => const ArchiveScreen(),
    ),
    GoRoute(
      path: '/ai-chat',
      builder: (context, state) => const AiChatScreen(),
    ),
  ],
);

/// Kök uygulama widget'ı
class AlteraApp extends StatelessWidget {
  const AlteraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'ALTERA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark, // Dark mode varsayılan
      routerConfig: _router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('tr', 'TR'),
    );
  }
}

/// BottomNav ile sarılmış ana scaffold.
/// İlk açılışta aylık döngü kontrolü yapar.
class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  @override
  void initState() {
    super.initState();
    // Aylık döngü kontrolü — gerekiyorsa arşivler
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkCycle());
  }

  Future<void> _checkCycle() async {
    try {
      await ref.read(cycleServiceProvider).checkAndRunIfNeeded();
    } catch (_) {
      // Döngü hatası kritik değil — uygulamayı durdurma
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: const AlteraBottomNav(),
    );
  }
}
