// ALTERA Gemini 2.0 Flash servis katmanı - tüm AI çağrıları burada
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../constants/app_constants.dart';
import '../utils/api_key_storage.dart';
import '../models/transaction.dart';
import '../models/investment_fund.dart';
import '../models/user_profile.dart';

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

    final responseText = await _generateWithRetry(prompt);
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
  }) async {
    String? responseText;

    for (var attempt = 0; attempt < AppConstants.kGeminiMaxRetries; attempt++) {
      try {
        responseText = await _generateContent(prompt, jsonMode: jsonMode);
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
  }) async {
    final config = jsonMode
        ? GenerationConfig(
            maxOutputTokens: AppConstants.kGeminiMaxTokens,
            temperature: 0.1,
            responseMimeType: 'application/json',
            responseSchema: _transactionSchema,
          )
        : GenerationConfig(
            maxOutputTokens: AppConstants.kGeminiMaxTokens,
            temperature: 0.3,
          );

    final response = await GenerativeModel(
      model: _modelIdAt(_activeModelIndex),
      apiKey: _apiKey,
      generationConfig: config,
    ).generateContent([Content.text(prompt)]);

    return response.text;
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
