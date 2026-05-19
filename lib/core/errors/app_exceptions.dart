// ALTERA uygulama hata hiyerarşisi
// Kullanıcı hiçbir zaman ham teknik hata mesajı görmez

/// Tüm uygulama hatalarının temel sınıfı.
///
/// Her hata tipi:
/// - [userMessage]: Türkçe, kullanıcı dostu açıklama
/// - [technicalInfo]: Log için teknik detay
/// - [actionLabel]: Opsiyonel aksiyon butonu etiketi
sealed class AppException implements Exception {
  final String userMessage;
  final String technicalInfo;
  final String? actionLabel;

  const AppException({
    required this.userMessage,
    required this.technicalInfo,
    this.actionLabel,
  });

  @override
  String toString() => 'AppException: $technicalInfo';
}

/// Gemini API erişim hatası (ağ veya servis sorunu)
class GeminiUnavailableException extends AppException {
  const GeminiUnavailableException({required String detail})
    : super(
        userMessage:
            'AI analizi şu an kullanılamıyor. '
            'İşlemler kaydedildi, bağlantı gelince analiz edilecek.',
        technicalInfo: 'Gemini API error: $detail',
        actionLabel: 'Tamam',
      );
}

/// Gemini API key eksik veya geçersiz
class GeminiAuthException extends AppException {
  const GeminiAuthException()
    : super(
        userMessage:
            'Gemini API anahtarı bulunamadı. '
            'Lütfen Ayarlar\'dan API anahtarınızı girin.',
        technicalInfo: 'Gemini API key missing or invalid',
        actionLabel: 'Ayarlara Git',
      );
}

/// Veritabanı okuma/yazma hatası
class DatabaseException extends AppException {
  const DatabaseException({required String detail})
    : super(
        userMessage:
            'Veri kaydedilirken bir sorun oluştu. '
            'Uygulamayı yeniden başlatmayı deneyin.',
        technicalInfo: 'Database error: $detail',
        actionLabel: 'Yeniden Dene',
      );
}

/// Dosya içe aktarma başarısız
class ImportFailedException extends AppException {
  const ImportFailedException({required String reason})
    : super(
        userMessage: reason,
        technicalInfo: 'Import failed: $reason',
        actionLabel: 'Farklı Dosya Seç',
      );
}

/// Desteklenmeyen dosya formatı
class UnsupportedFormatException extends AppException {
  const UnsupportedFormatException()
    : super(
        userMessage:
            'Bu dosya formatı desteklenmiyor. '
            'PDF veya Excel (.xlsx) dosyası seçin.',
        technicalInfo: 'Unsupported file format',
        actionLabel: 'Tamam',
      );
}

/// İşlem bulunamadı (repository hatası)
class TransactionNotFoundException extends AppException {
  const TransactionNotFoundException({required String id})
    : super(
        userMessage: 'İşlem bulunamadı. Silinmiş olabilir.',
        technicalInfo: 'Transaction not found: $id',
        actionLabel: 'Geri Dön',
      );
}

/// Beklenmedik genel hata
class UnexpectedException extends AppException {
  const UnexpectedException({required String detail})
    : super(
        userMessage:
            'Beklenmedik bir hata oluştu. '
            'Sorun devam ederse uygulamayı yeniden başlatın.',
        technicalInfo: 'Unexpected: $detail',
        actionLabel: 'Yeniden Dene',
      );
}
