// İşlemler listesi ekranı - arama, filtre, CRUD ve AI etiketleri
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/transaction.dart';
import '../../core/providers.dart';
import 'add_edit_transaction_screen.dart';
import 'widgets/transaction_tile.dart';

/// Tüm işlemler listesi ekranı.
/// Arama, filtre ve AI kategori etiketleri içerir.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _searchQuery = '';
  TransactionCategory? _selectedCategory;
  bool _showUnanalyzedOnly = false;

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(allTransactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('İşlemler'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _selectedCategory != null || _showUnanalyzedOnly
                  ? AppColors.accent
                  : AppColors.textSecondary,
            ),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withOpacity(0.4),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GlassButton(
                  icon: Icons.document_scanner,
                  label: 'Dekont',
                  color: AppColors.accent,
                  onTap: () => _importDocument(context),
                ),
                const SizedBox(width: 16),
                Container(width: 1, height: 24, color: Colors.white.withOpacity(0.2)),
                const SizedBox(width: 16),
                _GlassButton(
                  icon: Icons.add,
                  label: 'İşlem Ekle',
                  color: AppColors.success,
                  onTap: () => _openAddScreen(context),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Arama çubuğu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'İşlem ara...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
                    : null,
              ),
            ),
          ),
          // Filtre chips
          if (_selectedCategory != null || _showUnanalyzedOnly)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  if (_selectedCategory != null)
                    _FilterChip(
                      label:
                      '${_selectedCategory!.emoji} ${_selectedCategory!.displayNameTr}',
                      onRemove: () => setState(() => _selectedCategory = null),
                    ),
                  if (_showUnanalyzedOnly)
                    _FilterChip(
                      label: 'Analiz Bekliyor',
                      onRemove: () =>
                          setState(() => _showUnanalyzedOnly = false),
                    ),
                ],
              ),
            ),
          // İşlem listesi
          Expanded(
            child: txAsync.when(
              data: (transactions) {
                final filtered = _applyFilters(transactions);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'İşlem bulunamadı',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 140),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final tx = filtered[i];
                    return Dismissible(
                      key: ValueKey(tx.id),
                      background: _buildSwipeBackground(
                        alignment: Alignment.centerRight,
                        color: Colors.redAccent,
                        icon: Icons.delete_outline,
                        label: 'Sil',
                      ),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(context, tx),
                      onDismissed: (_) => _deleteTransaction(tx),
                      child: TransactionTile(
                        tx: tx,
                        onEdit: () => _openEditScreen(context, tx),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
              error: (_, __) => const Center(
                child: Text(
                  'İşlemler yüklenemedi',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 GÜNCEL: Siyah Ekran (GoRouter Pop) Çözümlü Yükleme Motoru
  Future<void> _importDocument(BuildContext context) async {
    bool isDialogOpen = false;

    try {
      // 1. Dosya Seçimi
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final fileBytes = await file.readAsBytes();
      final extension = result.files.single.extension?.toLowerCase() ?? '';

      if (!mounted) return;

      // 2. Yükleniyor Dialogu Göster
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true, // 🔥 Ekrana tam oturması ve GoRouter'dan kaçması için şart
        builder: (ctx) => const AlertDialog(
          backgroundColor: AppColors.surface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(height: 16),
              Text(
                'ALTERA Ajanı belgeyi okuyor ve işlemleri çıkarıyor. Lütfen bekleyin...',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
      );

      isDialogOpen = true;

      String extractedExcelText = '';

      // Eğer Excel ise lokal olarak metne çevir
      if (extension == 'xlsx' || extension == 'xls') {
        var excel = ex.Excel.decodeBytes(fileBytes);
        for (var table in excel.tables.keys) {
          for (var row in excel.tables[table]!.rows) {
            extractedExcelText += row.map((e) => e?.value.toString() ?? '').join(' ') + '\n';
          }
        }
      }

      // 3. Dosyadan Metin Çıkarma (PDF veya Excel)
      String extractedText = '';

      if (extension == 'pdf') {
        final PdfDocument document = PdfDocument(inputBytes: fileBytes);
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        extractedText = extractor.extractText();
        document.dispose();
      } else if (extension == 'xlsx' || extension == 'xls') {
        extractedText = extractedExcelText;
      }

      if (extractedText.isEmpty) {
        throw Exception('Belgeden metin okunamadı.');
      }

      // 4. Groq API ile İşlem Yakalama
      const storage = FlutterSecureStorage();
      String? apiKey = await storage.read(key: AppConstants.kSecureKeyGeminiApiKey);

      if (apiKey == null || apiKey.isEmpty || apiKey == 'AIzaSyCwhgjxfc2i3W3_-n8JYkVhYg3xcn8HbRE') {
        apiKey = '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';
      }

      final prompt = '''
Sen ALTERA finansal analiz ajanısın. Aşağıdaki belge içeriğini analiz et ve tüm harcama/gelir kalemlerini bul.
SADECE geçerli bir JSON formatında (Array içinde) döndür. Başka hiçbir açıklama yazma.

Örnek Çıktı:
[
  {
    "description": "Migros A.Ş.",
    "amount": -250.50,
    "date": "2023-10-25T00:00:00",
    "category": "market",
    "type": "need"
  }
]

Belge İçeriği:
$extractedText
''';

      final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.1,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('API Hatası: ${response.statusCode} - ${response.body}');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final responseText = data['choices'][0]['message']['content'] as String;

      final start = responseText.indexOf('[');
      final end = responseText.lastIndexOf(']');

      if (start == -1 || end == -1) {
        throw Exception('Geçerli işlem bulunamadı.');
      }

      final jsonStr = responseText.substring(start, end + 1);
      final List<dynamic> jsonList = jsonDecode(jsonStr);

      if (jsonList.isEmpty) {
        throw Exception('Belgede işlem bulunamadı.');
      }

      final repo = ref.read(transactionRepositoryProvider);

      for (var item in jsonList) {
        final tx = Transaction(
          id: const Uuid().v4(),
          description: item['description'] ?? 'Otomatik Kayıt',
          amount: (item['amount'] as num?)?.toDouble() ?? 0.0,
          date: DateTime.tryParse(item['date'] ?? '') ?? DateTime.now(),
          category: TransactionCategory.values.firstWhere(
            (e) => e.name == (item['category']?.toString().toLowerCase()),
            orElse: () => TransactionCategory.other,
          ),
          type: TransactionType.values.firstWhere(
            (e) => e.name == (item['type']?.toString().toLowerCase()),
            orElse: () => TransactionType.need,
          ),
          aiReason: 'Dekont Analizi',
          isAnalyzed: true,
          source: 'import',
          createdAt: DateTime.now(),
        );
        await repo.addTransaction(tx);
      }

      if (!mounted) return;

      // 🔥 GÜVENLİ KAPATMA
      if (isDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogOpen = false;
      }

      ref.invalidate(allTransactionsProvider);
      ref.invalidate(currentMonthTransactionsProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(monthlySpendingProvider);
      ref.invalidate(monthlySummaryProvider);
      ref.invalidate(currentMonthBudgetsProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${jsonList.length} işlem başarıyla eklendi!'),
          backgroundColor: Colors.greenAccent.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

    } catch (e) {
      if (!mounted) return;

      // 🔥 HATA DURUMUNDA GÜVENLİ KAPATMA
      if (isDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogOpen = false;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _openAddScreen(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddEditTransactionScreen(),
      ),
    );
    if (result == true) {
      ref.invalidate(allTransactionsProvider);
    }
  }

  Future<void> _openEditScreen(BuildContext context, Transaction tx) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditTransactionScreen(existingTransaction: tx),
      ),
    );
    if (result == true) {
      ref.invalidate(allTransactionsProvider);
    }
  }

  Future<bool?> _confirmDelete(BuildContext context, Transaction tx) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('İşlemi Sil', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '"${tx.description}" işlemi kalıcı olarak silinecek.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _deleteTransaction(Transaction tx) {
    final repo = ref.read(transactionRepositoryProvider);
    repo.deleteTransaction(tx.id).then((_) {
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(monthlySpendingProvider);
      ref.invalidate(monthlySummaryProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('İşlem silindi'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Geri Al',
            onPressed: () {
              repo.addTransaction(tx).then((_) {
                ref.invalidate(allTransactionsProvider);
              });
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    });
  }

  Widget _buildSwipeBackground({
    required AlignmentGeometry alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  List<Transaction> _applyFilters(List<Transaction> transactions) {
    return transactions.where((tx) {
      if (_searchQuery.isNotEmpty &&
          !tx.description.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_selectedCategory != null && tx.category != _selectedCategory) {
        return false;
      }
      if (_showUnanalyzedOnly && tx.isAnalyzed) return false;
      return true;
    }).toList();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtrele',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Kategori',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TransactionCategory.values.map((cat) {
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = isSelected ? null : cat;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent.withOpacity(0.2)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      '${cat.emoji} ${cat.displayNameTr}',
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _showUnanalyzedOnly,
              onChanged: (v) {
                setState(() => _showUnanalyzedOnly = v);
                Navigator.pop(ctx);
              },
              title: const Text(
                'Yalnızca analiz bekleyenler',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              ),
              activeColor: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, color: AppColors.accent, size: 14),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GlassButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}