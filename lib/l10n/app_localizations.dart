import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// Uygulama adı
  ///
  /// In tr, this message translates to:
  /// **'ALTERA'**
  String get appTitle;

  /// Dashboard sekme adı
  ///
  /// In tr, this message translates to:
  /// **'Panel'**
  String get dashboard;

  /// İşlemler sekme adı
  ///
  /// In tr, this message translates to:
  /// **'İşlemler'**
  String get transactions;

  /// Bütçe sekme adı
  ///
  /// In tr, this message translates to:
  /// **'Bütçe'**
  String get budget;

  /// Yatırım sekme adı
  ///
  /// In tr, this message translates to:
  /// **'Yatırım'**
  String get investments;

  /// Ajan Log sekme adı
  ///
  /// In tr, this message translates to:
  /// **'Ajan Log'**
  String get agentLog;

  /// Ayarlar
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get settings;

  /// Ajan bekleme durumu mesajı
  ///
  /// In tr, this message translates to:
  /// **'ALTERA Ajan Hazır'**
  String get agentReady;

  /// Veri toplama ajanı aktif
  ///
  /// In tr, this message translates to:
  /// **'Veri Toplanıyor...'**
  String get agentCollecting;

  /// Analiz ajanı aktif
  ///
  /// In tr, this message translates to:
  /// **'Gemini Analiz Ediyor...'**
  String get agentAnalyzing;

  /// Aksiyon ajanı aktif
  ///
  /// In tr, this message translates to:
  /// **'Aksiyonlar Alınıyor...'**
  String get agentActing;

  /// Döngü tamamlandı
  ///
  /// In tr, this message translates to:
  /// **'Döngü Tamamlandı ✓'**
  String get agentCompleted;

  /// Ajan hata durumu
  ///
  /// In tr, this message translates to:
  /// **'Hata Oluştu'**
  String get agentError;

  /// Analiz tamamlanan işlem sayısı
  ///
  /// In tr, this message translates to:
  /// **'{count} işlem analiz edildi'**
  String agentAnalyzedCount(int count);

  /// Toplanan yeni işlem sayısı
  ///
  /// In tr, this message translates to:
  /// **'{count} yeni işlem eklendi'**
  String agentCollectedCount(int count);

  /// Bütçe güvende durumu
  ///
  /// In tr, this message translates to:
  /// **'Güvende'**
  String get budgetSafe;

  /// Bütçe uyarı durumu
  ///
  /// In tr, this message translates to:
  /// **'Uyarı'**
  String get budgetWarning;

  /// Bütçe aşım durumu
  ///
  /// In tr, this message translates to:
  /// **'Aşıldı'**
  String get budgetDanger;

  /// Bütçe aşım miktarı
  ///
  /// In tr, this message translates to:
  /// **'{amount} TL aşım'**
  String budgetOverspent(String amount);

  /// No description provided for @categoryMarket.
  ///
  /// In tr, this message translates to:
  /// **'Market'**
  String get categoryMarket;

  /// No description provided for @categoryRestaurant.
  ///
  /// In tr, this message translates to:
  /// **'Restoran'**
  String get categoryRestaurant;

  /// No description provided for @categoryTransport.
  ///
  /// In tr, this message translates to:
  /// **'Ulaşım'**
  String get categoryTransport;

  /// No description provided for @categoryBill.
  ///
  /// In tr, this message translates to:
  /// **'Fatura'**
  String get categoryBill;

  /// No description provided for @categoryClothing.
  ///
  /// In tr, this message translates to:
  /// **'Giyim'**
  String get categoryClothing;

  /// No description provided for @categoryEntertainment.
  ///
  /// In tr, this message translates to:
  /// **'Eğlence'**
  String get categoryEntertainment;

  /// No description provided for @categoryHealth.
  ///
  /// In tr, this message translates to:
  /// **'Sağlık'**
  String get categoryHealth;

  /// No description provided for @categoryEducation.
  ///
  /// In tr, this message translates to:
  /// **'Eğitim'**
  String get categoryEducation;

  /// No description provided for @categoryInvestment.
  ///
  /// In tr, this message translates to:
  /// **'Yatırım'**
  String get categoryInvestment;

  /// No description provided for @categoryIncome.
  ///
  /// In tr, this message translates to:
  /// **'Gelir'**
  String get categoryIncome;

  /// No description provided for @categoryOther.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get categoryOther;

  /// No description provided for @transactionTypeNeed.
  ///
  /// In tr, this message translates to:
  /// **'İhtiyaç'**
  String get transactionTypeNeed;

  /// No description provided for @transactionTypeWant.
  ///
  /// In tr, this message translates to:
  /// **'İstek'**
  String get transactionTypeWant;

  /// No description provided for @transactionTypeIncome.
  ///
  /// In tr, this message translates to:
  /// **'Gelir'**
  String get transactionTypeIncome;

  /// No description provided for @riskConservative.
  ///
  /// In tr, this message translates to:
  /// **'Muhafazakâr'**
  String get riskConservative;

  /// No description provided for @riskBalanced.
  ///
  /// In tr, this message translates to:
  /// **'Dengeli'**
  String get riskBalanced;

  /// No description provided for @riskAggressive.
  ///
  /// In tr, this message translates to:
  /// **'Agresif'**
  String get riskAggressive;

  /// No description provided for @monthlySummary.
  ///
  /// In tr, this message translates to:
  /// **'Aylık Özet'**
  String get monthlySummary;

  /// No description provided for @totalIncome.
  ///
  /// In tr, this message translates to:
  /// **'Gelir'**
  String get totalIncome;

  /// No description provided for @totalExpense.
  ///
  /// In tr, this message translates to:
  /// **'Gider'**
  String get totalExpense;

  /// No description provided for @totalSavings.
  ///
  /// In tr, this message translates to:
  /// **'Tasarruf'**
  String get totalSavings;

  /// No description provided for @noTransactions.
  ///
  /// In tr, this message translates to:
  /// **'Henüz işlem yok.\nAjan döngüsünü başlatarak işlemleri yükle.'**
  String get noTransactions;

  /// No description provided for @noBudgets.
  ///
  /// In tr, this message translates to:
  /// **'Henüz bütçe tanımlanmadı.'**
  String get noBudgets;

  /// No description provided for @noLogs.
  ///
  /// In tr, this message translates to:
  /// **'Henüz log kaydı yok.'**
  String get noLogs;

  /// No description provided for @startAgentCycle.
  ///
  /// In tr, this message translates to:
  /// **'Ajan Döngüsü'**
  String get startAgentCycle;

  /// No description provided for @agentRunning.
  ///
  /// In tr, this message translates to:
  /// **'Çalışıyor...'**
  String get agentRunning;

  /// No description provided for @notificationBudgetWarningTitle.
  ///
  /// In tr, this message translates to:
  /// **'⚠️ {category} Bütçesi %{percent} Doldu'**
  String notificationBudgetWarningTitle(String category, String percent);

  /// No description provided for @notificationBudgetDangerTitle.
  ///
  /// In tr, this message translates to:
  /// **'🚨 {category} Bütçesi Aşıldı!'**
  String notificationBudgetDangerTitle(String category);

  /// No description provided for @notificationInvestmentTitle.
  ///
  /// In tr, this message translates to:
  /// **'✅ Yatırım Tamamlandı'**
  String get notificationInvestmentTitle;

  /// No description provided for @notificationInvestmentBody.
  ///
  /// In tr, this message translates to:
  /// **'{amount} TL {fund} fonuna aktarıldı.'**
  String notificationInvestmentBody(String amount, String fund);

  /// No description provided for @apiKeyLabel.
  ///
  /// In tr, this message translates to:
  /// **'Gemini API Key'**
  String get apiKeyLabel;

  /// No description provided for @apiKeyHint.
  ///
  /// In tr, this message translates to:
  /// **'AIzaSy...'**
  String get apiKeyHint;

  /// No description provided for @apiKeySaved.
  ///
  /// In tr, this message translates to:
  /// **'API Key kaydedildi'**
  String get apiKeySaved;

  /// No description provided for @apiKeyInfo.
  ///
  /// In tr, this message translates to:
  /// **'API key cihazında şifreli olarak saklanır.'**
  String get apiKeyInfo;

  /// No description provided for @resetAllData.
  ///
  /// In tr, this message translates to:
  /// **'Tüm Verileri Sıfırla'**
  String get resetAllData;

  /// No description provided for @resetConfirm.
  ///
  /// In tr, this message translates to:
  /// **'İşlemler, bütçeler ve ajan logları silinecek. Bu işlem geri alınamaz.'**
  String get resetConfirm;

  /// No description provided for @resetSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Tüm veriler sıfırlandı'**
  String get resetSuccess;

  /// No description provided for @agentFlowTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ajan Akışı'**
  String get agentFlowTitle;

  /// No description provided for @agentFlowIdle.
  ///
  /// In tr, this message translates to:
  /// **'Bekleme'**
  String get agentFlowIdle;

  /// No description provided for @agentFlowCollect.
  ///
  /// In tr, this message translates to:
  /// **'Veri'**
  String get agentFlowCollect;

  /// No description provided for @agentFlowAnalyze.
  ///
  /// In tr, this message translates to:
  /// **'Gemini'**
  String get agentFlowAnalyze;

  /// No description provided for @agentFlowAct.
  ///
  /// In tr, this message translates to:
  /// **'Aksiyon'**
  String get agentFlowAct;

  /// No description provided for @geminiReason.
  ///
  /// In tr, this message translates to:
  /// **'✨ Gemini Gerekçesi'**
  String get geminiReason;

  /// No description provided for @analysisWaiting.
  ///
  /// In tr, this message translates to:
  /// **'⏳ Analiz Bekliyor'**
  String get analysisWaiting;

  /// No description provided for @transferConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Onayla'**
  String get transferConfirm;

  /// No description provided for @transferCancel.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get transferCancel;

  /// No description provided for @transferSuccess.
  ///
  /// In tr, this message translates to:
  /// **'₺{amount} {fund} fonuna aktarıldı'**
  String transferSuccess(String amount, String fund);

  /// No description provided for @investmentReady.
  ///
  /// In tr, this message translates to:
  /// **'Yatırıma Hazır!'**
  String get investmentReady;

  /// No description provided for @thisMonthSavings.
  ///
  /// In tr, this message translates to:
  /// **'Bu Ay Tasarruf'**
  String get thisMonthSavings;

  /// No description provided for @historicalTransfers.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş Transferler'**
  String get historicalTransfers;

  /// No description provided for @onboardingTitle.
  ///
  /// In tr, this message translates to:
  /// **'ALTERA\'ya\nHoşgeldin!'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Gemini 2.0 Flash destekli 3 otonom ajan seni finansal hedeflerine ulaştıracak.'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingNext.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get onboardingNext;

  /// No description provided for @onboardingBack.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get onboardingBack;

  /// No description provided for @onboardingStart.
  ///
  /// In tr, this message translates to:
  /// **'Başla!'**
  String get onboardingStart;

  /// No description provided for @aboutApp.
  ///
  /// In tr, this message translates to:
  /// **'ALTERA v1.0.0'**
  String get aboutApp;

  /// No description provided for @aboutAI.
  ///
  /// In tr, this message translates to:
  /// **'Gemini 2.0 Flash'**
  String get aboutAI;

  /// No description provided for @aboutEvent.
  ///
  /// In tr, this message translates to:
  /// **'BTK Hackathon 2026'**
  String get aboutEvent;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
