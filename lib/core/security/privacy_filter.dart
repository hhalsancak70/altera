// Gemini'ye gönderilecek veriden kişisel bilgileri temizler
import '../models/transaction.dart';

/// Gizlilik filtresi — kişisel verilerin Gemini API'ye gitmesini engeller.
///
/// GÜVENLİK PRENSİPLERİ:
/// - IBAN, kart numarası, ad, telefon, TC Kimlik asla Gemini'ye gitmez
/// - Yalnızca kategorizasyon için gereken minimum veri gönderilir
/// - İşlem tutarı pozitif (mutlak değer) olarak gönderilir
class PrivacyFilter {
  PrivacyFilter._();

  /// İşlem açıklamasından hassas kişisel bilgileri maskeler.
  ///
  /// Maskelenen desenler:
  ///   - IBAN (TR + 24 rakam)
  ///   - 16 haneli kart numaraları
  ///   - Türk telefon numaraları
  ///   - 11 haneli TC Kimlik No
  ///   - E-posta adresleri
  ///   - Hesap numaraları (bağlam: "hesap no:", "account number", "acct" sonrası 6-20 rakam)
  ///
  /// [maxLength] varsayılan 100 — Gemini için yeterli. Fatura parse için 500 kullan.
  static String sanitizeDescription(String description, {int maxLength = 100}) {
    String s = description;

    // IBAN maskele — TR + boşluklu/boşluksuz 24 rakam
    s = s.replaceAll(
      RegExp(
        r'TR\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{2}',
        caseSensitive: false,
      ),
      '[IBAN]',
    );

    // 16 haneli kart numarası maskele
    s = s.replaceAll(
      RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'),
      '[KART]',
    );

    // Türk telefon numarası (+90 veya 05xx)
    s = s.replaceAll(
      RegExp(r'(\+90|0)?\s?5\d{2}\s?\d{3}\s?\d{2}\s?\d{2}'),
      '[TEL]',
    );

    // 11 haneli TC Kimlik No (1 ile başlar)
    s = s.replaceAll(RegExp(r'\b[1-9]\d{10}\b'), '[TCKN]');

    // E-posta adresleri
    s = s.replaceAll(
      RegExp(r'\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b'),
      '[EMAIL]',
    );

    // Hesap numarası — bağlam anahtar kelimesi sonrası 6-20 rakam
    // Örn: "hesap no: 1234567890", "account number 1234567890", "acct 123456"
    s = s.replaceAllMapped(
      RegExp(
        r'(hesap\s*no[:\s]+|account\s*number[:\s]+|acct[:\s]+)(\d{6,20})',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}[ACCOUNT_NO]',
    );

    if (s.length > maxLength) s = s.substring(0, maxLength);

    return s.trim();
  }

  /// Gemini'ye gönderilecek işlem verisini hazırlar.
  ///
  /// Dönen map'te yalnızca açıklama (temizlenmiş) ve mutlak tutar bulunur.
  /// Tarih, isim, hesap bilgisi gönderilmez.
  static Map<String, dynamic> prepareForGemini(Transaction tx) {
    return {
      'description': sanitizeDescription(tx.description),
      'amount': tx.amount.abs(),
    };
  }
}
