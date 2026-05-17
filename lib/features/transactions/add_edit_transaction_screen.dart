// İşlem ekleme ve düzenleme ekranı
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/budget.dart';
import '../../core/models/transaction.dart';
import '../../core/providers.dart';
import '../../core/services/gemini_service.dart';
import '../../core/utils/app_snackbar.dart';

/// İşlem ekleme ve düzenleme ekranı.
///
/// [existingTransaction] null → yeni işlem modu
/// [existingTransaction] dolu → düzenleme modu
class AddEditTransactionScreen extends ConsumerStatefulWidget {
  final Transaction? existingTransaction;

  const AddEditTransactionScreen({super.key, this.existingTransaction});

  @override
  ConsumerState<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState
    extends ConsumerState<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isExpense = true; // Gider mi, Gelir mi?
  TransactionCategory _selectedCategory = TransactionCategory.other;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  bool get _isEditing => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.existingTransaction;
    if (tx != null) {
      _descriptionController.text = tx.description;
      _amountController.text = tx.amount.abs().toStringAsFixed(2);
      _isExpense = tx.amount < 0;
      _selectedCategory = tx.category;
      _selectedDate = tx.date;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(_isEditing ? 'İşlemi Düzenle' : 'Yeni İşlem'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _confirmDelete,
              tooltip: 'Sil',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── İşlem Türü ───
            const _SectionLabel(label: 'İşlem Türü'),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Gider'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Gelir'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: {_isExpense},
              onSelectionChanged: (set) =>
                  setState(() => _isExpense = set.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return _isExpense ? Colors.redAccent : Colors.greenAccent.shade700;
                  }
                  return AppColors.surface;
                }),
              ),
            ),

            const SizedBox(height: 20),

            // ─── Tutar ───
            const _SectionLabel(label: 'Tutar (₺)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                prefixText: '₺ ',
                prefixStyle: TextStyle(
                  color: _isExpense ? Colors.redAccent : Colors.greenAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                hintText: '0.00',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Tutar giriniz';
                final amount = double.tryParse(v);
                if (amount == null || amount <= 0) return 'Geçerli bir tutar giriniz';
                if (amount > 9999999) return 'Tutar çok büyük';
                return null;
              },
            ),

            const SizedBox(height: 20),

            // ─── Açıklama ───
            const _SectionLabel(label: 'Açıklama'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: AppColors.textPrimary),
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Migros market alışverişi',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                counterStyle: TextStyle(color: AppColors.textSecondary),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 2) {
                  return 'En az 2 karakter giriniz';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // ─── Tarih ───
            const _SectionLabel(label: 'Tarih'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textSecondary.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.accent, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(_selectedDate),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ─── Kategori ───
            const _SectionLabel(label: 'Kategori'),
            const SizedBox(height: 8),
            DropdownButtonFormField<TransactionCategory>(
              initialValue: _selectedCategory,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.category_outlined, color: AppColors.accent),
              ),
              items: TransactionCategory.values
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text('${cat.emoji}  ${cat.displayNameTr}'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v ?? TransactionCategory.other),
            ),

            const SizedBox(height: 32),

            // ─── Kaydet Butonu ───
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_isEditing ? Icons.save : Icons.add),
                label: Text(
                  _isEditing ? 'Değişiklikleri Kaydet' : 'İşlemi Ekle',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // Gelecek tarihe izin verme
      locale: const Locale('tr', 'TR'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final amount = double.parse(_amountController.text);
      final finalAmount = _isExpense ? -amount : amount;

      final tx = Transaction(
        id: widget.existingTransaction?.id ?? const Uuid().v4(),
        description: _descriptionController.text.trim(),
        amount: finalAmount,
        date: _selectedDate,
        category: _selectedCategory,
        type: _isExpense ? TransactionType.need : TransactionType.income,
        aiReason: null,
        isAnalyzed: true, // Manuel kategori seçildi, analiz gerekmez
        source: 'manual',
        createdAt: widget.existingTransaction?.createdAt ?? DateTime.now(),
      );

      final repo = ref.read(transactionRepositoryProvider);

      if (_isEditing) {
        await repo.updateTransaction(tx);
      } else {
        await repo.addTransaction(tx);
      }

      if (!mounted) return;

      ref.invalidate(currentMonthTransactionsProvider);
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(monthlySpendingProvider);
      ref.invalidate(monthlySummaryProvider);
      ref.invalidate(currentMonthBudgetsProvider);

      final snackMessage =
          _isEditing ? 'İşlem güncellendi' : 'İşlem eklendi';
      showAppSnackBar(snackMessage,
          backgroundColor: Colors.greenAccent.shade700);

      // Yeni işlem ekleme → Gemini yorumu arka planda istenir, hazır olunca global snackbar
      // Kullanıcı beklemiyor, ekran anında kapanıyor
      if (!_isEditing) {
        _fetchGeminiCommentInBackground(tx);
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// İşlem kaydedildikten sonra Gemini'den ARKA PLANDA yorum ister.
  /// Kullanıcı ekranı zaten kapatmış olur, yorum hazır olunca alttaki sayfada snackbar gösterilir.
  /// Hata olursa sessizce yutulur.
  void _fetchGeminiCommentInBackground(Transaction tx) {
    () async {
      try {
        final db = ref.read(dbHelperProvider);
        final spending = await db.getMonthlySpendingByCategory(DateTime.now());
        final budgets = await db.getBudgetsForMonth(DateTime.now());
        final categoryBudget = budgets
            .firstWhere(
              (b) => b.category == tx.category,
              orElse: () => Budget(
                id: '',
                category: tx.category,
                limitAmount: 0,
                spentAmount: 0,
                month: DateTime.now(),
              ),
            )
            .limitAmount;
        final spentSoFar = spending[tx.category] ?? 0;

        final gemini = await ref.read(geminiServiceProvider.future);
        final comment = await gemini.commentOnNewTransaction(
          transaction: tx,
          currentMonthSpending: spending,
          categoryBudget: categoryBudget,
          categorySpentSoFar: spentSoFar,
        );

        showAppSnackBar(
          '✨ $comment',
          backgroundColor: AppColors.surfaceLight,
          duration: const Duration(seconds: 5),
        );
      } on GeminiException catch (e) {
        if (!e.isQuotaExceeded) return; // sessiz fallback
        showAppSnackBar(
          'Gemini yorumu için kota dolu',
          backgroundColor: AppColors.warning,
        );
      } catch (_) {
        // yutuluyor — kullanıcı yorum görmese de işlem zaten kaydedildi
      }
    }();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('İşlemi Sil', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Bu işlem kalıcı olarak silinecek. Devam etmek istiyor musunuz?',
          style: TextStyle(color: AppColors.textSecondary),
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

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(transactionRepositoryProvider)
            .deleteTransaction(widget.existingTransaction!.id);

        if (mounted) {
          ref.invalidate(currentMonthTransactionsProvider);
          ref.invalidate(allTransactionsProvider);
          ref.invalidate(monthlySpendingProvider);
          ref.invalidate(monthlySummaryProvider);

          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('İşlem silindi'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Silinemedi: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}
