// Türkçe ve uluslararası para formatlarını double'a çevirir

/// Türkçe ve uluslararası para formatlarını double'a çevirir.
///
/// Desteklenen formatlar:
///   `12,50`       → 12.50
///   `1.234,56`    → 1234.56  (Türkçe: nokta binlik, virgül ondalık)
///   `1234,56`     → 1234.56
///   `1234.56`     → 1234.56
///   `1,234.56`    → 1234.56  (İngilizce: virgül binlik, nokta ondalık)
///   `₺1.234,56`   → 1234.56  (para birimi sembolü atılır)
///   `1234`        → 1234.0
///
/// Geçersiz girişte `null` döndürür.
double? parseMoneyAmount(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;

  // Para birimi sembollerini ve boşlukları temizle
  String s = raw
      .trim()
      .replaceAll('₺', '')
      .replaceAll('TL', '')
      .replaceAll('\$', '')
      .replaceAll('€', '')
      .replaceAll(' ', '');

  if (s.isEmpty) return null;

  // Hem nokta hem virgül varsa format belirle
  if (s.contains(',') && s.contains('.')) {
    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');
    if (lastDot > lastComma) {
      // İngilizce format: 1,234.56 → virgül binlik, nokta ondalık
      s = s.replaceAll(',', '');
    } else {
      // Türkçe format: 1.234,56 → nokta binlik, virgül ondalık
      s = s.replaceAll('.', '').replaceAll(',', '.');
    }
  } else if (s.contains(',')) {
    // Yalnızca virgül: ondalık ayraç olarak yorumla (12,50 → 12.50)
    s = s.replaceAll(',', '.');
  }
  // Yalnızca nokta: doğrudan parse edilir (1234.56)

  return double.tryParse(s);
}

/// [parseMoneyAmount] ile aynı; geçersiz girişte 0.0 döndürür.
double parseMoneyAmountOrZero(String? raw) => parseMoneyAmount(raw) ?? 0.0;
