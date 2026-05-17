// ALTERA Gemini 2.0 Flash servis katmanı - tüm AI çağrıları burada
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../constants/app_constants.dart';
import '../utils/api_key_storage.dart';
import '../models/transaction.dart';
import '../models/investment_fund.dart';
import '../models/user_profile.dart';
import 'api_quota_tracker.dart';

/// Gemini API yanıt parse hatası
class GeminiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isQuotaExceeded;
  final int? retryAfterSeconds;

  const GeminiException(
    this.message, {
    this.statusCode,
    this.isQuotaExceeded = false,
    this.retryAfterSeconds,
  });

  @override
  String toString() => 'GeminiException: $message';
}

/// analyzeTransaction dönüş tipi
class TransactionAnalysis {
  final TransactionCategory category;
  final TransactionType type;
  final String reason;
  final int durationMs;

  const TransactionAnalysis({
    required this.category,
    required this.type,
    required this.reason,
    required this.durationMs,
  });
}

/// Tek bir kategori için detaylı analiz
class CategoryAnalysis {
  final TransactionCategory category;
  final String verdict; // "İyi" | "Dikkat" | "Kritik"
  final String comment;

  const CategoryAnalysis({
    required this.category,
    required this.verdict,
    required this.comment,
  });
}

/// Detaylı finansal rapor — Gemini İçgörü kartında tablolu görünür
class DetailedFinancialReport {
  final String summary;
  final List<CategoryAnalysis> categoryAnalyses;
  final List<String> savingsBlockers;
  final List<String> actions;
  final int overallScore; // 0-100 finansal sağlık puanı

  const DetailedFinancialReport({
    required this.summary,
    required this.categoryAnalyses,
    required this.savingsBlockers,
    required this.actions,
    required this.overallScore,
  });

  bool get isEmpty => categoryAnalyses.isEmpty && actions.isEmpty;
}

/// Yatırım önerisi dönüş tipi
class InvestmentRecommendation {
  final String fundId;
  final String fundName;
  final String reasoning;
  final double suggestedAmount;

  const InvestmentRecommendation({
    required this.fundId,
    required this.fundName,
    required this.reasoning,
    required this.suggestedAmount,
  });
}

/// ALTERA Gemini 2.0 Flash servis katmanı.
/// Tüm AI çağrıları buradan geçer - ajanlar bu sınıfı kullanır.
class GeminiService {
  final String _apiKey;
  int _activeModelIndex = 0;

  static final _categoryNames =
      TransactionCategory.values.map((c) => c.name).toList();

  static final _transactionSchema = Schema.object(
    properties: {
      'category': Schema.enumString(
        enumValues: _categoryNames,
        description: 'İşlem kategorisi',
      ),
      'type': Schema.enumString(
        enumValues: ['need', 'want', 'income'],
        description: 'need=ihtiyaç, want=istek, income=gelir',
      ),
      'reason': Schema.string(description: 'Kısa Türkçe gerekçe'),
    },
    requiredProperties: ['category', 'type', 'reason'],
  );

  GeminiService._(this._apiKey, this._activeModelIndex);

  /// Şu an kullanılan Gemini modelinin adı (log için)
  String get activeModel => _modelIdAt(_activeModelIndex);

  static String _modelIdAt(int index) {
    if (index == 0) return AppConstants.kGeminiModelPrimary;
    return AppConstants.kGeminiModelFallbacks[index - 1];
  }

  static int get _modelCount =>
      1 + AppConstants.kGeminiModelFallbacks.length;

  /// flutter_secure_storage'dan API key okuyarak modeli başlatır
  static Future<GeminiService> initialize() async {
    final apiKey = await readGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const GeminiException(
        'Gemini API key bulunamadı. Lütfen ayarlardan API key girin.',
      );
    }
    return GeminiService._(apiKey, 0);
  }

  /// Test amaçlı doğrudan API key ile oluşturur
  factory GeminiService.withKey(String apiKey) =>
      GeminiService._(apiKey.trim(), 0);

  /// API key mevcut mu (boşluklar hariç)
  static Future<bool> hasApiKey() => hasGeminiApiKey();

  /// Tek bir işlemi analiz eder - kategori, tür ve gerekçe döndürür.
  Future<TransactionAnalysis> analyzeTransaction(Transaction tx) async {
    final stopwatch = Stopwatch()..start();
    final isIncome = tx.amount > 0;

    final prompt = '''
Sen ALTERA kişisel finans asistanısın. Aşağıdaki banka işlemini analiz et.

İşlem: ${tx.description}
Tutar: ${tx.amount.abs().toStringAsFixed(2)} TL
Tarih: ${tx.date.day}.${tx.date.month}.${tx.date.year}
${isIncome ? 'Bu bir GELİR işlemidir — type alanı mutlaka "income" olmalı.' : 'Bu bir GİDER işlemidir — type "need" veya "want" olmalı.'}

Kategori seçenekleri: ${_categoryNames.join(', ')}

Kısa Türkçe gerekçe yaz (en fazla 10 kelime).
''';

    final responseText = await _generateWithRetry(prompt, schema: _transactionSchema);
    stopwatch.stop();

    try {
      final data = jsonDecode(_extractJson(responseText)) as Map<String, dynamic>;

      final category = _parseCategory(data['category']);
      final type = isIncome
          ? TransactionType.income
          : _parseType(data['type'], isIncome: false);

      return TransactionAnalysis(
        category: category,
        type: type,
        reason: (data['reason'] as String?)?.trim() ?? '',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      throw GeminiException('Yanıt parse hatası: $responseText');
    }
  }

  /// Kullanıcının aylık harcamalarını analiz eder ve yatırım önerisi üretir.
  Future<InvestmentRecommendation> analyzeAndRecommendInvestment({
    required Map<TransactionCategory, double> spending,
    required RiskProfile riskProfile,
    required double savingsAmount,
    required List<InvestmentFund> funds,
  }) async {
    if (funds.isEmpty) {
      throw const GeminiException('Yatırım fonu listesi boş');
    }

    final spendingSummary = spending.entries
        .map((e) => '- ${e.key.displayNameTr}: ${e.value.toStringAsFixed(0)} TL')
        .join('\n');

    final fundsList = funds
        .map((f) =>
            '${f.id}: ${f.name} (${f.type.displayNameTr}, %${f.annualReturnRate} yıllık getiri, ${f.riskLevel.displayNameTr})')
        .join('\n');

    final riskDesc = switch (riskProfile) {
      RiskProfile.conservative => 'Muhafazakâr - sermaye koruma öncelikli',
      RiskProfile.balanced => 'Dengeli - risk/getiri dengesi',
      RiskProfile.aggressive => 'Agresif - yüksek getiri öncelikli',
    };

    final suggestedDefault = savingsAmount * 0.8;

    final prompt = '''
Sen ALTERA yatırım danışmanısın. Kullanıcının ay sonu tasarrufunu en uygun fona yönlendir.

Bu Ayki Harcamalar:
$spendingSummary

Tasarruf: ${savingsAmount.toStringAsFixed(0)} TL
Risk Profili: $riskDesc

Mevcut Fonlar (fund_id bu listeden seçilmeli):
$fundsList

Görevin: Risk profiline göre EN UYGUN tek fonu seç.
Türkçe kısa gerekçe yaz (en fazla 20 kelime).
suggested_amount = ${suggestedDefault.toStringAsFixed(0)} (tasarrufun %80'i)

JSON alanları: fund_id, fund_name, reasoning, suggested_amount
''';

    try {
      final responseText = await _generateWithRetry(prompt);
      final data =
          jsonDecode(_extractJson(responseText)) as Map<String, dynamic>;

      final rawFundId = (data['fund_id'] as String?)?.trim();
      final rawFundName = (data['fund_name'] as String?)?.trim().toLowerCase();

      InvestmentFund matchedFund;
      try {
        matchedFund = funds.firstWhere((f) => f.id == rawFundId);
      } catch (_) {
        try {
          matchedFund = funds.firstWhere(
            (f) => f.name.toLowerCase() == rawFundName,
          );
        } catch (_) {
          matchedFund = _getDefaultFundForRisk(riskProfile, funds);
        }
      }

      return InvestmentRecommendation(
        fundId: matchedFund.id,
        fundName: (data['fund_name'] as String?)?.trim() ?? matchedFund.name,
        reasoning: (data['reasoning'] as String?)?.trim() ??
            'Risk profilinize uygun seçim',
        suggestedAmount:
            (data['suggested_amount'] as num?)?.toDouble() ?? suggestedDefault,
      );
    } catch (_) {
      final defaultFund = _getDefaultFundForRisk(riskProfile, funds);
      return InvestmentRecommendation(
        fundId: defaultFund.id,
        fundName: defaultFund.name,
        reasoning: 'Risk profilinize göre otomatik seçildi',
        suggestedAmount: suggestedDefault,
      );
    }
  }

  /// Bütçe aşıldığında alternatif öneri metni üretir.
  Future<String> generateBudgetAlert({
    required TransactionCategory category,
    required double overspentAmount,
  }) async {
    final prompt = '''
Sen ALTERA finans asistanısın. Kullanıcı ${category.displayNameTr} kategorisinde ${overspentAmount.toStringAsFixed(0)} TL bütçe aştı.

Pratik ve motive edici bir öneri ver (en fazla 2 cümle, Türkçe).
Sadece öneri metnini yaz, başka hiçbir şey yazma.
''';

    try {
      final responseText = await _generateWithRetry(
        prompt,
        jsonMode: false,
      );
      return responseText.trim().isNotEmpty
          ? responseText.trim()
          : 'Bu ay bütçeni aştın. Harcamalarını gözden geçirmeyi dene.';
    } catch (_) {
      return 'Bu ay ${category.displayNameTr} bütçeni aştın. Harcamalarını gözden geçirmeyi dene.';
    }
  }

  /// Kullanıcının finansal sorularına veriye dayalı cevap verir (AI Sohbet).
  Future<String> chatWithFinancialAssistant({
    required String question,
    required Map<TransactionCategory, double> spending,
    required double monthlyIncome,
    required double monthlyExpense,
  }) async {
    final savings = monthlyIncome - monthlyExpense;
    final spendingSummary = spending.entries
        .where((e) => e.value > 0)
        .map((e) =>
            '- ${e.key.displayNameTr}: ${e.value.toStringAsFixed(0)} TL')
        .join('\n');

    final prompt = '''
Sen ALTERA kişisel finans asistanısın. Kullanıcının finansal verilerine göre sorularını yanıtla.

Bu Ayki Finansal Durum:
- Gelir: ${monthlyIncome.toStringAsFixed(0)} TL
- Gider: ${monthlyExpense.toStringAsFixed(0)} TL
- Tasarruf: ${savings.toStringAsFixed(0)} TL

Harcama Dağılımı:
${spendingSummary.isEmpty ? '- Henüz veri yok' : spendingSummary}

Kullanıcı Sorusu: $question

Türkçe, kısa ve pratik bir cevap ver (en fazla 4 cümle). Rakamları kullan, somut öneriler sun.
Sadece cevabı yaz, başka hiçbir şey ekleme.
''';

    final response = await _generateWithRetry(prompt, jsonMode: false);
    return response.trim();
  }

  /// Dashboard için aylık harcama içgörüsü üretir.
  /// Anomali tespiti ve hedef etkisi dahil 5-6 maddelik kapsamlı analiz.
  Future<String> generateMonthlyInsight({
    required Map<TransactionCategory, double> spending,
    required double monthlyIncome,
    required double monthlyExpense,
    required double savings,
    Map<TransactionCategory, double>? previousMonthSpending,
    Map<TransactionCategory, double>? budgetLimits,
  }) async {
    if (spending.isEmpty) {
      return '📊 Henüz yeterli veri yok.\n💡 Ajan döngüsünü çalıştırarak işlemleri analiz et.\n🎯 Analiz sonrası burada içgörüler görünecek.';
    }

    final topSpending = (spending.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .map((e) =>
            '${e.key.displayNameTr}: ${e.value.toStringAsFixed(0)} TL')
        .join(', ');

    final savingsRate = monthlyIncome > 0
        ? (savings / monthlyIncome * 100).toStringAsFixed(1)
        : '0';

    // Geçen aya göre anomaliler
    String anomalyContext = '';
    if (previousMonthSpending != null && previousMonthSpending.isNotEmpty) {
      final changes = <String>[];
      for (final entry in spending.entries) {
        final prev = previousMonthSpending[entry.key] ?? 0;
        if (prev > 0) {
          final changePercent = ((entry.value - prev) / prev * 100);
          if (changePercent.abs() > 25) {
            final sign = changePercent > 0 ? '+' : '';
            changes.add(
                '${entry.key.displayNameTr}: $sign${changePercent.toStringAsFixed(0)}%');
          }
        }
      }
      if (changes.isNotEmpty) {
        anomalyContext =
            '\nGeçen aya göre büyük değişimler: ${changes.take(3).join(', ')}';
      }
    }

    // Bütçe aşımları
    String budgetContext = '';
    if (budgetLimits != null && budgetLimits.isNotEmpty) {
      final overruns = <String>[];
      for (final entry in budgetLimits.entries) {
        final spent = spending[entry.key] ?? 0;
        if (spent > entry.value && entry.value > 0) {
          final pct = ((spent - entry.value) / entry.value * 100);
          overruns.add(
              '${entry.key.displayNameTr} +%${pct.toStringAsFixed(0)} aşıldı');
        }
      }
      if (overruns.isNotEmpty) {
        budgetContext = '\nBütçe aşımları: ${overruns.take(3).join(', ')}';
      }
    }

    final prompt = '''
Sen ALTERA finans asistanısın. Kullanıcının bu ayki verilerine göre 5-6 maddelik kapsamlı içgörü yaz.

Gelir: ${monthlyIncome.toStringAsFixed(0)} TL
Gider: ${monthlyExpense.toStringAsFixed(0)} TL
Tasarruf: ${savings.toStringAsFixed(0)} TL (%$savingsRate oran)
En fazla harcama: $topSpending$anomalyContext$budgetContext

Türkçe yaz, 5-6 madde, her madde tek satır ve emoji ile başlasın:
📊 Aylık özet (rakamlı)
⚠️ Anomali (büyük değişim varsa)
💡 Tasarruf önerisi (spesifik)
🎯 Hedef etkisi (mevcut tasarruf hızında 3-6 ay sonra ne olur?)
✅ Pozitif gözlem (varsa)
🚨 Bütçe uyarısı (aşılmışsa)

Sadece maddeleri yaz, başka hiçbir şey ekleme. Her madde 15 kelimeyi geçmesin.
''';

    try {
      final response = await _generateWithRetry(prompt, jsonMode: false);
      return response.trim();
    } catch (_) {
      return '📊 Harcamalarınız analiz edildi.\n💡 En yüksek gider: $topSpending.\n🎯 Tasarruf oranınız: %$savingsRate.';
    }
  }

  /// Kullanıcının harcama geçmişine göre bütçe limitleri önerir.
  Future<Map<TransactionCategory, double>> suggestBudgetLimits({
    required Map<TransactionCategory, double> spending,
    required double monthlyIncome,
  }) async {
    if (spending.isEmpty || monthlyIncome <= 0) return {};

    final spendingList = spending.entries
        .where((e) => e.value > 0)
        .map((e) => '"${e.key.name}": ${e.value.toStringAsFixed(0)}')
        .join(', ');

    final prompt = '''
Sen ALTERA bütçe danışmanısın. Harcama verisine göre aylık bütçe limitleri belirle.

Aylık Gelir: ${monthlyIncome.toStringAsFixed(0)} TL
Bu Ayki Harcamalar (TL): {$spendingList}

Kurallar:
- Toplam bütçe gelirin %85'ini geçmesin
- Her kategori için mevcut harcamaya %10-20 tampon ekle
- Sadece bu listedeki kategori isimlerini kullan

SADECE JSON döndür (başka hiçbir şey yazma):
{"market": 1500, "restaurant": 600, ...}
''';

    try {
      final response = await _generateWithRetry(prompt);
      final extracted = _extractJson(response);
      final data = jsonDecode(extracted) as Map<String, dynamic>;

      final result = <TransactionCategory, double>{};
      for (final entry in data.entries) {
        try {
          final category = TransactionCategory.values.byName(entry.key);
          final amount = (entry.value as num).toDouble();
          if (amount > 0) result[category] = amount;
        } catch (_) {}
      }
      return result;
    } catch (_) {
      // Fallback: mevcut harcamalara %15 tampon ekle
      return {
        for (final e in spending.entries)
          if (e.value > 0) e.key: (e.value * 1.15).ceilToDouble()
      };
    }
  }

  /// Detaylı finansal tahlil — kategori bazlı analiz, tasarruf engelleri, aksiyon önerileri.
  /// JSON formatında yapılandırılmış sonuç döndürür ki UI'da tablo/kartla gösterebilelim.
  Future<DetailedFinancialReport> generateDetailedReport({
    required Map<TransactionCategory, double> spending,
    required Map<TransactionCategory, double> previousMonthSpending,
    required Map<TransactionCategory, double> budgets,
    required double monthlyIncome,
    required double monthlyExpense,
    required double savings,
    required int needCount,
    required int wantCount,
  }) async {
    if (spending.isEmpty) {
      return const DetailedFinancialReport(
        summary: 'Henüz yeterli veri yok. İşlem ekleyerek analiz başlat.',
        categoryAnalyses: [],
        savingsBlockers: [],
        actions: [],
        overallScore: 0,
      );
    }

    final spendingList = spending.entries
        .where((e) => e.value > 0)
        .map((e) =>
            '${e.key.name}=${e.value.toStringAsFixed(0)} (geçen ay: ${(previousMonthSpending[e.key] ?? 0).toStringAsFixed(0)}, bütçe: ${(budgets[e.key] ?? 0).toStringAsFixed(0)})')
        .join('\n');

    final savingsRate = monthlyIncome > 0
        ? (savings / monthlyIncome * 100).toStringAsFixed(1)
        : '0';

    final prompt = '''
Sen ALTERA finans danışmanısın. Aşağıdaki kullanıcı verisini analiz et ve **DETAYLI** rapor üret.

GENEL TABLO:
- Aylık Gelir: ${monthlyIncome.toStringAsFixed(0)} TL
- Aylık Gider: ${monthlyExpense.toStringAsFixed(0)} TL
- Tasarruf: ${savings.toStringAsFixed(0)} TL (%$savingsRate)
- İhtiyaç işlem sayısı: $needCount | İstek işlem sayısı: $wantCount

KATEGORİ DETAYI (TL):
$spendingList

GÖREVİN: SADECE şu JSON formatında yanıt ver, başka hiçbir şey yazma:
{
  "summary": "2-3 cümlelik genel durum özeti, Türkçe",
  "category_analyses": [
    {
      "category": "market",
      "verdict": "İyi/Dikkat/Kritik",
      "comment": "Bu kategoride 1-2 cümlelik somut yorum, rakamlı (geçen aya kıyas, bütçe aşımı vs.)"
    }
  ],
  "savings_blockers": [
    "Tasarrufu engelleyen spesifik faktör 1 (örn: restoran harcaması bütçenin %180'i)",
    "Faktör 2"
  ],
  "actions": [
    "Yapılabilecek somut aksiyon 1 (örn: Restoran harcamasını 800 TL'ye düşür → ayda 700 TL tasarruf)",
    "Aksiyon 2"
  ],
  "overall_score": 75
}

Kurallar:
- category_analyses: en yüksek 4-5 harcama kategorisi için yorum yap
- savings_blockers: 2-4 maddelik liste, somut sebepler
- actions: 3-5 maddelik somut + rakamlı aksiyon
- overall_score: 0-100 arası finansal sağlık puanı (tasarruf oranı, bütçe uyumu, ihtiyaç/istek dengesi)
- Tüm metinler Türkçe, kısa ve rakamlı
- Genel motive edici dil, ama gerçekçi
''';

    // _generateWithRetry kendi GeminiException'larını fırlatır (kota, ağ vs.)
    // — burada yakalamıyoruz, doğrudan UI'a geçsin
    final response = await _generateWithRetry(prompt, maxOutputTokens: 2048);

    try {
      final data =
          jsonDecode(_extractJson(response)) as Map<String, dynamic>;

      final categoryAnalyses =
          ((data['category_analyses'] as List?) ?? const [])
              .map((e) => CategoryAnalysis(
                    category: _parseCategory(
                        (e as Map<String, dynamic>)['category']),
                    verdict: (e['verdict'] as String?) ?? '',
                    comment: (e['comment'] as String?) ?? '',
                  ))
              .toList();

      return DetailedFinancialReport(
        summary: (data['summary'] as String?) ?? '',
        categoryAnalyses: categoryAnalyses,
        savingsBlockers: ((data['savings_blockers'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        actions: ((data['actions'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        overallScore: (data['overall_score'] as num?)?.toInt() ?? 50,
      );
    } catch (e) {
      // Sadece JSON parse aşamasının hatası — Gemini yanıt verdi ama format bozuk
      throw GeminiException('Rapor formatı bozuk geldi (yanıt: ${response.length > 80 ? '${response.substring(0, 80)}...' : response})');
    }
  }

  /// Yeni eklenen işlem için kullanıcının geçmişine göre anlık yorum üretir.
  /// İşlem kaydedildiğinde gösterilir.
  Future<String> commentOnNewTransaction({
    required Transaction transaction,
    required Map<TransactionCategory, double> currentMonthSpending,
    required double categoryBudget,
    required double categorySpentSoFar,
  }) async {
    final isIncome = transaction.amount > 0;
    final absAmount = transaction.amount.abs();
    final categoryName = transaction.category.displayNameTr;

    final budgetLine = categoryBudget > 0
        ? 'Bu kategori için bütçen ${categoryBudget.toStringAsFixed(0)} TL, şu ana kadar ${categorySpentSoFar.toStringAsFixed(0)} TL harcadın.'
        : 'Bu kategori için bütçe tanımlanmamış.';

    final prompt = isIncome
        ? '''
Sen ALTERA finans asistanısın. Kullanıcı yeni bir GELİR ekledi.

İşlem: ${transaction.description} — ${absAmount.toStringAsFixed(0)} TL
Tarih: ${transaction.date.day}.${transaction.date.month}.${transaction.date.year}

Kısa, motive edici 1 cümle yaz (max 15 kelime, Türkçe). Sadece cevabı yaz.
Örnek: "Güzel kazanç! Bunu yatırıma yönlendirmek ister misin?"
'''
        : '''
Sen ALTERA finans asistanısın. Kullanıcı yeni bir GİDER ekledi.

İşlem: ${transaction.description} — ${absAmount.toStringAsFixed(0)} TL
Kategori: $categoryName
$budgetLine

Bu işlem hakkında somut, kısa bir yorum yaz (max 20 kelime, Türkçe).
- Bütçeyi geçtiyse uyar
- Olağandışı yüksekse dikkat çek
- Normal ise pozitif bir not düş
Sadece cevabı yaz, başka hiçbir şey ekleme.
''';

    try {
      final response = await _generateWithRetry(prompt, jsonMode: false);
      return response.trim();
    } catch (_) {
      return isIncome
          ? '${absAmount.toStringAsFixed(0)} TL gelir kaydedildi.'
          : '${absAmount.toStringAsFixed(0)} TL $categoryName harcaması kaydedildi.';
    }
  }

  /// E-fatura metninden işlem verisi çıkarır.
  Future<Map<String, dynamic>?> parseInvoice(String invoiceText) async {
    final prompt = '''
Aşağıdaki fatura/e-posta metninden işlem bilgilerini çıkar.

Metin:
$invoiceText

SADECE geçerli JSON döndür (bulamazsan {"description":null} döndür):
{"description": "...", "amount": 0.0, "date": "YYYY-MM-DD"}
''';

    try {
      final responseText = await _generateWithRetry(prompt);
      if (responseText.contains('null')) return null;
      final data =
          jsonDecode(_extractJson(responseText)) as Map<String, dynamic>;
      if (data['description'] == null) return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  /// İçerik üretir; rate limit ve model bulunamadı hatalarında yeniden dener.
  Future<String> _generateWithRetry(
    String prompt, {
    bool jsonMode = true,
    Schema? schema,
    int? maxOutputTokens,
  }) async {
    String? responseText;

    for (var attempt = 0; attempt < AppConstants.kGeminiMaxRetries; attempt++) {
      try {
        responseText = await _generateContent(
          prompt,
          jsonMode: jsonMode,
          schema: schema,
          maxOutputTokens: maxOutputTokens,
        );
        if (responseText != null && responseText.isNotEmpty) {
          return responseText;
        }
        throw const GeminiException('Gemini boş yanıt döndürdü');
      } catch (e) {
        final errStr = e.toString();
        // Kota dolduysa yeniden deneme — 58s x 3 bekleme yapma
        if (_isQuotaError(errStr)) {
          throw _toException(errStr);
        }
        if (_isModelNotFound(errStr) && _tryNextModel()) {
          continue;
        }
        if (attempt == AppConstants.kGeminiMaxRetries - 1) {
          throw _toException(errStr);
        }
        final delayMs = _retryDelayMs(errStr);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    throw const GeminiException('Gemini yanıt alınamadı');
  }

  Future<String?> _generateContent(
    String prompt, {
    required bool jsonMode,
    Schema? schema,
    int? maxOutputTokens,
  }) async {
    // Günlük limit kontrolü — gerçek API çağrısı yapmadan önce
    if (ApiQuotaTracker.isLimitReached()) {
      throw const GeminiException(
        'Günlük API limiti (1500) doldu. Yarın tekrar dene.',
        isQuotaExceeded: true,
      );
    }

    final config = jsonMode
        ? GenerationConfig(
            maxOutputTokens: maxOutputTokens ?? AppConstants.kGeminiMaxTokens,
            temperature: 0.1,
            responseMimeType: 'application/json',
            responseSchema: schema, // null = sadece JSON modu, şema kısıtı yok
          )
        : GenerationConfig(
            maxOutputTokens: maxOutputTokens ?? AppConstants.kGeminiMaxTokens,
            temperature: 0.3,
          );

    try {
      final response = await GenerativeModel(
        model: _modelIdAt(_activeModelIndex),
        apiKey: _apiKey,
        generationConfig: config,
      ).generateContent([Content.text(prompt)]);

      await ApiQuotaTracker.increment(); // başarılı
      return response.text;
    } catch (e) {
      // Başarısız çağrı da sayılır — quota debug için
      await ApiQuotaTracker.incrementFailed(e.toString());
      rethrow;
    }
  }

  /// Birden fazla işlemi tek API çağrısında analiz eder.
  /// Her işlem için ayrı çağrı yerine hepsini bir promptta gönderir.
  Future<List<TransactionAnalysis?>> analyzeTransactionsBatch(
    List<Transaction> transactions,
  ) async {
    if (transactions.isEmpty) return [];

    final stopwatch = Stopwatch()..start();

    final txLines = transactions.asMap().entries.map((e) {
      final tx = e.value;
      final isIncome = tx.amount > 0;
      return '${e.key}. "${tx.description}" — ${tx.amount.abs().toStringAsFixed(2)} TL (${isIncome ? 'GELİR' : 'GİDER'})';
    }).join('\n');

    final prompt = '''
Sen ALTERA kişisel finans asistanısın. Aşağıdaki ${transactions.length} banka işlemini analiz et.

Kurallar:
- Kategori seçenekleri: ${_categoryNames.join(', ')}
- GELİR işlemlerde type mutlaka "income" olmalı
- GİDER işlemlerde type "need" (zorunlu harcama) veya "want" (istek/lüks) olmalı
- reason: Türkçe, max 10 kelime

İşlemler:
$txLines

SADECE şu formatta JSON döndür, başka hiçbir şey yazma:
{"results":[{"index":0,"category":"...","type":"...","reason":"..."}]}
''';

    final responseText = await _generateWithRetry(
      prompt,
      maxOutputTokens: 2048,
    );

    stopwatch.stop();
    final durationMs = stopwatch.elapsedMilliseconds;

    try {
      final extracted = _extractJson(responseText);
      final decoded = jsonDecode(extracted) as Map<String, dynamic>;
      final rawList = decoded['results'] as List<dynamic>;
      final results = List<TransactionAnalysis?>.filled(transactions.length, null);

      for (final item in rawList) {
        final map = item as Map<String, dynamic>;
        final index = (map['index'] as num?)?.toInt();
        if (index == null || index < 0 || index >= transactions.length) continue;

        final tx = transactions[index];
        final isIncome = tx.amount > 0;

        results[index] = TransactionAnalysis(
          category: _parseCategory(map['category']),
          type: isIncome
              ? TransactionType.income
              : _parseType(map['type'], isIncome: false),
          reason: (map['reason'] as String?)?.trim() ?? '',
          durationMs: durationMs ~/ transactions.length,
        );
      }

      return results;
    } catch (e) {
      throw GeminiException('Batch yanıt parse hatası: $responseText');
    }
  }

  bool _tryNextModel() {
    if (_activeModelIndex >= _modelCount - 1) return false;
    _activeModelIndex++;
    return true;
  }

  static bool _isModelNotFound(String error) {
    final lower = error.toLowerCase();
    return lower.contains('not found') ||
        lower.contains('not supported') ||
        lower.contains('does not exist') ||
        lower.contains('invalid model');
  }

  /// Kategori değerini güvenli şekilde enum'a çevirir.
  static TransactionCategory _parseCategory(dynamic raw) {
    if (raw == null) return TransactionCategory.other;

    final normalized = raw.toString().trim().toLowerCase();

    // Doğrudan enum adı
    for (final cat in TransactionCategory.values) {
      if (cat.name == normalized) return cat;
    }

    // Yaygın eşanlamlılar / Türkçe karşılıklar
    const aliases = <String, TransactionCategory>{
      'grocery': TransactionCategory.market,
      'supermarket': TransactionCategory.market,
      'food': TransactionCategory.market,
      'market_alisveris': TransactionCategory.market,
      'alisveris': TransactionCategory.market,
      'cafe': TransactionCategory.restaurant,
      'yemek': TransactionCategory.restaurant,
      'restoran': TransactionCategory.restaurant,
      'dining': TransactionCategory.restaurant,
      'ulasim': TransactionCategory.transport,
      'transportation': TransactionCategory.transport,
      'taxi': TransactionCategory.transport,
      'uber': TransactionCategory.transport,
      'fatura': TransactionCategory.bill,
      'utility': TransactionCategory.bill,
      'utilities': TransactionCategory.bill,
      'giyim': TransactionCategory.clothing,
      'fashion': TransactionCategory.clothing,
      'eglence': TransactionCategory.entertainment,
      'fun': TransactionCategory.entertainment,
      'saglik': TransactionCategory.health,
      'medical': TransactionCategory.health,
      'egitim': TransactionCategory.education,
      'education': TransactionCategory.education,
      'yatirim': TransactionCategory.investment,
      'gelir': TransactionCategory.income,
      'salary': TransactionCategory.income,
      'maas': TransactionCategory.income,
      'diger': TransactionCategory.other,
      'misc': TransactionCategory.other,
      'miscellaneous': TransactionCategory.other,
    };

    return aliases[normalized] ?? TransactionCategory.other;
  }

  /// Tür değerini güvenli şekilde enum'a çevirir.
  static TransactionType _parseType(dynamic raw, {required bool isIncome}) {
    if (isIncome) return TransactionType.income;
    if (raw == null) return TransactionType.need;

    final normalized = raw.toString().trim().toLowerCase();

    for (final t in TransactionType.values) {
      if (t.name == normalized) return t;
    }

    const aliases = <String, TransactionType>{
      'ihtiyac': TransactionType.need,
      'necessity': TransactionType.need,
      'essential': TransactionType.need,
      'istek': TransactionType.want,
      'luxury': TransactionType.want,
      'gelir': TransactionType.income,
      'revenue': TransactionType.income,
    };

    return aliases[normalized] ?? TransactionType.need;
  }

  static int _retryDelayMs(String error) {
    final match = RegExp(r'retry in (\d+\.?\d*)').firstMatch(error);
    if (match != null) {
      final seconds = double.tryParse(match.group(1) ?? '') ?? 10.0;
      return ((seconds + 2) * 1000).toInt();
    }
    return AppConstants.kRateLimitDelayMs;
  }

  static GeminiException _toException(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('quota') ||
        lower.contains('exceeded') ||
        lower.contains('resource_exhausted') ||
        (lower.contains('limit') && lower.contains('rate'))) {
      final retrySeconds = _parseRetrySeconds(raw);
      if (retrySeconds != null) {
        final secs = retrySeconds.ceil();
        return GeminiException(
          'Gemini kota aşıldı (~${secs}s sonra tekrar dene)',
          isQuotaExceeded: true,
          retryAfterSeconds: secs,
        );
      }
      return const GeminiException(
        'Gemini API kota sınırı aşıldı — birkaç dakika bekleyin',
        isQuotaExceeded: true,
      );
    }
    if (lower.contains('api key') ||
        lower.contains('invalid key') ||
        lower.contains('api_key_invalid')) {
      return const GeminiException('Gemini API anahtarı geçersiz');
    }
    if (lower.contains('network') || lower.contains('socket')) {
      return const GeminiException('Ağ bağlantısı hatası');
    }
    final cleaned = raw
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final msg =
        cleaned.length > 100 ? '${cleaned.substring(0, 100)}...' : cleaned;
    return GeminiException(msg);
  }

  static bool _isQuotaError(String raw) {
    final lower = raw.toLowerCase();
    return lower.contains('quota') ||
        lower.contains('resource_exhausted') ||
        lower.contains('rate limit') ||
        (lower.contains('exceeded') && lower.contains('limit'));
  }

  static int? _parseRetrySeconds(String raw) {
    final match = RegExp(r'retry in (\d+\.?\d*)').firstMatch(raw);
    if (match == null) return null;
    return double.tryParse(match.group(1) ?? '')?.ceil();
  }

  String _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1) {
      throw FormatException('JSON bulunamadı: $text');
    }
    return text.substring(start, end + 1);
  }

  InvestmentFund _getDefaultFundForRisk(
      RiskProfile risk, List<InvestmentFund> funds) {
    return switch (risk) {
      RiskProfile.conservative => funds.firstWhere(
          (f) => f.riskLevel == RiskLevel.low,
          orElse: () => funds.first,
        ),
      RiskProfile.balanced => funds.firstWhere(
          (f) => f.riskLevel == RiskLevel.medium,
          orElse: () => funds.first,
        ),
      RiskProfile.aggressive => funds.firstWhere(
          (f) => f.riskLevel == RiskLevel.high,
          orElse: () => funds.first,
        ),
    };
  }
}
