// İşlemler listesi ekranı - arama, filtre, CRUD ve AI etiketleri
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/transaction.dart';
import '../../core/providers.dart';
import '../../core/utils/app_snackbar.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddScreen(context),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('İşlem Ekle'),
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
                  padding: const EdgeInsets.only(bottom: 88), // FAB için boşluk
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final tx = filtered[i];
                    return Dismissible(
                      key: ValueKey(tx.id),
                      // Sola kaydır → sil
                      background: _buildSwipeBackground(
                        alignment: Alignment.centerRight,
                        color: Colors.redAccent,
                        icon: Icons.delete_outline,
                        label: 'Sil',
                      ),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(context, tx),
                      onDismissed: (_) {
                        // Provider'ı önce sync invalidate et ki widget tree'den çıksın,
                        // sonra async delete başla. Yoksa "dismissed but still in tree" hatası.
                        ref.invalidate(allTransactionsProvider);
                        ref.invalidate(currentMonthTransactionsProvider);
                        ref.invalidate(recentTransactionsProvider);
                        _deleteTransaction(tx);
                      },
                      child: GestureDetector(
                        onLongPress: () => _openEditScreen(context, tx),
                        child: TransactionTile(tx: tx),
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

  Future<void> _deleteTransaction(Transaction tx) async {
    try {
      await ref.read(transactionRepositoryProvider).deleteTransaction(tx.id);
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(monthlySpendingProvider);
      ref.invalidate(monthlySummaryProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(currentMonthTransactionsProvider);
      if (mounted) {
        showAppSnackBar('İşlem silindi', backgroundColor: AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar('Silinemedi', backgroundColor: AppColors.danger);
      }
    }
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
                          ? AppColors.accent.withValues(alpha: 0.2)
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
              activeThumbColor: AppColors.accent,
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
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
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
