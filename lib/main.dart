// ALTERA - Gemini 2.0 Flash tabanlı kişisel finans yönetim uygulaması
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/database/hive_boxes.dart';
import 'core/services/notification_service.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/transactions/transactions_screen.dart';
import 'features/budget/budget_screen.dart';
import 'features/investments/investments_screen.dart';
import 'features/agent_log/agent_log_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/altera_bottom_nav.dart';

/// Uygulama giriş noktası.
/// Başlatma sırası:
/// 1. Flutter binding başlat
/// 2. Hive başlat (kullanıcı profili, ayarlar)
/// 3. Bildirim servisi başlat
/// 4. Riverpod container oluştur
/// 5. MaterialApp çalıştır
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dikey yönlendirmeyi tercih et - finans uygulaması için daha iyi
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await initHive();
  await NotificationService.initialize();

  runApp(
    const ProviderScope(
      child: AlteraApp(),
    ),
  );
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
  ],
);

/// Kök uygulama widget'ı
class AlteraApp extends StatelessWidget {
  const AlteraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
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

/// BottomNav ile sarılmış ana scaffold
class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const AlteraBottomNav(),
    );
  }
}
