import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Fetches live quote data from Yahoo Finance for a given symbol.
/// Returns a map with keys: 'price' (double) and 'changePercent' (double).
Future<Map<String, dynamic>> fetchYahooQuote(String symbol) async {
  final url = Uri.parse(
    'https://query1.finance.yahoo.com/v8/finance/chart/$symbol'
    '?interval=1d&range=2d',
  );

  final response = await http.get(url, headers: {
    'User-Agent': 'Mozilla/5.0',
  }).timeout(const Duration(seconds: 10));

  if (response.statusCode != 200) {
    throw Exception('Yahoo Finance HTTP ${response.statusCode} for $symbol');
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final result = body['chart']?['result'] as List?;
  if (result == null || result.isEmpty) {
    throw Exception('No data from Yahoo Finance for $symbol');
  }

  final meta = result[0]['meta'] as Map<String, dynamic>;
  final price = (meta['regularMarketPrice'] as num).toDouble();
  final prevClose = (meta['chartPreviousClose'] ?? meta['previousClose'] ?? price) as num;
  final changePercent = prevClose != 0
      ? ((price - prevClose.toDouble()) / prevClose.toDouble()) * 100
      : 0.0;

  return {
    'price': price,
    'changePercent': changePercent,
  };
}

final yahooFinanceProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, symbol) => fetchYahooQuote(symbol),
);
