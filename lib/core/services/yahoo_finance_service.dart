import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Servisi Riverpod ile dışarı açıyoruz
final yahooFinanceProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, symbol) async {
  // Yahoo Finance'in v8 chart API'sini kullanıyoruz
  final url = Uri.parse('https://query1.finance.yahoo.com/v8/finance/chart/$symbol');

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final meta = data['chart']['result'][0]['meta'];

    final currentPrice = (meta['regularMarketPrice'] as num).toDouble();
    final previousClose = (meta['previousClose'] as num).toDouble();

    // Günlük değişim yüzdesini hesaplıyoruz
    final changePercent = ((currentPrice - previousClose) / previousClose) * 100;
    final changeAmount = currentPrice - previousClose;

    return {
      'price': currentPrice,
      'changePercent': changePercent,
      'changeAmount': changeAmount,
      'isUp': changePercent >= 0,
    };
  } else {
    throw Exception('Veri çekilemedi: $symbol');
  }
});