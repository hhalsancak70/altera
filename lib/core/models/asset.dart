import 'package:flutter/material.dart';

/// Portföydeki tek bir varlığı (hisse, kripto, döviz, emtia) temsil eder.
class Asset {
  final String name;
  final String symbol;
  final String prefix;
  final Color color;
  final double units;
  final double totalCost;

  const Asset({
    required this.name,
    required this.symbol,
    required this.prefix,
    required this.color,
    required this.units,
    required this.totalCost,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'symbol': symbol,
    'prefix': prefix,
    'colorHex': color.toARGB32(),
    'units': units,
    'totalCost': totalCost,
  };

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
    name: json['name'] as String,
    symbol: json['symbol'] as String,
    prefix: json['prefix'] as String,
    color: Color(json['colorHex'] as int),
    units: (json['units'] as num).toDouble(),
    totalCost: (json['totalCost'] as num).toDouble(),
  );
}
