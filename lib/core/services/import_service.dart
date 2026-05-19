// Finansal belge içe aktarma servisi — Excel
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/transaction.dart';
import '../utils/money_parser.dart';

/// Desteklenen banka formatları
enum BankFormat { ziraat, garanti, isBank, akbank, yapiKredi, generic }

/// Import satır ayrıştırma sonucu
sealed class _RowResult {}

class _RowParsed extends _RowResult {
  final Transaction tx;
  _RowParsed(this.tx);
}

class _RowEmpty extends _RowResult {}

class _RowInvalid extends _RowResult {
  final String reason;
  _RowInvalid(this.reason);
}

/// Import işlemi sonucu
class ImportResult {
  final List<Transaction> transactions;
  final BankFormat bankFormat;
  final int totalRowsRead;
  final int successfullyParsed;
  final int parseErrors;
  final int duplicatesSkipped;
  final int emptyRowsSkipped;
  final List<String> warnings;

  const ImportResult({
    required this.transactions,
    required this.bankFormat,
    required this.totalRowsRead,
    required this.successfullyParsed,
    this.parseErrors = 0,
    this.duplicatesSkipped = 0,
    this.emptyRowsSkipped = 0,
    this.warnings = const [],
  });

  @Deprecated('Use totalRowsRead instead')
  int get totalFound => totalRowsRead;
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
    var totalParseErrors = 0;
    var totalEmptyRows = 0;
    var totalRowsRead = 0;

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName]!;
      if (sheet.maxRows < 2) continue;

      // Başlık satırını bul
      final headerRow = _findHeaderRow(sheet);
      if (headerRow == -1) {
        warnings.add('$sheetName sayfasında uygun başlık bulunamadı');
        continue;
      }

      final columnMap = _mapColumns(sheet.row(headerRow));
      final hasAmountCol =
          columnMap.containsKey('amount') ||
          columnMap.containsKey('debit') ||
          columnMap.containsKey('credit');
      if (!columnMap.containsKey('date') || !hasAmountCol) {
        warnings.add(
          '$sheetName: Tarih veya Tutar/Borç/Alacak sütunu bulunamadı',
        );
        continue;
      }

      onProgress(0.3, 'İşlemler okunuyor...');

      int sheetParseErrors = 0;
      int sheetEmptyRows = 0;

      for (int row = headerRow + 1; row < sheet.maxRows; row++) {
        totalRowsRead++;
        final result = _parseExcelRow(sheet.row(row), columnMap: columnMap);

        if (result is _RowParsed) {
          rawTransactions.add(result.tx);
        } else if (result is _RowEmpty) {
          sheetEmptyRows++;
        } else if (result is _RowInvalid) {
          sheetParseErrors++;
        }

        if (row % 10 == 0) {
          onProgress(
            0.3 + (row / sheet.maxRows) * 0.6,
            '${rawTransactions.length} işlem bulundu...',
          );
        }
      }

      totalParseErrors += sheetParseErrors;
      totalEmptyRows += sheetEmptyRows;

      if (sheetParseErrors > 0) {
        warnings.add('$sheetParseErrors satır parse edilemedi ve atlandı');
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
      totalRowsRead: totalRowsRead,
      successfullyParsed: rawTransactions.length,
      parseErrors: totalParseErrors,
      emptyRowsSkipped: totalEmptyRows,
      warnings: warnings,
    );
  }

  /// Başlık satırını bulur (Tarih + Tutar/Borç/Alacak sütunlarını içeren satır)
  int _findHeaderRow(Sheet sheet) {
    for (int i = 0; i < sheet.maxRows && i < 10; i++) {
      final row = sheet.row(i);
      final rowText = row
          .map((c) => c?.value?.toString().toLowerCase() ?? '')
          .join(' ');

      final hasDate =
          rowText.contains('tarih') || rowText.contains('date');
      final hasAmount =
          rowText.contains('tutar') ||
          rowText.contains('amount') ||
          rowText.contains('borç') ||
          rowText.contains('alacak') ||
          rowText.contains('debit') ||
          rowText.contains('credit') ||
          rowText.contains('withdrawal') ||
          rowText.contains('deposit');

      if (hasDate && hasAmount) return i;
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
      } else if (cell.contains('borç') ||
          cell.contains('debit') ||
          cell.contains('withdrawal')) {
        map['debit'] = i;
      } else if (cell.contains('alacak') ||
          cell.contains('credit') ||
          cell.contains('deposit')) {
        map['credit'] = i;
      }
    }
    return map;
  }

  /// Excel satırını ayrıştırma sonucuna dönüştürür
  _RowResult _parseExcelRow(
    List<Data?> row, {
    required Map<String, int> columnMap,
  }) {
    // Tamamen boş satırı atla
    if (row.isEmpty || row.every((c) => c?.value == null)) return _RowEmpty();

    // Tarih parse
    DateTime? date;
    if (columnMap.containsKey('date')) {
      final dateCell = row[columnMap['date']!]?.value;
      if (dateCell == null) return _RowInvalid('Tarih boş');
      date = _parseDate(dateCell.toString());
      if (date == null) {
        return _RowInvalid('Geçersiz tarih: ${dateCell.toString()}');
      }
    } else {
      return _RowInvalid('Tarih sütunu bulunamadı');
    }

    // Açıklama
    String description = 'İşlem';
    if (columnMap.containsKey('description')) {
      description =
          row[columnMap['description']!]?.value?.toString().trim() ?? 'İşlem';
    }
    if (description.isEmpty) description = 'İşlem';

    // Tutar — bozuk tutar sessizce 0 yapılmaz, parse error döner
    double? amount;
    if (columnMap.containsKey('amount')) {
      final raw = row[columnMap['amount']!]?.value?.toString() ?? '';
      if (raw.trim().isEmpty) return _RowInvalid('Tutar boş');
      amount = parseMoneyAmount(raw);
      if (amount == null) return _RowInvalid('Geçersiz tutar: $raw');
    } else if (columnMap.containsKey('debit') ||
        columnMap.containsKey('credit')) {
      final debitRaw =
          columnMap.containsKey('debit')
              ? row[columnMap['debit']!]?.value?.toString() ?? ''
              : '';
      final creditRaw =
          columnMap.containsKey('credit')
              ? row[columnMap['credit']!]?.value?.toString() ?? ''
              : '';

      final debit =
          debitRaw.trim().isEmpty ? null : parseMoneyAmount(debitRaw);
      final credit =
          creditRaw.trim().isEmpty ? null : parseMoneyAmount(creditRaw);

      if (debit == null && credit == null) {
        // Her iki sütun da boşsa boş satır
        if (debitRaw.trim().isEmpty && creditRaw.trim().isEmpty) {
          return _RowEmpty();
        }
        return _RowInvalid('Geçersiz borç/alacak: $debitRaw / $creditRaw');
      }

      // Borç negatif, alacak pozitif
      if (credit != null && credit > 0) {
        amount = credit;
      } else if (debit != null && debit > 0) {
        amount = -debit;
      } else {
        amount = (credit ?? 0) - (debit ?? 0);
      }
    }

    if (amount == null) return _RowInvalid('Tutar belirlenemedi');
    if (amount == 0) return _RowInvalid('Sıfır tutarlı işlem atlandı');

    return _RowParsed(
      Transaction(
        id: _uuid.v4(),
        description: description,
        amount: amount,
        date: date,
        category: TransactionCategory.other,
        type: amount > 0 ? TransactionType.income : TransactionType.need,
        aiReason: null,
        isAnalyzed: false,
        source: 'import',
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Çeşitli tarih formatlarını parse eder
  DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;

    // Excel sayısal tarih (1900'dan gün sayısı)
    final numericValue = double.tryParse(raw);
    if (numericValue != null && numericValue > 40000) {
      return DateTime(1899, 12, 30).add(Duration(days: numericValue.toInt()));
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
}
