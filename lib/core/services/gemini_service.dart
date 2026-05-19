// ALTERA Gemini 2.0 Flash servis katmanı - tüm AI çağrıları burada
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../models/asset.dart';
import '../models/investment_fund.dart';
import '../models/transaction.dart';
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
/// Tüm AI çağrıları buradan geçer — ajanlar bu sınıfı kullanır.
/// API key yoksa GeminiException fırlatır; UI bunu yakalamalı ve
/// kullanıcıya "Ayarlar > API Key" yönlendirmesi göstermelidir.
class GeminiService {
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  final String _apiKey;

  GeminiService._(this._apiKey);

  /// flutter_secure_storage'dan API key okuyarak servisi başlatır.
  /// Key yoksa veya boşsa GeminiException fırlatır.
  static Future<GeminiService> initialize() async {
    const storage = FlutterSecureStorage();
    final apiKey = await storage.read(key: AppConstants.kSecureKeyGeminiApiKey);
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const GeminiException(
        'Gemini API key bulunamadı. Lütfen Ayarlar ekranından API key ekleyin.',
      );
    }
    return GeminiService._(apiKey.trim());
  }

  /// Test amaçlı doğrudan API key ile oluşturur
  factory GeminiService.withKey(String apiKey) => GeminiService._(apiKey);

  /// Gemini 2.0 Flash REST API'sini çağırır, düz metin yanıt döner.
  Future<String?> _callGemini(String prompt) async {
    final uri = Uri.parse('$_baseUrl?key=$_apiKey');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': AppConstants.kGeminiMaxTokens,
        },
      }),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw GeminiException(
        'Gemini API anahtarı geçersiz veya yetkisiz.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode == 429) {
      throw GeminiException(
        'Gemini API kota/rate-limit aşıldı.',
        statusCode: 429,
      );
    }
    if (response.statusCode != 200) {
      throw GeminiException(
        'Gemini API Hatası: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;
    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    return parts?.first['text'] as String?;
  }

  /// Tek bir işlemi analiz eder — kategori, tür ve gerekçe döndürür.
  /// Hassas veriler PrivacyFilter ile temizlendikten sonra API'ye gönderilir.
  Future<TransactionAnalysis> analyzeTransaction(Transaction tx) async {
    final stopwatch = Stopwatch()..start();

    final safeDescription = PrivacyFilter.sanitizeDescription(tx.description);
    final amount = tx.amount.abs().toStringAsFixed(2);
    final direction = tx.amount > 0 ? 'Gelir' : 'Gider';

    final prompt = '''
Sen ALTERA kişisel finans asistanısın. Aşağıdaki banka işlemini analiz et.

İşlem: $safeDescription
Tutar: $amount TL
Tür: $direction

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
        responseText = await _callGemini(prompt);
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

      return TransactionAnalysis(
        category: TransactionCategory.values.firstWhere(
          (e) => e.name == (data['category']?.toString().toLowerCase()),
          orElse: () => TransactionCategory.other,
        ),
        type: TransactionType.values.firstWhere(
          (e) => e.name == (data['type']?.toString().toLowerCase()),
          orElse: () => TransactionType.need,
        ),
        reason: data['reason'] as String? ?? '',
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
      final responseText = await _callGemini(prompt) ?? '';
      final json = _extractJson(responseText);
      final data = jsonDecode(json) as Map<String, dynamic>;

      return InvestmentRecommendation(
        fundId: data['fund_id'] as String? ?? funds.first.id,
        fundName: data['fund_name'] as String? ?? funds.first.name,
        reasoning:
            data['reasoning'] as String? ?? 'Risk profilinize uygun seçim',
        suggestedAmount:
            (data['suggested_amount'] as num?)?.toDouble() ??
            savingsAmount * 0.8,
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
    final prompt = '''
Sen ALTERA finans asistanısın. Kullanıcı ${category.displayNameTr} kategorisinde ${overspentAmount.toStringAsFixed(0)} TL bütçe aştı.

Pratik ve motive edici bir öneri ver (max 2 cümle, Türkçe).
Sadece öneri metnini yaz, başka hiçbir şey yazma.
''';

    try {
      final responseText = await _callGemini(prompt);
      return responseText?.trim() ??
          'Bu ay bütçeni aştın. Harcamalarını gözden geçirmeyi dene.';
    } catch (_) {
      return 'Bu ay ${category.displayNameTr} bütçeni aştın. Harcamalarını gözden geçirmeyi dene.';
    }
  }

  /// Belge metninden işlem listesi çıkarır (dekont/PDF/Excel analizi için).
  /// Dönüş değeri: List<Map> — her map bir işlem satırını temsil eder.
  Future<List<dynamic>> parseDocumentTransactions(String documentText) async {
    if (documentText.trim().isEmpty) {
      throw const GeminiException('Belgeden metin okunamadı.');
    }

    final prompt = '''
Sen ALTERA finansal analiz ajanısın. Aşağıdaki belge içeriğini analiz et ve tüm harcama/gelir kalemlerini bul.
SADECE geçerli bir JSON Array formatında döndür. Başka hiçbir açıklama yazma.

Örnek Çıktı:
[
  {
    "description": "Migros A.Ş.",
    "amount": -250.50,
    "date": "2023-10-25T00:00:00",
    "category": "market",
    "type": "need"
  }
]

Belge İçeriği (maksimum 2000 karakter):
${documentText.length > 2000 ? documentText.substring(0, 2000) : documentText}
''';

    final responseText = await _callGemini(prompt) ?? '';
    final start = responseText.indexOf('[');
    final end = responseText.lastIndexOf(']');

    if (start == -1 || end == -1) {
      throw const GeminiException('Belgede işlem bulunamadı.');
    }

    final jsonStr = responseText.substring(start, end + 1);
    final list = jsonDecode(jsonStr) as List<dynamic>;
    if (list.isEmpty) {
      throw const GeminiException('Belgede işlem bulunamadı.');
    }
    return list;
  }

  /// Canlı portföy verisiyle analiz ve öneri üretir.
  Future<String> generatePortfolioInsights(String portfolioContext) async {
    final prompt = '''
Sen ALTERA kişisel finans ajanısın. Kullanıcının gerçek zamanlı portföy verilerini incele.
Türkiye ekonomisi bağlamında (enflasyon, döviz kuru, piyasa koşulları) düşün.

PORTFÖY VERİLERİ:
$portfolioContext

Her varlık için aşağıdaki formatta SADECE üç sütunlu bir liste yaz:

[VARLIK ADI] → [AL / SAT / TUT] → [1 cümle gerekçe + rakam]

Kurallar:
- AL: Fiyat düştüyse veya uzun vadeli potansiyel yüksekse öner.
- SAT: Kâr realizasyonu zamanı geldiyse veya risk yükseldiyse öner (örn. +%15 üzeri kâr varsa).
- TUT: Nötr durum, büyük hareket yoksa öner.
- Her varlık için mutlaka bir karar ver, "belki" yazma.
- Rakamları kullan (₺ veya %).
- Son satırda portföy geneli için 1 cümle özet yaz.
- Giriş cümlesi yazma, direkt listeyle başla.
''';

    try {
      final responseText = await _callGemini(prompt);
      return responseText?.trim() ??
          'Portföy analizi şu an gerçekleştirilemiyor.';
    } catch (e) {
      if (isRateLimitError(e.toString())) {
        return 'API kotası aşıldı, lütfen biraz bekleyip tekrar deneyin.';
      }
      return 'Analiz yapılamadı: ${_summarizeError(e.toString())}';
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

  /// Hata mesajından retry süresini parse eder (ms).
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

  /// Hata mesajının rate limit kaynaklı olup olmadığını döndürür.
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
    if (start == -1 || end == -1) {
      throw FormatException('JSON bulunamadı: $text');
    }
    return text.substring(start, end + 1);
  }

  /// Risk profiline göre varsayılan fon seçer
  InvestmentFund _getDefaultFundForRisk(
    RiskProfile risk,
    List<InvestmentFund> funds,
  ) {
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
