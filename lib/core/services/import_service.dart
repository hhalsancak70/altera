// Finansal belge içe aktarma servisi — PDF ve Excel
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/transaction.dart';

/// Desteklenen banka formatları
enum BankFormat {
  ziraat,
  garanti,
  isBank,
  akbank,
  yapiKredi,
  generic,
}

/// Import işlemi sonucu
class ImportResult {
  final List<Transaction> transactions;
  final BankFormat bankFormat;
  final int totalFound;
  final int successfullyParsed;
  final List<String> warnings;

  const ImportResult({
    required this.transactions,
    required this.bankFormat,
    required this.totalFound,
    required this.successfullyParsed,
    this.warnings = const [],
  });
}

/// Import hatası — kullanıcıya gösterilebilir mesaj içerir
class ImportException implements Exception {
  final String message;
  const ImportException(this.message);

  @override
  String toString() => message;
}

/// Finansal belge içe aktarma servisi.
///
/// GÜVENLİK PRENSİPLERİ:
/// - Tüm parse işlemi cihazda gerçekleşir
/// - Dosya içeriği sunucuya gönderilmez
/// - Dosya yolu veritabanına kaydedilmez
/// - Yalnızca çıkarılan işlem verileri saklanır
class ImportService {
  final _uuid = const Uuid();

  /// Excel dosyasından işlemleri içe aktarır.
  ///
  /// [bytes] Excel dosyasının byte verisi (.xlsx)
  /// [onProgress] İlerleme bildirimi callback'i (0.0-1.0)
  /// Returns: Parse edilen işlemler + meta bilgi
  Future<ImportResult> importFromExcel({
    required Uint8List bytes,
    required void Function(double progress, String status) onProgress,
  }) async {
    onProgress(0.0, 'Excel dosyası okunuyor...');

    if (bytes.length > 20 * 1024 * 1024) {
      throw const ImportException('Dosya çok büyük (max 20MB)');
    }

    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw ImportException('Excel dosyası açılamadı: $e');
    }

    if (excel.tables.isEmpty) {
      throw const ImportException('Excel dosyasında sayfa bulunamadı');
    }

    onProgress(0.2, 'Sayfa analiz ediliyor...');

    final rawTransactions = <Transaction>[];
    final warnings = <String>[];

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName]!;
      if (sheet.maxRows < 2) continue;

      // Başlık satırını bul (Tarih + Tutar sütunu olan satır)
      final headerRow = _findHeaderRow(sheet);
      if (headerRow == -1) {
        warnings.add('$sheetName sayfasında uygun başlık bulunamadı');
        continue;
      }

      final columnMap = _mapColumns(sheet.row(headerRow));
      if (!columnMap.containsKey('date') || !columnMap.containsKey('amount')) {
        warnings.add('$sheetName: Tarih veya Tutar sütunu bulunamadı');
        continue;
      }

      onProgress(0.3, 'İşlemler okunuyor...');

      for (int row = headerRow + 1; row < sheet.maxRows; row++) {
        try {
          final tx = _parseExcelRow(sheet.row(row), columnMap: columnMap);
          if (tx != null) rawTransactions.add(tx);
        } catch (_) {
          // Satır parse hatası — atla, devam et
        }

        if (row % 10 == 0) {
          onProgress(
            0.3 + (row / sheet.maxRows) * 0.6,
            '${rawTransactions.length} işlem bulundu...',
          );
        }
      }
      break; // İlk geçerli sayfayı işledik
    }

    if (rawTransactions.isEmpty) {
      throw const ImportException(
        'Geçerli işlem bulunamadı. Dosyanın doğru banka ekstresi olduğundan emin olun.',
      );
    }

    onProgress(1.0, 'Tamamlandı!');

    return ImportResult(
      transactions: rawTransactions,
      bankFormat: BankFormat.generic,
      totalFound: rawTransactions.length,
      successfullyParsed: rawTransactions.length,
      warnings: warnings,
    );
  }

  /// Başlık satırını bulur (Tarih + Tutar sütunlarını içeren satır)
  int _findHeaderRow(Sheet sheet) {
    for (int i = 0; i < sheet.maxRows && i < 10; i++) {
      final row = sheet.row(i);
      final rowText = row
          .map((c) => c?.value?.toString().toLowerCase() ?? '')
          .join(' ');

      // Tarih ve tutar kelimelerinden birini içeriyorsa başlık satırı
      if ((rowText.contains('tarih') || rowText.contains('date')) &&
          (rowText.contains('tutar') ||
              rowText.contains('amount') ||
              rowText.contains('borç') ||
              rowText.contains('alacak'))) {
        return i;
      }
    }
    return -1;
  }

  /// Başlık satırından sütun eşlemesi çıkarır
  Map<String, int> _mapColumns(List<Data?> headerRow) {
    final map = <String, int>{};
    for (int i = 0; i < headerRow.length; i++) {
      final cell = headerRow[i]?.value?.toString().toLowerCase().trim() ?? '';
      if (cell.contains('tarih') || cell.contains('date')) {
        map['date'] = i;
      } else if (cell.contains('açıklama') ||
          cell.contains('description') ||
          cell.contains('işlem')) {
        map['description'] = i;
      } else if (cell.contains('tutar') || cell.contains('amount')) {
        map['amount'] = i;
      } else if (cell.contains('borç') || cell.contains('debit')) {
        map['debit'] = i;
      } else if (cell.contains('alacak') || cell.contains('credit')) {
        map['credit'] = i;
      }
    }
    return map;
  }

  /// Excel satırını Transaction'a dönüştürür
  Transaction? _parseExcelRow(
    List<Data?> row, {
    required Map<String, int> columnMap,
  }) {
    if (row.isEmpty) return null;

    // Tarih parse
    DateTime? date;
    if (columnMap.containsKey('date')) {
      final dateCell = row[columnMap['date']!]?.value;
      date = _parseDate(dateCell?.toString() ?? '');
    }
    if (date == null) return null;

    // Açıklama
    String description = 'İşlem';
    if (columnMap.containsKey('description')) {
      description =
          row[columnMap['description']!]?.value?.toString().trim() ?? 'İşlem';
    }
    if (description.isEmpty) description = 'İşlem';

    // Tutar
    double amount = 0;
    if (columnMap.containsKey('amount')) {
      amount = _parseAmount(row[columnMap['amount']!]?.value?.toString() ?? '');
    } else if (columnMap.containsKey('debit') || columnMap.containsKey('credit')) {
      final debit = columnMap.containsKey('debit')
          ? _parseAmount(row[columnMap['debit']!]?.value?.toString() ?? '')
          : 0.0;
      final credit = columnMap.containsKey('credit')
          ? _parseAmount(row[columnMap['credit']!]?.value?.toString() ?? '')
          : 0.0;
      // Borç negatif, alacak pozitif
      amount = credit > 0 ? credit : -debit;
    }

    if (amount == 0) return null;

    return Transaction(
      id: _uuid.v4(),
      description: description,
      amount: amount,
      date: date,
      category: TransactionCategory.other,
      type: amount > 0 ? TransactionType.income : TransactionType.need,
      aiReason: null,
      isAnalyzed: false, // Gemini analizi bekliyor
      source: 'import',
      createdAt: DateTime.now(),
    );
  }

  /// Çeşitli tarih formatlarını parse eder
  DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;

    // Excel sayısal tarih (1900'dan gün sayısı)
    final numericValue = double.tryParse(raw);
    if (numericValue != null && numericValue > 40000) {
      // Excel epoch başlangıcı: 30 Aralık 1899
      return DateTime(1899, 12, 30)
          .add(Duration(days: numericValue.toInt()));
    }

    // Türkçe/uluslararası format denemeleri
    final formats = [
      'dd.MM.yyyy',
      'dd/MM/yyyy',
      'yyyy-MM-dd',
      'd.M.yyyy',
      'dd.MM.yy',
    ];

    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parseStrict(raw.trim());
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Türk para formatını double'a çevirir
  double _parseAmount(String raw) {
    if (raw.isEmpty) return 0;
    // "1.234,56" → 1234.56
    String cleaned = raw
        .replaceAll(' ', '')
        .replaceAll('₺', '')
        .replaceAll('TL', '')
        .trim();

    // Türk formatı: nokta binlik ayraç, virgül ondalık
    if (cleaned.contains(',') && cleaned.contains('.')) {
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else if (cleaned.contains(',') && !cleaned.contains('.')) {
      cleaned = cleaned.replaceAll(',', '.');
    }

    return double.tryParse(cleaned) ?? 0;
  }
}
