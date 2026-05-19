import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/asset.dart';
import '../../core/providers.dart';
import '../../core/services/yahoo_finance_service.dart';
import '../../core/services/gemini_service.dart';
import '../../core/utils/money_parser.dart';

// ─── Sabit varlık kataloğu ────────────────────────────────────────────────────
const _kCatalog = [
  {
    'name': 'Altın (Gram)',
    'symbol': 'GC=F',
    'prefix': '₺',
    'colorHex': 0xFFF59E0B,
  },
  {
    'name': 'Döviz (USD/TRY)',
    'symbol': 'TRY=X',
    'prefix': '₺',
    'colorHex': 0xFF22C55E,
  },
  {
    'name': 'Bitcoin',
    'symbol': 'BTC-USD',
    'prefix': '\$',
    'colorHex': 0xFFEF4444,
  },
  {
    'name': 'Ethereum',
    'symbol': 'ETH-USD',
    'prefix': '\$',
    'colorHex': 0xFF8B5CF6,
  },
  {
    'name': 'Borsa İstanbul',
    'symbol': 'XU100.IS',
    'prefix': '₺',
    'colorHex': 0xFF3B82F6,
  },
  {
    'name': 'S&P 500 ETF',
    'symbol': 'SPY',
    'prefix': '\$',
    'colorHex': 0xFF06B6D4,
  },
  {
    'name': 'Gümüş (Gram)',
    'symbol': 'SI=F',
    'prefix': '₺',
    'colorHex': 0xFF94A3B8,
  },
  {
    'name': 'Euro/TRY',
    'symbol': 'EURTRY=X',
    'prefix': '₺',
    'colorHex': 0xFFF97316,
  },
];

const _kBist = [
  {'name': 'Şişe Cam', 'symbol': 'SISE.IS', 'ticker': 'SISE'},
  {'name': 'Garanti Bankası', 'symbol': 'GARAN.IS', 'ticker': 'GARAN'},
  {'name': 'Akbank', 'symbol': 'AKBNK.IS', 'ticker': 'AKBNK'},
  {'name': 'Türk Telekom', 'symbol': 'TTKOM.IS', 'ticker': 'TTKOM'},
  {'name': 'Ereğli Demir', 'symbol': 'EREGL.IS', 'ticker': 'EREGL'},
  {'name': 'Sabancı Holding', 'symbol': 'SAHOL.IS', 'ticker': 'SAHOL'},
  {'name': 'Koç Holding', 'symbol': 'KCHOL.IS', 'ticker': 'KCHOL'},
  {'name': 'BİM', 'symbol': 'BIMAS.IS', 'ticker': 'BIMAS'},
  {'name': 'Arçelik', 'symbol': 'ARCLK.IS', 'ticker': 'ARCLK'},
  {'name': 'THY', 'symbol': 'THYAO.IS', 'ticker': 'THYAO'},
  {'name': 'Yapı Kredi', 'symbol': 'YKBNK.IS', 'ticker': 'YKBNK'},
  {'name': 'İş Bankası', 'symbol': 'ISCTR.IS', 'ticker': 'ISCTR'},
  {'name': 'Ford Otosan', 'symbol': 'FROTO.IS', 'ticker': 'FROTO'},
  {'name': 'Togg', 'symbol': 'TOGG.IS', 'ticker': 'TOGG'},
  {'name': 'Aselsan', 'symbol': 'ASELS.IS', 'ticker': 'ASELS'},
  {'name': 'Enka İnşaat', 'symbol': 'ENKAI.IS', 'ticker': 'ENKAI'},
  {'name': 'Migros', 'symbol': 'MGROS.IS', 'ticker': 'MGROS'},
];

// ─── Providers ─────────────────────────────────────────────────────────────────
final assetsProvider = StateNotifierProvider<AssetsNotifier, List<Asset>>(
  (ref) => AssetsNotifier(),
);

class AssetsNotifier extends StateNotifier<List<Asset>> {
  AssetsNotifier() : super(const []) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('altera_portfolio');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      state = decoded.map((item) => Asset.fromJson(item)).toList();
    }
  }

  Future<void> _saveToStorage(List<Asset> currentAssets) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(currentAssets.map((a) => a.toJson()).toList());
    await prefs.setString('altera_portfolio', encoded);
  }

  void add(Asset asset) {
    state = [...state, asset];
    _saveToStorage(state);
  }

  void remove(Asset asset) {
    state = state.where((a) => a != asset).toList();
    _saveToStorage(state);
  }
}

final isUsdProvider = StateProvider<bool>((ref) => false);
final isLineChartProvider = StateProvider<bool>((ref) => false);

// 🌟 YENİ: Portföyü analiz eden Gemini Ajanı Sağlayıcısı
final portfolioAnalysisProvider = FutureProvider.family<String, List<Asset>>((
  ref,
  assets,
) async {
  if (assets.isEmpty) {
    return 'Portföyünüz şu an boş. Hemen bir varlık ekleyerek enflasyona karşı korunmaya başlayın!';
  }
  try {
    final geminiService = await GeminiService.initialize();
    return await geminiService.analyzePortfolio(assets);
  } on GeminiException catch (e) {
    return 'ALTERA Ajanı şu an portföyü analiz edemiyor: ${e.message}';
  } catch (_) {
    return 'ALTERA Ajanı şu an portföyü analiz edemiyor. Lütfen ayarlardan Gemini API Key tanımlamasını kontrol edin.';
  }
});

// ─── Fiyat Çeviri Motoru ───────────────────────────────────────────────────────
class LivePriceParams {
  final double livePriceTl;
  final String displayPrefix;
  LivePriceParams({required this.livePriceTl, required this.displayPrefix});
}

LivePriceParams _getLiveTlPrice(
  Map<String, dynamic>? rawData,
  String symbol,
  double usdRate,
) {
  if (rawData == null)
    return LivePriceParams(livePriceTl: 0, displayPrefix: '');

  final p = (rawData['price'] as num?)?.toDouble() ?? 0.0;
  double priceTl = p;

  if (symbol == 'GC=F' || symbol == 'SI=F') {
    priceTl = (p / 31.1034768) * usdRate;
  } else if (symbol.contains('-USD') || symbol == 'SPY') {
    priceTl = p * usdRate;
  } else if (symbol == 'TRY=X') {
    priceTl = p;
  }

  return LivePriceParams(livePriceTl: priceTl, displayPrefix: '₺');
}

String _formatCurrency(double amountInTl, bool isUsd, double usdRate) {
  final val = isUsd ? (amountInTl / usdRate) : amountInTl;
  final formatted = val
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
  return isUsd ? '\$$formatted' : '$formatted TL';
}

String _getUnitString(String symbol) {
  if (symbol.contains('.IS') || symbol == 'SPY') return 'Lot';
  if (symbol == 'GC=F' || symbol == 'SI=F') return 'Gram';
  if (symbol.contains('-USD')) return 'Adet';
  return 'Birim';
}

// ─── Ana Ekran ────────────────────────────────────────────────────────────────
class InvestmentsScreen extends ConsumerWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(assetsProvider);
    final isUsd = ref.watch(isUsdProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);

    final tryData = ref.watch(yahooFinanceProvider('TRY=X'));
    final usdRate = (tryData.valueOrNull?['price'] as num?)?.toDouble() ?? 1.0;

    final savings = summaryAsync.valueOrNull?.savings ?? 0.0;
    final totalInvested = assets.fold(0.0, (sum, a) => sum + a.totalCost);
    final available = (savings - totalInvested).clamp(0.0, double.infinity).toDouble();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF16223A), Color(0xFF0A0F1C)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const _AppBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      _ChartSection(
                        assets: assets,
                        isUsd: isUsd,
                        usdRate: usdRate,
                      ),
                      const SizedBox(height: 24),
                      _PortfolioTotal(
                        assets: assets,
                        isUsd: isUsd,
                        usdRate: usdRate,
                      ),
                      const SizedBox(height: 24),
                      const _SavingsCard(),
                      const SizedBox(height: 24),
                      _AiAgentCard(assets: assets),

                      const SizedBox(height: 24),
                      _MarketPulseCard(
                        assets: assets,
                        isUsd: isUsd,
                        usdRate: usdRate,
                      ),

                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            for (final asset in assets) ...[
                              Dismissible(
                                key: Key('${asset.symbol}_${asset.hashCode}'),
                                direction: DismissDirection.endToStart,
                                onDismissed:
                                    (_) => ref
                                        .read(assetsProvider.notifier)
                                        .remove(asset),
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white,
                                  ),
                                ),
                                child: _AssetCard(
                                  asset: asset,
                                  isUsd: isUsd,
                                  usdRate: usdRate,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            _AddAssetButton(
                              available: available,
                              onTap:
                                  () => showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder:
                                        (_) => _AddAssetSheet(
                                          maxAmount:
                                              available > 0 ? available : null,
                                        ),
                                  ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── App Bar ──────────────────────────────────────────────────────────────────
class _AppBar extends ConsumerWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUsd = ref.watch(isUsdProvider);
    final isLineChart = ref.watch(isLineChartProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap:
                () =>
                    ref.read(isLineChartProvider.notifier).state = !isLineChart,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: const BoxDecoration(
                color: Color(0xFF1E2746),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLineChart ? Icons.pie_chart_outline : Icons.show_chart,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => ref.read(isUsdProvider.notifier).state = !isUsd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                isUsd ? 'USD' : 'TRY',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tasarruf Kartı ─────────────────────────────────────────────────────────
class _SavingsCard extends ConsumerWidget {
  const _SavingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(monthlySummaryProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF22C55E).withValues(alpha: 0.12),
              const Color(0xFF1E2746).withValues(alpha: 0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.25)),
        ),
        child: summaryAsync.when(
          loading:
              () => const SizedBox(
                height: 48,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF22C55E),
                  ),
                ),
              ),
          error:
              (_, __) => const Text(
                'Tasarruf bilgisi yüklenemedi',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
              ),
          data: (summary) {
            final savings = summary.savings;
            final totalInvested = ref
                .watch(assetsProvider)
                .fold(0.0, (sum, a) => sum + a.totalCost);
            final available = (savings - totalInvested).clamp(
              0.0,
              double.infinity,
            ).toDouble();
            final hasSavings = savings > 0;
            final hasAvailable = available > 0;

            String fmt(double v) => v
                .abs()
                .toStringAsFixed(0)
                .replaceAllMapped(
                  RegExp(r'(\d)(?=(\d{3})+$)'),
                  (m) => '${m[1]}.',
                );

            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (hasSavings
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444))
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.savings_outlined,
                    color:
                        hasSavings
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BU AYKİ TASARRUF',
                        style: TextStyle(
                          color: Color(0xFF8B95A5),
                          fontSize: 10,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${hasSavings ? '' : '-'}₺${fmt(savings)}',
                        style: TextStyle(
                          color:
                              hasSavings
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFEF4444),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (totalInvested > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Portföyde: ₺${fmt(totalInvested)}  •  Kalan: ₺${fmt(available)}',
                          style: TextStyle(
                            color:
                                hasAvailable
                                    ? const Color(0xFF8B95A5)
                                    : const Color(0xFFEF4444),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasAvailable)
                  GestureDetector(
                    onTap:
                        () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _AddAssetSheet(maxAmount: available),
                        ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: Colors.white,
                            size: 15,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Yatır',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (hasSavings)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Tümü yatırıldı',
                      style: TextStyle(color: Color(0xFF8B95A5), fontSize: 11),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Tasarruf yok',
                      style: TextStyle(color: Color(0xFF8B95A5), fontSize: 11),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Gemini Yapay Zekâ Kartı Bileşeni ──────────────────────────────────────────
class _AiAgentCard extends ConsumerStatefulWidget {
  final List<Asset> assets;
  const _AiAgentCard({required this.assets});

  @override
  ConsumerState<_AiAgentCard> createState() => _AiAgentCardState();
}

class _AiAgentCardState extends ConsumerState<_AiAgentCard> {
  /// Bir kez hesaplanmış bağlam — canlı fiyatlar yüklenince set edilir.
  String? _contextKey;
  bool _autoTriggered = false;

  /// Portföydeki her varlık için canlı fiyat + P&L bağlamı oluşturur.
  String _buildContext(
    List<Asset> assets,
    Map<String, Map<String, dynamic>?> liveMap,
    double usdRate,
  ) {
    final buf = StringBuffer();
    double totalCostTl = 0;
    double totalCurrentTl = 0;
    double totalDailyDeltaTl = 0;

    for (final a in assets) {
      final data = liveMap[a.symbol];
      if (data == null) continue;

      // price kullanılmıyor; livePriceTl hesabı _getLiveTlPrice üzerinden yapılıyor
      final changePct = (data['changePercent'] as num?)?.toDouble() ?? 0.0;
      final livePriceTl = _getLiveTlPrice(data, a.symbol, usdRate).livePriceTl;
      final currentValTl = a.units * livePriceTl;
      final profitTl = currentValTl - a.totalCost;
      final profitPct = a.totalCost > 0 ? (profitTl / a.totalCost) * 100 : 0.0;
      final prevValTl = currentValTl / (1 + changePct / 100);
      final dailyDeltaTl = currentValTl - prevValTl;

      totalCostTl += a.totalCost;
      totalCurrentTl += currentValTl;
      totalDailyDeltaTl += dailyDeltaTl;

      final profitSign = profitTl >= 0 ? '+' : '';
      final dailySign = dailyDeltaTl >= 0 ? '+' : '';

      buf.writeln(
        '• ${a.name}: '
        'maliyet ₺${a.totalCost.toStringAsFixed(0)}, '
        'güncel ₺${currentValTl.toStringAsFixed(0)} '
        '($profitSign₺${profitTl.toStringAsFixed(0)}, $profitSign${profitPct.toStringAsFixed(1)}% toplam kâr/zarar), '
        'bugün $dailySign₺${dailyDeltaTl.toStringAsFixed(0)} ($dailySign${changePct.toStringAsFixed(2)}%)',
      );
    }

    final totalProfitTl = totalCurrentTl - totalCostTl;
    final totalDailySign = totalDailyDeltaTl >= 0 ? '+' : '';
    buf.writeln(
      '\nTOPLAM: maliyet ₺${totalCostTl.toStringAsFixed(0)}, '
      'güncel ₺${totalCurrentTl.toStringAsFixed(0)}, '
      'toplam kâr/zarar ${totalProfitTl >= 0 ? '+' : ''}₺${totalProfitTl.toStringAsFixed(0)}, '
      'bugün $totalDailySign₺${totalDailyDeltaTl.toStringAsFixed(0)}',
    );

    return buf.toString();
  }

  void _refresh(String ctx) {
    ref.invalidate(portfolioInsightsProvider(ctx));
    setState(() => _contextKey = ctx);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assets.isEmpty) return const SizedBox.shrink();

    final usdRate =
        (ref.watch(yahooFinanceProvider('TRY=X')).valueOrNull?['price'] as num?)
            ?.toDouble() ??
        1.0;

    // Tüm portföy sembollerinin canlı verilerini topla
    final liveMap = <String, Map<String, dynamic>?>{};
    bool anyLoading = false;
    for (final a in widget.assets) {
      final async = ref.watch(yahooFinanceProvider(a.symbol));
      liveMap[a.symbol] = async.valueOrNull;
      if (async.isLoading) anyLoading = true;
    }

    // Veriler ilk yüklendiğinde otomatik tetikle (bir kez)
    if (!anyLoading &&
        !_autoTriggered &&
        liveMap.values.any((v) => v != null)) {
      _autoTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _contextKey = _buildContext(widget.assets, liveMap, usdRate);
        });
      });
    }

    final insightsAsync =
        _contextKey != null
            ? ref.watch(portfolioInsightsProvider(_contextKey!))
            : null;

    final isLoading =
        anyLoading || insightsAsync == null || insightsAsync.isLoading;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF3B82F6).withValues(alpha: 0.12),
              const Color(0xFF1E2746).withValues(alpha: 0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Başlık ──
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF3B82F6),
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ALTERA · AL / SAT / TUT ÖNERİLERİ',
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFF3B82F6),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () {
                      final ctx = _buildContext(
                        widget.assets,
                        liveMap,
                        usdRate,
                      );
                      _refresh(ctx);
                    },
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF3B82F6),
                      size: 16,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── İçerik ──
            if (anyLoading && _contextKey == null)
              const Text(
                'Canlı fiyatlar yükleniyor, analiz hazırlanıyor...',
                style: TextStyle(
                  color: Color(0xFF8B95A5),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              )
            else if (insightsAsync == null)
              const Text(
                'Canlı veriler bekleniyor...',
                style: TextStyle(color: Color(0xFF8B95A5), fontSize: 12),
              )
            else
              insightsAsync.when(
                loading:
                    () => const Text(
                      'Ajan portföyünüzü inceliyor...',
                      style: TextStyle(
                        color: Color(0xFF8B95A5),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                error:
                    (err, _) => Text(
                      'Analiz yüklenemedi: $err',
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                      ),
                    ),
                data:
                    (insight) => Text(
                      insight,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.55,
                      ),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Dinamik Grafik Alanı ────────────────────────────────────────────────────
class _ChartSection extends ConsumerWidget {
  final List<Asset> assets;
  final bool isUsd;
  final double usdRate;

  const _ChartSection({
    required this.assets,
    required this.isUsd,
    required this.usdRate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLineChart = ref.watch(isLineChartProvider);

    double totalCurrentValueTl = 0.0;
    double totalDailyChangeTl = 0.0;
    bool isCalculating = false;

    for (final asset in assets) {
      if (asset.units > 0) {
        final liveData = ref.watch(yahooFinanceProvider(asset.symbol));
        liveData.whenData((data) {
          final livePriceTl =
              _getLiveTlPrice(data, asset.symbol, usdRate).livePriceTl;
          final changePct = (data['changePercent'] as num?)?.toDouble() ?? 0.0;

          final currentValueTl = asset.units * livePriceTl;

          final previousTotalValueTl = currentValueTl / (1 + (changePct / 100));
          final dailyChangeTl = currentValueTl - previousTotalValueTl;

          totalCurrentValueTl += currentValueTl;
          totalDailyChangeTl += dailyChangeTl;
        });
        if (liveData.isLoading) isCalculating = true;
      }
    }

    final previousTotalTl = totalCurrentValueTl - totalDailyChangeTl;
    final dailyProfitPct =
        previousTotalTl > 0
            ? (totalDailyChangeTl / previousTotalTl) * 100
            : 0.0;

    final gainSign = totalDailyChangeTl >= 0 ? '+' : '';
    final gainColor =
        totalDailyChangeTl >= 0
            ? const Color(0xFF22C55E)
            : const Color(0xFFEF4444);

    final displayGainAmt =
        isUsd ? (totalDailyChangeTl / usdRate) : totalDailyChangeTl;
    final currencySymbol = isUsd ? '\$' : '₺';

    final slices =
        totalCurrentValueTl == 0
            ? <_Slice>[]
            : assets.where((a) => a.units > 0).map((a) {
              final liveData =
                  ref.watch(yahooFinanceProvider(a.symbol)).valueOrNull;
              final livePriceTl =
                  _getLiveTlPrice(liveData, a.symbol, usdRate).livePriceTl;
              final currentValueTl = a.units * livePriceTl;
              return _Slice(
                a.color,
                currentValueTl / totalCurrentValueTl,
                a.name,
              );
            }).toList();

    return SizedBox(
      height: 240,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child:
                isLineChart
                    ? SizedBox(
                      key: const ValueKey('Line'),
                      width: 250,
                      height: 160,
                      child: CustomPaint(
                        painter: _TrendLinePainter(
                          isProfit: totalDailyChangeTl >= 0,
                        ),
                      ),
                    )
                    : SizedBox(
                      key: const ValueKey('Donut'),
                      width: double.infinity,
                      height: double.infinity,
                      child: CustomPaint(painter: _DonutPainter(slices)),
                    ),
          ),

          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: isLineChart ? Colors.transparent : const Color(0xFF0A0F1C),
              shape: BoxShape.circle,
            ),
            child: Center(
              child:
                  isCalculating && totalCurrentValueTl == 0
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white54,
                        ),
                      )
                      : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$gainSign${dailyProfitPct.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: gainColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$gainSign${displayGainAmt.toStringAsFixed(0)} $currencySymbol',
                            style: TextStyle(
                              color: gainColor.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!isLineChart) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'GÜNLÜK',
                              style: TextStyle(
                                color: Color(0xFF8B95A5),
                                fontSize: 8,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  final bool isProfit;
  _TrendLinePainter({required this.isProfit});

  @override
  void paint(Canvas canvas, Size size) {
    final themeColor =
        isProfit ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    final paint =
        Paint()
          ..color = themeColor
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final fillPaint =
        Paint()
          ..shader = LinearGradient(
            colors: [themeColor.withValues(alpha: 0.3), Colors.transparent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTRB(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill;

    final path = Path();
    final points =
        isProfit
            ? [0.7, 0.8, 0.6, 0.5, 0.4, 0.45, 0.2]
            : [0.2, 0.3, 0.25, 0.5, 0.4, 0.6, 0.8];

    final stepX = size.width / (points.length - 1);

    path.moveTo(0, size.height * points[0]);
    for (int i = 0; i < points.length - 1; i++) {
      final x1 = stepX * i;
      final y1 = size.height * points[i];
      final x2 = stepX * (i + 1);
      final y2 = size.height * points[i + 1];

      final controlPointX = x1 + (x2 - x1) / 2;
      path.cubicTo(controlPointX, y1, controlPointX, y2, x2, y2);
    }

    final fillPath =
        Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrendLinePainter oldDelegate) =>
      oldDelegate.isProfit != isProfit;
}

class _Slice {
  final Color color;
  final double ratio;
  final String label;
  const _Slice(this.color, this.ratio, this.label);
}

class _DonutPainter extends CustomPainter {
  final List<_Slice> slices;
  const _DonutPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 65.0;
    const strokeWidth = 24.0;

    final arcPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;
    final linePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    if (slices.isEmpty) {
      arcPaint.color = Colors.white.withValues(alpha: 0.05);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        0,
        2 * pi,
        false,
        arcPaint,
      );
      return;
    }

    double startAngle = -pi / 2;
    for (final s in slices) {
      final sweepAngle = s.ratio * 2 * pi;
      arcPaint.color = s.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
      startAngle += sweepAngle;
    }

    startAngle = -pi / 2;
    for (final s in slices) {
      final sweepAngle = s.ratio * 2 * pi;
      final midAngle = startAngle + sweepAngle / 2;

      final outerRadius = radius + strokeWidth / 2;
      final startX = center.dx + cos(midAngle) * outerRadius;
      final startY = center.dy + sin(midAngle) * outerRadius;

      final breakPointX = center.dx + cos(midAngle) * (outerRadius + 20);
      final breakPointY = center.dy + sin(midAngle) * (outerRadius + 20);

      final isRightSide = cos(midAngle) >= 0;
      final endLineX = breakPointX + (isRightSide ? 25 : -25);

      canvas.drawLine(
        Offset(startX, startY),
        Offset(breakPointX, breakPointY),
        linePaint,
      );
      canvas.drawLine(
        Offset(breakPointX, breakPointY),
        Offset(endLineX, breakPointY),
        linePaint,
      );

      final textSpan = TextSpan(
        text:
            '%${(s.ratio * 100).toStringAsFixed(1)} ${s.label.replaceAll('(Gram)', '').trim()}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final textX =
          isRightSide ? endLineX + 6 : endLineX - textPainter.width - 6;
      final textY = breakPointY - textPainter.height / 2;

      textPainter.paint(canvas, Offset(textX, textY));
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) => true;
}

// ─── Portföy Toplamı ─────────────────────────────────────────────────────────
class _PortfolioTotal extends ConsumerWidget {
  final List<Asset> assets;
  final bool isUsd;
  final double usdRate;

  const _PortfolioTotal({
    required this.assets,
    required this.isUsd,
    required this.usdRate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    double totalCurrentValueTl = 0.0;

    for (final asset in assets) {
      if (asset.units > 0) {
        final liveData =
            ref.watch(yahooFinanceProvider(asset.symbol)).valueOrNull;
        final livePriceTl =
            _getLiveTlPrice(liveData, asset.symbol, usdRate).livePriceTl;
        totalCurrentValueTl += (asset.units * livePriceTl);
      }
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chevron_left, color: Color(0xFF8B95A5), size: 18),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2746).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Text(
                    'GELECEĞİNİZ İÇİN',
                    style: TextStyle(
                      color: Color(0xFF8B95A5),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.emoji_events_outlined,
                    color: Color(0xFF8B95A5),
                    size: 13,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF8B95A5), size: 18),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _formatCurrency(totalCurrentValueTl, isUsd, usdRate),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E2746)),
          ),
          child: const Text(
            'PORTFÖY DEĞERİ',
            style: TextStyle(
              color: Color(0xFF8B95A5),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Varlık Kartı ─────────────────────────────────────────────────────────────
class _AssetCard extends ConsumerWidget {
  final Asset asset;
  final bool isUsd;
  final double usdRate;

  const _AssetCard({
    required this.asset,
    required this.isUsd,
    required this.usdRate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(yahooFinanceProvider(asset.symbol));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2746),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: asset.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (asset.units > 0)
                  Text(
                    '${asset.units.toStringAsFixed(asset.symbol.contains('GC') ? 2 : 0)} ${_getUnitString(asset.symbol)}',
                    style: const TextStyle(
                      color: Color(0xFF8B95A5),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),

          live.when(
            loading:
                () => const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white54,
                  ),
                ),
            error:
                (_, __) => const Text(
                  '—',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
            data: (data) {
              final livePriceTl =
                  _getLiveTlPrice(data, asset.symbol, usdRate).livePriceTl;

              final currentValueTl = asset.units * livePriceTl;
              final profitTl = currentValueTl - asset.totalCost;
              final profitPct =
                  asset.totalCost > 0
                      ? (profitTl / asset.totalCost) * 100
                      : 0.0;

              final isUp = profitTl >= 0;
              final clr =
                  isUp ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

              final displayValue =
                  isUsd ? (currentValueTl / usdRate) : currentValueTl;
              final displayProfit = isUsd ? (profitTl / usdRate) : profitTl;
              final currencyPrefix = isUsd ? '\$' : '₺';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(
                        '$currencyPrefix${displayValue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: clr,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isUp
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${isUp ? '+' : ''}${displayProfit.toStringAsFixed(2)}  %${profitPct.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: clr,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Varlık Ekle Butonu ───────────────────────────────────────────────────────
class _AddAssetButton extends StatelessWidget {
  final VoidCallback onTap;
  final double available;
  const _AddAssetButton({required this.onTap, required this.available});

  @override
  Widget build(BuildContext context) {
    final hasLimit = available <= 0;
    return GestureDetector(
      onTap: hasLimit ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2746).withValues(alpha: hasLimit ? 0.3 : 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasLimit ? Icons.block : Icons.add_circle_outline,
                  color:
                      hasLimit
                          ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                          : const Color(0xFF8B95A5),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Varlık Ekle',
                  style: TextStyle(
                    color:
                        hasLimit
                            ? const Color(0xFF8B95A5).withValues(alpha: 0.5)
                            : const Color(0xFF8B95A5),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (hasLimit) ...[
              const SizedBox(height: 4),
              const Text(
                'Tasarruf limitine ulaşıldı',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Piyasa Nabzı Kartı ───────────────────────────────────────────────────────
/// Portföydeki varlıkların günlük fiyat değişimini feed olarak gösterir.
/// Portföy boşsa sabit izleme listesindeki (USD, Altın, BIST) verileri gösterir.
class _MarketPulseCard extends ConsumerWidget {
  final List<Asset> assets;
  final bool isUsd;
  final double usdRate;

  // Portföyde olmasa bile her zaman gösterilecek piyasa göstergeleri
  static const _watchlist = [
    {'symbol': 'TRY=X', 'name': 'Dolar / TL', 'colorHex': 0xFF22C55E},
    {'symbol': 'GC=F', 'name': 'Altın (gram)', 'colorHex': 0xFFF59E0B},
    {'symbol': 'XU100.IS', 'name': 'BIST 100', 'colorHex': 0xFF3B82F6},
  ];

  const _MarketPulseCard({
    required this.assets,
    required this.isUsd,
    required this.usdRate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Portföydeki semboller
    final portfolioSymbols = assets.map((a) => a.symbol).toSet();

    // İzleme listesinden portföyde olmayanları ekle
    final watchEntries =
        _watchlist
            .where((w) => !portfolioSymbols.contains(w['symbol']))
            .toList();

    final hasContent = assets.isNotEmpty || watchEntries.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2746),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Başlık ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.bar_chart_rounded,
                    color: Color(0xFF8B95A5),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'PİYASA NABZI',
                    style: TextStyle(
                      color: Color(0xFF8B95A5),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Günlük  •  $timeStr',
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Divider(color: Color(0xFF0D1426), height: 1),
            const SizedBox(height: 4),

            if (!hasContent)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Portföyünüze varlık ekleyin',
                    style: TextStyle(color: Color(0xFF4B5563), fontSize: 13),
                  ),
                ),
              )
            else ...[
              // ── Portföy varlıkları ──
              for (final asset in assets)
                _PulseRow(
                  symbol: asset.symbol,
                  name: asset.name,
                  color: asset.color,
                  positionUnits: asset.units,
                  positionCostTl: asset.totalCost,
                  usdRate: usdRate,
                  isUsd: isUsd,
                  isLast: asset == assets.last && watchEntries.isEmpty,
                ),

              // ── Sabit izleme listesi ──
              if (watchEntries.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: Color(0xFF0D1426), height: 16),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    'PIYASA GÖSTERGELERİ',
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                for (var i = 0; i < watchEntries.length; i++)
                  _PulseRow(
                    symbol: watchEntries[i]['symbol'] as String,
                    name: watchEntries[i]['name'] as String,
                    color: Color(watchEntries[i]['colorHex'] as int),
                    positionUnits: 0,
                    positionCostTl: 0,
                    usdRate: usdRate,
                    isUsd: isUsd,
                    isLast: i == watchEntries.length - 1,
                  ),
              ],
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _PulseRow extends ConsumerWidget {
  final String symbol;
  final String name;
  final Color color;
  final double positionUnits; // 0 → izleme listesi (pozisyon yok)
  final double positionCostTl;
  final double usdRate;
  final bool isUsd;
  final bool isLast;

  const _PulseRow({
    required this.symbol,
    required this.name,
    required this.color,
    required this.positionUnits,
    required this.positionCostTl,
    required this.usdRate,
    required this.isUsd,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAsync = ref.watch(yahooFinanceProvider(symbol));

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, isLast ? 0 : 0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                // Renk noktası
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),

                // Varlık adı
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Canlı veri
                liveAsync.when(
                  loading:
                      () => const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.2,
                          color: Colors.white24,
                        ),
                      ),
                  error:
                      (_, __) => const Text(
                        'Veri yok',
                        style: TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 11,
                        ),
                      ),
                  data: (data) {
                    final changePct =
                        (data['changePercent'] as num?)?.toDouble() ?? 0.0;
                    // price doğrudan kullanılmıyor; changePct rozet için yeterli
                    final isUp = changePct >= 0;
                    final clr =
                        isUp
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444);
                    final sign = isUp ? '+' : '';

                    // Pozisyon varsa günlük kazanç/kayıp hesapla
                    String? positionLine;
                    if (positionUnits > 0) {
                      final livePriceTl =
                          _getLiveTlPrice(data, symbol, usdRate).livePriceTl;
                      final currentValTl = positionUnits * livePriceTl;
                      final previousValTl =
                          currentValTl / (1 + changePct / 100);
                      final dailyDeltaTl = currentValTl - previousValTl;
                      final displayDelta =
                          isUsd ? (dailyDeltaTl / usdRate) : dailyDeltaTl;
                      final prefix = isUsd ? '\$' : '₺';
                      final deltaSign = dailyDeltaTl >= 0 ? '+' : '';
                      positionLine =
                          '$deltaSign$prefix${displayDelta.toStringAsFixed(0)} bugün';
                    }

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (positionLine != null) ...[
                          Text(
                            positionLine,
                            style: TextStyle(
                              color:
                                  isUp
                                      ? const Color(0xFF22C55E)
                                      : const Color(0xFFEF4444),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // % değişim rozeti
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: clr.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isUp
                                    ? Icons.arrow_drop_up
                                    : Icons.arrow_drop_down,
                                color: clr,
                                size: 14,
                              ),
                              Text(
                                '$sign${changePct.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  color: clr,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          if (!isLast) const Divider(color: Color(0xFF0D1426), height: 1),
        ],
      ),
    );
  }
}

// ─── Bottom Sheet ─────────────────────────────────────────────────────────────
class _AddAssetSheet extends ConsumerStatefulWidget {
  final double? maxAmount;
  const _AddAssetSheet({this.maxAmount});

  @override
  ConsumerState<_AddAssetSheet> createState() => _AddAssetSheetState();
}

class _AddAssetSheetState extends ConsumerState<_AddAssetSheet> {
  final _searchCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _query = '';
  Map<String, dynamic>? _chosen;
  bool _step2 = false;

  bool _isLotMode = false;

  List<Map<String, dynamic>> get _all => [
    ..._kCatalog.map(
      (e) => {
        'name': e['name'],
        'symbol': e['symbol'],
        'prefix': e['prefix'],
        'colorHex': e['colorHex'],
        'ticker': '',
      },
    ),
    ..._kBist.map(
      (e) => {
        'name': e['name'],
        'symbol': e['symbol'],
        'prefix': '₺',
        'colorHex': 0xFF3B82F6,
        'ticker': e['ticker'],
      },
    ),
  ];

  List<Map<String, dynamic>> get _filtered {
    final q = _query.toUpperCase().trim();
    if (q.isEmpty) return _all;

    final matches =
        _all.where((e) {
          return (e['name'] as String).toUpperCase().contains(q) ||
              (e['symbol'] as String).toUpperCase().contains(q) ||
              (e['ticker'] as String).toUpperCase().contains(q);
        }).toList();

    if (matches.isEmpty && q.isNotEmpty) {
      matches.add({
        'name': '$q Hissesi',
        'symbol': '$q.IS',
        'prefix': '₺',
        'colorHex': 0xFF3B82F6,
        'ticker': q,
      });
    }

    return matches;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E2746),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                if (_step2)
                  GestureDetector(
                    onTap:
                        () => setState(() {
                          _step2 = false;
                          _chosen = null;
                          _amountCtrl.clear();
                        }),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white54,
                        size: 18,
                      ),
                    ),
                  ),
                Text(
                  _step2 ? 'Değer Girin' : 'Varlık Ekle',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (!_step2) ...[
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Ara: Altın, SASA, THYAO...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF8B95A5),
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF8B95A5),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0D1426),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _filtered.length,
                  separatorBuilder:
                      (_, __) =>
                          const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (_, i) {
                    final item = _filtered[i];
                    final color = Color(item['colorHex'] as int);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        item['name'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        item['symbol'] as String,
                        style: const TextStyle(
                          color: Color(0xFF8B95A5),
                          fontSize: 11,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.white24,
                        size: 18,
                      ),
                      onTap:
                          () => setState(() {
                            _chosen = item;
                            _step2 = true;
                            if (widget.maxAmount != null &&
                                widget.maxAmount! > 0) {
                              _amountCtrl.text = widget.maxAmount!
                                  .toStringAsFixed(0);
                            }
                          }),
                    );
                  },
                ),
              ),
            ] else ...[
              _buildStep2Input(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Input() {
    final tryData = ref.watch(yahooFinanceProvider('TRY=X'));
    final usdRate = (tryData.valueOrNull?['price'] as num?)?.toDouble() ?? 1.0;
    final liveDataAsync = ref.watch(yahooFinanceProvider(_chosen!['symbol']));

    final unitStr = _getUnitString(_chosen!['symbol']);

    return liveDataAsync.when(
      loading:
          () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          ),
      error:
          (_, __) => const Center(
            child: Text(
              'Fiyat alınamadı.',
              style: TextStyle(color: Colors.red),
            ),
          ),
      data: (data) {
        final livePriceTl =
            _getLiveTlPrice(data, _chosen!['symbol'], usdRate).livePriceTl;
        final inputVal = parseMoneyAmount(_amountCtrl.text) ?? 0.0;
        final tlEquivalent = _isLotMode ? inputVal * livePriceTl : inputVal;
        final maxAmount = widget.maxAmount;
        final isOverLimit =
            maxAmount != null && inputVal > 0 && tlEquivalent > maxAmount;

        String previewText = '';
        if (inputVal > 0) {
          if (_isLotMode) {
            previewText =
                '≈ Maliyet: ${_formatCurrency(inputVal * livePriceTl, false, 1.0)}';
          } else {
            previewText =
                '≈ ${(inputVal / (livePriceTl > 0 ? livePriceTl : 1)).toStringAsFixed(4)} $unitStr';
          }
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1426),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(_chosen!['colorHex'] as int),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _chosen!['name'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _chosen!['symbol'] as String,
                          style: const TextStyle(
                            color: Color(0xFF8B95A5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Anlık Fiyat',
                        style: TextStyle(
                          color: Color(0xFF8B95A5),
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        '₺${livePriceTl.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1426),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isLotMode = false;
                          _amountCtrl.clear();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color:
                              !_isLotMode
                                  ? const Color(0xFF1E2746)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Tutar (TL)',
                            style: TextStyle(
                              color:
                                  !_isLotMode ? Colors.white : Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isLotMode = true;
                          _amountCtrl.clear();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color:
                              _isLotMode
                                  ? const Color(0xFF1E2746)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Miktar ($unitStr)',
                            style: TextStyle(
                              color: _isLotMode ? Colors.white : Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _amountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: const TextStyle(
                  color: Color(0xFF8B95A5),
                  fontSize: 28,
                ),
                prefixText: !_isLotMode ? '₺ ' : '',
                suffixText: _isLotMode ? ' $unitStr' : '',
                prefixStyle: const TextStyle(
                  color: Color(0xFF8B95A5),
                  fontSize: 20,
                ),
                suffixStyle: const TextStyle(
                  color: Color(0xFF8B95A5),
                  fontSize: 16,
                ),
                filled: true,
                fillColor: const Color(0xFF0D1426),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
            const SizedBox(height: 8),

            if (maxAmount != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Yatırılabilir limit: ₺${maxAmount.toStringAsFixed(0)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF8B95A5),
                    fontSize: 11,
                  ),
                ),
              ),

            Center(
              child: Text(
                isOverLimit
                    ? '⚠️ Tasarruf limitini (₺${maxAmount.toStringAsFixed(0)}) aşıyorsunuz!'
                    : previewText.isEmpty
                    ? 'Eklemek istediğiniz değeri girin'
                    : previewText,
                style: TextStyle(
                  color:
                      isOverLimit
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF22C55E),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    inputVal > 0 && !isOverLimit
                        ? () => _add(livePriceTl)
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  disabledBackgroundColor: Colors.white10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Portföye Ekle',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _add(double livePriceTl) {
    final inputVal = parseMoneyAmount(_amountCtrl.text) ?? 0.0;
    if (inputVal <= 0 || _chosen == null) return;

    double finalUnits = 0;
    double finalCostTl = 0;

    if (_isLotMode) {
      finalUnits = inputVal;
      finalCostTl = inputVal * livePriceTl;
    } else {
      finalCostTl = inputVal;
      finalUnits = inputVal / (livePriceTl > 0 ? livePriceTl : 1);
    }

    ref
        .read(assetsProvider.notifier)
        .add(
          Asset(
            name: _chosen!['name'] as String,
            symbol: _chosen!['symbol'] as String,
            prefix: _chosen!['prefix'] as String,
            color: Color(_chosen!['colorHex'] as int),
            units: finalUnits,
            totalCost: finalCostTl,
          ),
        );
    Navigator.pop(context);
  }
}
