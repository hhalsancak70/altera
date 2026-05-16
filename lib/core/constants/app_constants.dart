// ALTERA uygulama sabitleri - magic number kullanımını önler
/// Tüm uygulama genelinde kullanılan sabit değerler.
/// Magic number yerine bu sınıftaki sabitler kullanılmalıdır.
class AppConstants {
  AppConstants._();

  // --- GEMİNİ API ---

  /// Gemini API için maksimum token sayısı - maliyet kontrolü
  static const int kGeminiMaxTokens = 1024;

  /// Gemini API çağrıları arası bekleme süresi (ms)
  /// Free tier: 15 istek/dakika → en az 4s arayla gönderim gerekli
  static const int kAnalysisDelayMs = 4500;

  /// Hata durumunda maksimum yeniden deneme sayısı
  static const int kGeminiMaxRetries = 3;

  /// Rate limit hatasında varsayılan bekleme (ms) — API retry-after parse edilemezse
  static const int kRateLimitDelayMs = 15000;

  /// Bir ajan döngüsünde maksimum analiz edilecek işlem sayısı
  static const int kMaxTransactionsPerCycle = 20;

  // --- BÜTÇE ---

  /// Bütçe uyarısı için eşik yüzdesi (%80)
  static const double kBudgetWarningThreshold = 0.80;

  /// Bütçe aşım eşiği (%100)
  static const double kBudgetDangerThreshold = 1.0;

  // --- AJAN ---

  /// Ajan döngüsü kontrol aralığı (saniye) - otomatik mod
  static const int kAgentCycleIntervalSeconds = 30;

  /// Ajan log maksimum kayıt sayısı - eski kayıtlar otomatik silinir
  static const int kMaxAgentLogEntries = 500;

  /// Ajan döngüsü tamamlandıktan sonra idle'a dönme gecikmesi (ms)
  static const int kAgentCompletedDelayMs = 3000;

  // --- VERİTABANI ---

  /// SQLite veritabanı dosya adı
  static const String kDatabaseName = 'altera.db';

  /// SQLite şema versiyonu - monthly_archives tablosu v2'de eklendi
  static const int kDatabaseVersion = 2;

  // --- YATIRIM ---

  /// Yatırım önerisi için minimum tasarruf miktarı (TL)
  static const double kMinInvestmentAmount = 500.0;

  /// Ay sonu yatırım kontrolü için gün eşiği (ayın kaçından itibaren?)
  static const int kMonthEndDayThreshold = 28;

  // --- UI ---

  /// Son işlemler listesi - dashboard'da gösterilecek maksimum adet
  static const int kRecentTransactionsCount = 5;

  /// Log listesi - varsayılan yükleme limiti
  static const int kDefaultLogLimit = 100;

  /// Banka mock servisi simülasyon gecikmesi (ms) - gerçekçi API hissi
  static const int kBankMockDelayMs = 500;

  /// Simüle transfer başarı oranı (0.0 - 1.0)
  static const double kTransferSuccessRate = 0.95;

  // --- HIVE ANAHTARLARI ---

  /// Hive'da kullanıcı profili anahtarı
  static const String kHiveKeyUserProfile = 'user_profile';

  /// Hive'da son ajan çalışma zamanı anahtarı
  static const String kHiveKeyLastAgentRun = 'last_agent_run';

  /// Hive'da otomatik ajan modu anahtarı
  static const String kHiveKeyAutoAgentEnabled = 'auto_agent_enabled';

  /// Hive'da tema modu anahtarı
  static const String kHiveKeyThemeMode = 'theme_mode';

  /// Hive'da dil anahtarı
  static const String kHiveKeyLocale = 'locale';

  // --- FLUTTER SECURE STORAGE ANAHTARLARI ---

  /// Güvenli depolamada Gemini API key anahtarı
  static const String kSecureKeyGeminiApiKey = 'gemini_api_key';

  // --- ANİMASYON SÜRELERİ ---

  /// Standart UI geçiş animasyonu süresi (ms)
  static const int kAnimationDurationMs = 300;

  /// Ajan nabız animasyonu süresi (ms)
  static const int kPulseAnimationDurationMs = 1500;
}
