// Yerel bildirim yöneticisi - internet gerektirmez
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/transaction.dart';

/// Yerel bildirim yöneticisi.
/// flutter_local_notifications kullanır - internet gerektirmez.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelBudget = 'budget_alerts';
  static const _channelAgent = 'agent_actions';
  static const _channelInvestment = 'investment';

  // Sabit bildirim ID aralıkları (çakışmadan kaçınmak için bloklar)
  static const _idBudgetWarning = 1000;
  static const _idBudgetDanger = 1001;
  static const _idInvestment = 2000;
  static const _idAgentSummary = 3000;
  static const _idMonthlySummary = 4000;
  // Portfolio uyarıları: 5000–5999 (sembol hash'inden türetilir)
  static const _idPortfolioBase = 5000;

  /// Uygulamanın başında bir kez çağrılır
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
    );

    await instance._plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await instance._createChannels();
  }

  /// Android 13+ (API 33+) için bildirim izni ister.
  /// İzin yoksa sessizce devam eder — uygulama crash etmez.
  static Future<void> requestPermissionIfNeeded() async {
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('[NotificationService] İzin isteği başarısız: $e');
    }
  }

  Future<void> _createChannels() async {
    const budgetChannel = AndroidNotificationChannel(
      _channelBudget,
      'Bütçe Uyarıları',
      description: 'Bütçe aşım ve uyarı bildirimleri',
      importance: Importance.high,
    );
    const agentChannel = AndroidNotificationChannel(
      _channelAgent,
      'Ajan Aksiyonları',
      description: 'ALTERA ajan aktivite bildirimleri',
      importance: Importance.defaultImportance,
    );
    const investmentChannel = AndroidNotificationChannel(
      _channelInvestment,
      'Yatırım Önerileri',
      description: 'Otomatik yatırım bildirimleri',
      importance: Importance.defaultImportance,
    );

    final androidPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlugin?.createNotificationChannel(budgetChannel);
    await androidPlugin?.createNotificationChannel(agentChannel);
    await androidPlugin?.createNotificationChannel(investmentChannel);
  }

  Future<void> _show(
    int id,
    String title,
    String body,
    NotificationDetails details,
  ) async {
    try {
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('[NotificationService] Bildirim gönderilemedi: $e');
    }
  }

  Future<void> showBudgetWarning({
    required TransactionCategory category,
    required double usagePercentage,
    required String suggestion,
  }) async {
    final percent = (usagePercentage * 100).toStringAsFixed(0);
    await _show(
      _idBudgetWarning,
      '⚠️ ${category.displayNameTr} Bütçesi %$percent Doldu',
      suggestion,
      _buildDetails(
        channelId: _channelBudget,
        channelName: 'Bütçe Uyarıları',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }

  Future<void> showBudgetDanger({
    required TransactionCategory category,
    required double overspentAmount,
  }) async {
    await _show(
      _idBudgetDanger,
      '🚨 ${category.displayNameTr} Bütçesi Aşıldı!',
      '${overspentAmount.toStringAsFixed(0)} TL fazla harcandı.',
      _buildDetails(
        channelId: _channelBudget,
        channelName: 'Bütçe Uyarıları',
        importance: Importance.max,
        priority: Priority.max,
      ),
    );
  }

  Future<void> showInvestmentCompleted({
    required String fundName,
    required double amount,
  }) async {
    await _show(
      _idInvestment,
      '✅ Yatırım Tamamlandı',
      '${amount.toStringAsFixed(0)} TL $fundName fonuna aktarıldı.',
      _buildDetails(
        channelId: _channelInvestment,
        channelName: 'Yatırım Önerileri',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
  }

  /// Portföyde önemli fiyat hareketi olduğunda bildirim gönderir.
  /// Her sembol için benzersiz ID üretilir (çakışma yok).
  Future<void> showPortfolioAlert({
    required String assetName,
    required String assetSymbol,
    required double changePct,
    required double deltaAmountTl,
  }) async {
    // Sembol hash'inden [0, 999] aralığında deterministic ID
    final notifId = _idPortfolioBase + (assetSymbol.hashCode.abs() % 1000);
    final isUp = changePct >= 0;
    final sign = isUp ? '+' : '';
    final arrow = isUp ? '▲' : '▼';

    await _show(
      notifId,
      '$arrow $assetName Önemli Hareket',
      '$sign${changePct.toStringAsFixed(2)}% ($sign${deltaAmountTl.toStringAsFixed(0)} TL) bugün',
      _buildDetails(
        channelId: _channelInvestment,
        channelName: 'Yatırım Önerileri',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }

  Future<void> showAgentCycleSummary({
    required int analyzedCount,
    required int actionsCount,
  }) async {
    await _show(
      _idAgentSummary,
      '🤖 ALTERA Ajan Döngüsü Tamamlandı',
      '$analyzedCount işlem analiz edildi, $actionsCount aksiyon alındı.',
      _buildDetails(
        channelId: _channelAgent,
        channelName: 'Ajan Aksiyonları',
        importance: Importance.low,
        priority: Priority.low,
      ),
    );
  }

  Future<void> showMonthlySummary({
    required DateTime month,
    required double totalSavings,
    String? topCategory,
  }) async {
    const monthNames = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    final monthName = monthNames[month.month];
    final savingsText =
        totalSavings >= 0
            ? '${totalSavings.toStringAsFixed(0)} TL tasarruf ettin!'
            : '${totalSavings.abs().toStringAsFixed(0)} TL açık verdin.';
    final body =
        topCategory != null ? '$savingsText En çok: $topCategory' : savingsText;

    await _show(
      _idMonthlySummary,
      '$monthName ayı arşivlendi',
      body,
      _buildDetails(
        channelId: _channelAgent,
        channelName: 'Ajan Aksiyonları',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
  }

  NotificationDetails _buildDetails({
    required String channelId,
    required String channelName,
    required Importance importance,
    required Priority priority,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: importance,
        priority: priority,
        styleInformation: const DefaultStyleInformation(true, true),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
      ),
    );
  }
}
