// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'ALTERA';

  @override
  String get dashboard => 'Panel';

  @override
  String get transactions => 'İşlemler';

  @override
  String get budget => 'Bütçe';

  @override
  String get investments => 'Yatırım';

  @override
  String get agentLog => 'Ajan Log';

  @override
  String get settings => 'Ayarlar';

  @override
  String get agentReady => 'ALTERA Ajan Hazır';

  @override
  String get agentCollecting => 'Veri Toplanıyor...';

  @override
  String get agentAnalyzing => 'Gemini Analiz Ediyor...';

  @override
  String get agentActing => 'Aksiyonlar Alınıyor...';

  @override
  String get agentCompleted => 'Döngü Tamamlandı ✓';

  @override
  String get agentError => 'Hata Oluştu';

  @override
  String agentAnalyzedCount(int count) {
    return '$count işlem analiz edildi';
  }

  @override
  String agentCollectedCount(int count) {
    return '$count yeni işlem eklendi';
  }

  @override
  String get budgetSafe => 'Güvende';

  @override
  String get budgetWarning => 'Uyarı';

  @override
  String get budgetDanger => 'Aşıldı';

  @override
  String budgetOverspent(String amount) {
    return '$amount TL aşım';
  }

  @override
  String get categoryMarket => 'Market';

  @override
  String get categoryRestaurant => 'Restoran';

  @override
  String get categoryTransport => 'Ulaşım';

  @override
  String get categoryBill => 'Fatura';

  @override
  String get categoryClothing => 'Giyim';

  @override
  String get categoryEntertainment => 'Eğlence';

  @override
  String get categoryHealth => 'Sağlık';

  @override
  String get categoryEducation => 'Eğitim';

  @override
  String get categoryInvestment => 'Yatırım';

  @override
  String get categoryIncome => 'Gelir';

  @override
  String get categoryOther => 'Diğer';

  @override
  String get transactionTypeNeed => 'İhtiyaç';

  @override
  String get transactionTypeWant => 'İstek';

  @override
  String get transactionTypeIncome => 'Gelir';

  @override
  String get riskConservative => 'Muhafazakâr';

  @override
  String get riskBalanced => 'Dengeli';

  @override
  String get riskAggressive => 'Agresif';

  @override
  String get monthlySummary => 'Aylık Özet';

  @override
  String get totalIncome => 'Gelir';

  @override
  String get totalExpense => 'Gider';

  @override
  String get totalSavings => 'Tasarruf';

  @override
  String get noTransactions =>
      'Henüz işlem yok.\nAjan döngüsünü başlatarak işlemleri yükle.';

  @override
  String get noBudgets => 'Henüz bütçe tanımlanmadı.';

  @override
  String get noLogs => 'Henüz log kaydı yok.';

  @override
  String get startAgentCycle => 'Ajan Döngüsü';

  @override
  String get agentRunning => 'Çalışıyor...';

  @override
  String notificationBudgetWarningTitle(String category, String percent) {
    return '⚠️ $category Bütçesi %$percent Doldu';
  }

  @override
  String notificationBudgetDangerTitle(String category) {
    return '🚨 $category Bütçesi Aşıldı!';
  }

  @override
  String get notificationInvestmentTitle => '✅ Yatırım Tamamlandı';

  @override
  String notificationInvestmentBody(String amount, String fund) {
    return '$amount TL $fund fonuna aktarıldı.';
  }

  @override
  String get apiKeyLabel => 'Gemini API Key';

  @override
  String get apiKeyHint => 'AIzaSy...';

  @override
  String get apiKeySaved => 'API Key kaydedildi';

  @override
  String get apiKeyInfo => 'API key cihazında şifreli olarak saklanır.';

  @override
  String get resetAllData => 'Tüm Verileri Sıfırla';

  @override
  String get resetConfirm =>
      'İşlemler, bütçeler ve ajan logları silinecek. Bu işlem geri alınamaz.';

  @override
  String get resetSuccess => 'Tüm veriler sıfırlandı';

  @override
  String get agentFlowTitle => 'Ajan Akışı';

  @override
  String get agentFlowIdle => 'Bekleme';

  @override
  String get agentFlowCollect => 'Veri';

  @override
  String get agentFlowAnalyze => 'Gemini';

  @override
  String get agentFlowAct => 'Aksiyon';

  @override
  String get geminiReason => '✨ Gemini Gerekçesi';

  @override
  String get analysisWaiting => '⏳ Analiz Bekliyor';

  @override
  String get transferConfirm => 'Onayla';

  @override
  String get transferCancel => 'İptal';

  @override
  String transferSuccess(String amount, String fund) {
    return '₺$amount $fund fonuna aktarıldı';
  }

  @override
  String get investmentReady => 'Yatırıma Hazır!';

  @override
  String get thisMonthSavings => 'Bu Ay Tasarruf';

  @override
  String get historicalTransfers => 'Geçmiş Transferler';

  @override
  String get onboardingTitle => 'ALTERA\'ya\nHoşgeldin!';

  @override
  String get onboardingSubtitle =>
      'Gemini 2.0 Flash destekli 3 otonom ajan seni finansal hedeflerine ulaştıracak.';

  @override
  String get onboardingNext => 'Devam';

  @override
  String get onboardingBack => 'Geri';

  @override
  String get onboardingStart => 'Başla!';

  @override
  String get aboutApp => 'ALTERA v1.0.0';

  @override
  String get aboutAI => 'Gemini 2.0 Flash';

  @override
  String get aboutEvent => 'BTK Hackathon 2026';
}
