// ALTERA Gemini 2.0 Flash servis katmanı - tüm AI çağrıları burada
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../constants/app_constants.dart';
import '../models/transaction.dart';
import '../models/investment_fund.dart';
import '../models/user_profile.dart';

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
/// Hata yönetimi: API hatalarında GeminiException fırlatır.
///
/// Kullanım:
/// ```dart
/// final gemini = await GeminiService.initialize();
/// final analysis = await gemini.analyzeTransaction(tx);
/// ```
class GeminiService {
  final GenerativeModel _model;

  GeminiService._(String apiKey)
      : _model = GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            maxOutputTokens: AppConstants.kGeminiMaxTokens,
            temperature: 0.1, // Düşük temperature - tutarlı JSON çıktısı için
          ),
        );

  /// flutter_secure_storage'dan API key okuyarak modeli başlatır
  static Future<GeminiService> initialize() async {
    const storage = FlutterSecureStorage();
    final apiKey = await storage.read(key: AppConstants.kSecureKeyGeminiApiKey);
    if (apiKey == null || apiKey.isEmpty) {
      throw const GeminiException('Gemini API key bulunamadı. Lütfen ayarlardan API key girin.');
    }
    return GeminiService._(apiKey);
  }

  /// Test amaçlı doğrudan API key ile oluşturur
  factory GeminiService.withKey(String apiKey) => GeminiService._(apiKey);

  /// Tek bir işlemi analiz eder - kategori, tür ve gerekçe döndürür.
  ///
  /// [tx] Analiz edilecek işlem
  /// Throws: GeminiException - API hatası veya geçersiz yanıt
  Future<TransactionAnalysis> analyzeTransaction(Transaction tx) async {
    final stopwatch = Stopwatch()..start();

    final prompt = '''
Sen ALTERA kişisel finans asistanısın. Aşağıdaki banka işlemini analiz et.

İşlem: ${tx.description}
Tutar: ${tx.amount.abs().toStringAsFixed(2)} TL
Tarih: ${tx.date.day}.${tx.date.month}.${tx.date.year}
${tx.amount > 0 ? 'Tür: Gelir' : 'Tür: Gider'}

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
        final response = await _model.generateContent([Content.text(prompt)]);
        responseText = response.text;
        break;
      } catch (e) {
        final errStr = e.toString();
        if (attempt == AppConstants.kGeminiMaxRetries - 1) {
          throw GeminiException(_summarizeError(errStr));
        }
        // API'nin belirttiği retry süresini parse et; yoksa varsayılan bekle
        final delayMs = _retryDelayMs(errStr);
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
        category: TransactionCategory.values.byName(
          data['category'] as String? ?? 'other',
        ),
        type: TransactionType.values.byName(
          data['type'] as String? ?? 'need',
        ),
        reason: data['reason'] as String? ?? '',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      throw GeminiException('Yanıt parse hatası: $responseText');
    }
  }

  /// Kullanıcının aylık harcamalarını analiz eder ve yatırım önerisi üretir.
  ///
  /// [spending] Kategori bazlı aylık harcamalar
  /// [riskProfile] Kullanıcının risk tercihi
  /// [savingsAmount] Ay sonu kalan tasarruf miktarı
  /// [funds] Mevcut yatırım fonları listesi
  Future<InvestmentRecommendation> analyzeAndRecommendInvestment({
    required Map<TransactionCategory, double> spending,
    required RiskProfile riskProfile,
    required double savingsAmount,
    required List<InvestmentFund> funds,
  }) async {
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
      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';
      final json = _extractJson(responseText);
      final data = jsonDecode(json) as Map<String, dynamic>;

      return InvestmentRecommendation(
        fundId: data['fund_id'] as String? ?? funds.first.id,
        fundName: data['fund_name'] as String? ?? funds.first.name,
        reasoning: data['reasoning'] as String? ?? 'Risk profilinize uygun seçim',
        suggestedAmount: (data['suggested_amount'] as num?)?.toDouble() ?? savingsAmount * 0.8,
      );
    } catch (e) {
      // Hata durumunda risk profiline göre varsayılan öneri
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
  ///
  /// [category] Aşılan bütçe kategorisi
  /// [overspentAmount] Aşım tutarı (TL)
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
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ??
          'Bu ay bütçeni aştın. Harcamalarını gözden geçirmeyi dene.';
    } catch (_) {
      return 'Bu ay ${category.displayNameTr} bütçeni aştın. Harcamalarını gözden geçirmeyi dene.';
    }
  }

  /// E-fatura metninden işlem verisi çıkarır.
  ///
  /// [invoiceText] E-posta veya metin içeriği
  Future<Map<String, dynamic>?> parseInvoice(String invoiceText) async {
    final prompt = '''
Aşağıdaki fatura/e-posta metninden işlem bilgilerini çıkar.

Metin:
$invoiceText

SADECE geçerli JSON döndür (bulamazsan null döndür):
{"description": "...", "amount": 0.0, "date": "YYYY-MM-DD"}
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';
      if (responseText.contains('null')) return null;
      final json = _extractJson(responseText);
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Hata mesajından "retry in X.Xs" süresini parse eder (ms cinsinden).
  static int _retryDelayMs(String error) {
    final match = RegExp(r'retry in (\d+\.?\d*)').firstMatch(error);
    if (match != null) {
      final seconds = double.tryParse(match.group(1) ?? '') ?? 10.0;
      return ((seconds + 2) * 1000).toInt(); // 2s buffer
    }
    return AppConstants.kRateLimitDelayMs;
  }

  /// Uzun API hata metnini kısa, Türkçe özete dönüştürür.
  static String _summarizeError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('quota') ||
        lower.contains('exceeded') ||
        lower.contains('limit')) {
      final retryMatch = RegExp(r'retry in (\d+\.?\d*)').firstMatch(raw);
      if (retryMatch != null) {
        return 'Gemini kota aşıldı (${retryMatch.group(1)}s sonra tekrar dene)';
      }
      return 'Gemini API kota sınırı aşıldı';
    }
    if (lower.contains('api key') || lower.contains('invalid key')) {
      return 'Gemini API anahtarı geçersiz';
    }
    if (lower.contains('network') || lower.contains('socket')) {
      return 'Ağ bağlantısı hatası';
    }
    // URL'leri temizle ve metni kısalt
    final cleaned = raw
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.length > 100 ? '${cleaned.substring(0, 100)}...' : cleaned;
  }

  /// JSON yanıtından { } bloğunu çıkarır - bazen Gemini ekstra metin ekler
  String _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1) throw FormatException('JSON bulunamadı: $text');
    return text.substring(start, end + 1);
  }

  /// Risk profiline göre varsayılan fon seçer
  InvestmentFund _getDefaultFundForRisk(
      RiskProfile risk, List<InvestmentFund> funds) {
    return switch (risk) {
      RiskProfile.conservative =>
        funds.firstWhere((f) => f.riskLevel == RiskLevel.low, orElse: () => funds.first),
      RiskProfile.balanced =>
        funds.firstWhere((f) => f.riskLevel == RiskLevel.medium, orElse: () => funds.first),
      RiskProfile.aggressive =>
        funds.firstWhere((f) => f.riskLevel == RiskLevel.high, orElse: () => funds.first),
    };
  }
}
