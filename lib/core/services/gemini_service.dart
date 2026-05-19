// ALTERA Gemini 2.0 Flash servis katmanı - tüm AI çağrıları burada
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../constants/app_constants.dart';
import '../models/asset.dart';
import '../models/transaction.dart';
import '../models/investment_fund.dart';
import '../models/user_profile.dart';
import '../security/privacy_filter.dart';

/// Gemini API yanıt parse hatası
class GeminiException implements Exception {
  final String message;
  final int? statusCode;

  const GeminiException(this.message, {this.statusCode});

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
  final GenerativeModel? _model;
  final bool _isEmpty;

  GeminiService._(String apiKey)
    : _isEmpty = false,
      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          maxOutputTokens: AppConstants.kGeminiMaxTokens,
          temperature: 0.1,
        ),
      );

  /// API key yokken kullanılır — hiç network çağrısı yapmaz.
  /// Her metod için varsayılan (offline) yanıt döner.
  GeminiService.disabled()
    : _isEmpty = true,
      _model = null;

  /// API key'den non-printable ve non-ASCII karakterleri temizler.
  /// Terminal prompt yapıştırma hatalarını (ANSI escape codes) engeller.
  static String _sanitizeKey(String raw) =>
      raw.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();

  /// Servisin etkin olup olmadığını döndürür.
  bool get isEnabled => !_isEmpty;

  /// flutter_secure_storage'dan API key okuyarak modeli başlatır
  static Future<GeminiService> initialize() async {
    const storage = FlutterSecureStorage();
    final raw = await storage.read(key: AppConstants.kSecureKeyGeminiApiKey);
    if (raw == null || raw.isEmpty) {
      throw const GeminiException(
        'Gemini API key bulunamadı. Lütfen ayarlardan API key girin.',
      );
    }
    final apiKey = _sanitizeKey(raw);
    if (apiKey.isEmpty) {
      throw const GeminiException(
        'Gemini API key geçersiz karakter içeriyor. Lütfen ayarlardan tekrar girin.',
      );
    }
    return GeminiService._(apiKey);
  }

  /// Doğrudan API key ile oluşturur — key otomatik sanitize edilir.
  /// Boş key için [GeminiService.disabled()] kullanın.
  factory GeminiService.withKey(String apiKey) {
    final sanitized = _sanitizeKey(apiKey);
    if (sanitized.isEmpty) return GeminiService.disabled();
    return GeminiService._(sanitized);
  }

  /// Tek bir işlemi analiz eder - kategori, tür ve gerekçe döndürür.
  Future<TransactionAnalysis> analyzeTransaction(Transaction tx) async {
    if (_isEmpty) {
      throw const GeminiException('Gemini API key ayarlanmamış.');
    }
    final stopwatch = Stopwatch()..start();

    // Kişisel veriyi maskele
    final safeDesc = PrivacyFilter.sanitizeDescription(tx.description);
    final absAmount = tx.amount.abs().toStringAsFixed(2);
    final txDirection = tx.amount > 0 ? 'Gelir' : 'Gider';

    // Delimiter ile prompt injection engelle; tarih gönderilmez
    final prompt = '''
Sen ALTERA kişisel finans asistanısın. Aşağıdaki banka işlemini analiz et.

---ISLEM_BASLANGIC---
Açıklama: $safeDesc
Tutar: $absAmount TL
Tür: $txDirection
---ISLEM_BITIS---

Görevin:
1. Kategoriyi belirle: market | restaurant | transport | bill | clothing | entertainment | health | education | investment | income | other
2. Türünü belirle: need (ihtiyaç) | want (istek) | income (gelir)
3. Kısa Türkçe gerekçe yaz (max 10 kelime)

SADECE geçerli JSON döndür, başka hiçbir şey yazma:
{"category": "...", "type": "...", "reason": "..."}
''';

    String? responseText;
    for (var attempt = 0; attempt < AppConstants.kGeminiMaxRetries; attempt++) {
      try {
        final response = await _model!.generateContent([Content.text(prompt)]);
        responseText = response.text;
        break;
      } catch (e) {
        final errStr = e.toString();
        if (attempt == AppConstants.kGeminiMaxRetries - 1) {
          throw GeminiException(_summarizeError(errStr));
        }
        final baseDelay = _retryDelayMs(errStr);
        final delayMs = baseDelay * (attempt + 1);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    stopwatch.stop();

    if (responseText == null || responseText.isEmpty) {
      throw const GeminiException('Gemini boş yanıt döndürdü');
    }

    try {
      final json = _extractJson(responseText);
      final data = jsonDecode(json) as Map<String, dynamic>;

      final categoryStr = data['category'] as String? ?? 'other';
      final typeStr = data['type'] as String? ?? 'need';

      // Bilinmeyen enum değeri için güvenli fallback
      TransactionCategory category;
      try {
        category = TransactionCategory.values.byName(categoryStr);
      } catch (_) {
        category = TransactionCategory.other;
      }

      TransactionType type;
      try {
        type = TransactionType.values.byName(typeStr);
      } catch (_) {
        type = TransactionType.need;
      }

      return TransactionAnalysis(
        category: category,
        type: type,
        reason: (() {
          final raw = data['reason'] as String? ?? '';
          return raw.length > 200 ? raw.substring(0, 200) : raw;
        })(),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      if (e is GeminiException) rethrow;
      throw GeminiException('Yanıt parse hatası');
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
      return const InvestmentRecommendation(
        fundId: '',
        fundName: 'Fon tanımlı değil',
        reasoning: 'Yatırım fonu listesi boş',
        suggestedAmount: 0,
      );
    }

    if (_isEmpty) {
      final defaultFund = _getDefaultFundForRisk(riskProfile, funds);
      return InvestmentRecommendation(
        fundId: defaultFund.id,
        fundName: defaultFund.name,
        reasoning: 'Risk profilinize göre otomatik seçildi',
        suggestedAmount: savingsAmount * 0.8,
      );
    }

    final spendingSummary = spending.entries
        .map(
          (e) => '- ${e.key.displayNameTr}: ${e.value.toStringAsFixed(0)} TL',
        )
        .join('\n');

    final fundsList = funds
        .map(
          (f) =>
              '${f.id}: ${f.name} (${f.type.displayNameTr}, %${f.annualReturnRate} yıllık getiri, ${f.riskLevel.displayNameTr})',
        )
        .join('\n');

    final riskDesc = switch (riskProfile) {
      RiskProfile.conservative => 'Muhafazakâr - sermaye koruma öncelikli',
      RiskProfile.balanced => 'Dengeli - risk/getiri dengesi',
      RiskProfile.aggressive => 'Agresif - yüksek getiri öncelikli',
    };

    final prompt = '''
Sen ALTERA yatırım danışmanısın. Kullanıcının ay sonu tasarrufunu en uygun fona yönlendir.

Bu Ayki Harcamalar:
$spendingSummary

Tasarruf: ${savingsAmount.toStringAsFixed(0)} TL
Risk Profili: $riskDesc

Mevcut Fonlar:
$fundsList

Görevin: Kullanıcının risk profiline ve harcama alışkanlıklarına göre EN UYGUN tek fonu seç.
Türkçe kısa gerekçe yaz (max 20 kelime).

SADECE geçerli JSON döndür:
{"fund_id": "...", "fund_name": "...", "reasoning": "...", "suggested_amount": 0.0}

Not: suggested_amount = tasarrufun %80'i (${(savingsAmount * 0.8).toStringAsFixed(0)} TL)
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';
      final json = _extractJson(responseText);
      final data = jsonDecode(json) as Map<String, dynamic>;

      final fundId = data['fund_id'] as String? ?? '';
      final knownIds = funds.map((f) => f.id).toSet();
      // Bilinmeyen fund_id gelirse risk profiline göre varsayılan seç
      final resolvedFund =
          knownIds.contains(fundId)
              ? funds.firstWhere((f) => f.id == fundId)
              : _getDefaultFundForRisk(riskProfile, funds);

      final rawAmount =
          (data['suggested_amount'] as num?)?.toDouble() ?? savingsAmount * 0.8;
      // Negatif öneri sıfıra, %80 limitini aşan öneri limite çekilir
      final safeAmount = rawAmount.clamp(0.0, savingsAmount * 0.8).toDouble();

      return InvestmentRecommendation(
        fundId: resolvedFund.id,
        fundName: resolvedFund.name,
        reasoning:
            data['reasoning'] as String? ?? 'Risk profilinize uygun seçim',
        suggestedAmount: safeAmount,
      );
    } catch (e) {
      final defaultFund = _getDefaultFundForRisk(riskProfile, funds);
      return InvestmentRecommendation(
        fundId: defaultFund.id,
        fundName: defaultFund.name,
        reasoning: 'Risk profilinize göre otomatik seçildi',
        suggestedAmount: savingsAmount * 0.8,
      );
    }
  }

  /// Bütçe aşıldığında alternatif öneri metni üretir.
  Future<String> generateBudgetAlert({
    required TransactionCategory category,
    required double overspentAmount,
  }) async {
    if (_isEmpty) {
      return 'Bu ay ${category.displayNameTr} bütçeni aştın. Harcamalarını gözden geçirmeyi dene.';
    }

    final prompt = '''
Sen ALTERA finans asistanısın. Kullanıcı ${category.displayNameTr} kategorisinde ${overspentAmount.toStringAsFixed(0)} TL bütçe aştı.

Pratik ve motive edici bir öneri ver (max 2 cümle, Türkçe).
Sadece öneri metnini yaz, başka hiçbir şey yazma.
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text?.trim() ??
          'Bu ay bütçeni aştın. Harcamalarını gözden geçirmeyi dene.';
    } catch (_) {
      return 'Bu ay ${category.displayNameTr} bütçeni aştın. Harcamalarını gözden geçirmeyi dene.';
    }
  }

  /// E-fatura metninden işlem verisi çıkarır.
  /// Kişisel veriler (IBAN, TC, e-posta) Gemini'ye gönderilmeden önce maskelenir.
  Future<Map<String, dynamic>?> parseInvoice(String invoiceText) async {
    if (_isEmpty) return null;

    // Gizlilik filtresi — fatura metninde hassas veriler olabilir
    final safeText = PrivacyFilter.sanitizeDescription(
      invoiceText,
      maxLength: 500,
    );

    final prompt = '''
Aşağıdaki fatura/e-posta metninden işlem bilgilerini çıkar.

---METIN_BASLANGIC---
$safeText
---METIN_BITIS---

SADECE geçerli JSON döndür (bulamazsan null döndür):
{"description": "...", "amount": 0.0, "date": "YYYY-MM-DD"}
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';
      if (responseText.contains('null')) return null;
      final json = _extractJson(responseText);
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Canlı fiyat + günlük P&L verisiyle portföy önerileri üretir.
  Future<String> generatePortfolioInsights(String portfolioContext) async {
    if (_isEmpty) {
      return 'Portföy analizi için ayarlardan Gemini API key tanımlamanız gerekiyor.';
    }

    final prompt = '''
Sen ALTERA kişisel finans ajanısın. Kullanıcının gerçek zamanlı portföy verilerini incele.
Türkiye ekonomisi bağlamında (enflasyon, döviz kuru, piyasa koşulları) düşün.

PORTFÖY VERİLERİ:
$portfolioContext

Her varlık için aşağıdaki formatta SADECe üç sütunlu bir liste yaz:

[VARLIK ADI] → [AL / SAT / TUT] → [1 cümle gerekçe + rakam]

Kurallar:
- AL: Fiyat düştüyse veya uzun vadeli potansiyel yüksekse öner.
- SAT: Kâr realizasyonu zamanı geldiyse veya risk yükseldiyse öner (örn. +%15 üzeri kâr varsa).
- TUT: Nötr durum, büyük hareket yoksa öner.
- Her varlık için mutlaka bir karar ver, "belki" yazma.
- Rakamları kullan (₺ veya %).
- Son satırda portföy geneli için 1 cümle özet yaz.
- Giriş cümlesi yazma, direkt listeyle başla.

UYARI: Bu bilgiler yatırım tavsiyesi değildir; yalnızca bilgi amaçlıdır.
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text?.trim() ??
          'Portföy analizi şu an gerçekleştirilemiyor.';
    } catch (e) {
      final errStr = e.toString();
      if (isRateLimitError(errStr)) {
        return 'API kotası aşıldı, lütfen biraz bekleyip tekrar deneyin.';
      }
      if (e is FormatException || errStr.contains('Invalid HTTP header')) {
        return 'API key geçersiz — Ayarlar ekranından Gemini API key\'inizi kontrol edip tekrar girin.';
      }
      return 'Analiz yapılamadı: ${_summarizeError(errStr)}';
    }
  }

  /// Eski metod — geriye dönük uyumluluk için korunuyor.
  Future<String> analyzePortfolio(List<Asset> assets) async {
    if (assets.isEmpty) {
      return 'Portföyün şu an boş. Hemen bir varlık ekleyerek enflasyona karşı korunmaya başla!';
    }
    final lines = assets
        .map(
          (a) =>
              '- ${a.name}: ${a.totalCost.toStringAsFixed(0)} TL maliyetle alınmış.',
        )
        .join('\n');
    return generatePortfolioInsights(lines);
  }

  /// Hata mesajından "retry in X.Xs" süresini parse eder (ms).
  static int _retryDelayMs(String error) {
    final match = RegExp(
      r'retry[_\s](?:in|delay)[:\s]+(\d+\.?\d*)',
    ).firstMatch(error.toLowerCase());
    if (match != null) {
      final seconds = double.tryParse(match.group(1) ?? '') ?? 10.0;
      return ((seconds + 3) * 1000).toInt();
    }
    return AppConstants.kRateLimitDelayMs;
  }

  /// Rate limit / quota hatası olup olmadığını döndürür.
  static bool isRateLimitError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('quota') ||
        lower.contains('exceeded') ||
        lower.contains('rate limit') ||
        lower.contains('resource_exhausted') ||
        lower.contains('429') ||
        lower.contains('too many requests') ||
        lower.contains('kota');
  }

  /// Uzun API hata metnini kısa, Türkçe özete dönüştürür.
  static String _summarizeError(String raw) {
    if (isRateLimitError(raw)) {
      final retryMatch = RegExp(
        r'retry[_\s](?:in|delay)[:\s]+(\d+\.?\d*)',
      ).firstMatch(raw.toLowerCase());
      if (retryMatch != null) {
        return 'Gemini kota aşıldı (${retryMatch.group(1)}s sonra tekrar dene)';
      }
      return 'Gemini API kota/rate-limit aşıldı';
    }
    final lower = raw.toLowerCase();
    if (lower.contains('api key') ||
        lower.contains('invalid key') ||
        lower.contains('unauthorized')) {
      return 'Gemini API anahtarı geçersiz';
    }
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection')) {
      return 'Ağ bağlantısı hatası';
    }
    final cleaned =
        raw
            .replaceAll(RegExp(r'https?://\S+'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    return cleaned.length > 100 ? '${cleaned.substring(0, 100)}...' : cleaned;
  }

  /// JSON yanıtından { } bloğunu çıkarır
  String _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw const GeminiException('Yanıtta JSON bulunamadı');
    }
    return text.substring(start, end + 1);
  }

  /// Risk profiline göre varsayılan fon seçer.
  /// [funds] boş olmamalıdır — çağıran taraf kontrol etmeli.
  InvestmentFund _getDefaultFundForRisk(
    RiskProfile risk,
    List<InvestmentFund> funds,
  ) {
    assert(
      funds.isNotEmpty,
      '_getDefaultFundForRisk çağrısından önce funds.isEmpty kontrol edin',
    );
    if (funds.isEmpty) throw const GeminiException('Yatırım fonu listesi boş');
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
