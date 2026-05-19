import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Fetches live quote data from Yahoo Finance for a given symbol.
/// Returns a map with keys: 'price' (double) and 'changePercent' (double).
/// Retries up to 2 times with exponential backoff on transient failures.
Future<Map<String, dynamic>> fetchYahooQuote(String symbol) async {
  const maxRetries = 2;
  for (int attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await _fetchOnce(symbol);
    } catch (e) {
      if (attempt == maxRetries) rethrow;
      await Future.delayed(Duration(seconds: 2 << attempt)); // 2s, 4s
    }
  }
  throw Exception('Unreachable');
}

Future<Map<String, dynamic>> _fetchOnce(String symbol) async {
  final url = Uri.parse(
    'https://query1.finance.yahoo.com/v8/finance/chart/$symbol'
    '?interval=1d&range=2d',
  );

  final response = await http
      .get(url, headers: {'User-Agent': 'Mozilla/5.0'})
      .timeout(const Duration(seconds: 10));

  if (response.statusCode != 200) {
    throw Exception('Yahoo Finance HTTP ${response.statusCode} for $symbol');
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final result = body['chart']?['result'] as List?;
  if (result == null || result.isEmpty) {
    throw Exception('No data from Yahoo Finance for $symbol');
  }

  final meta = result[0]['meta'] as Map<String, dynamic>;
  final price = (meta['regularMarketPrice'] as num?)?.toDouble() ?? 0.0;
  final prevCloseRaw =
      meta['chartPreviousClose'] ?? meta['previousClose'] ?? price;
  final prevClose = (prevCloseRaw as num).toDouble();
  final changePercent =
      prevClose != 0 ? ((price - prevClose) / prevClose) * 100 : 0.0;

  return {'price': price, 'changePercent': changePercent};
}

final yahooFinanceProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
      (ref, symbol) => fetchYahooQuote(symbol),
    );
