// Excel banka ekstresi içe aktarma ekranı
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/transaction.dart';
import '../../core/providers.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/services/import_service.dart';

/// Banka ekstresi içe aktarma ekranı.
///
/// Akış: 1. Dosya Seç → 2. Yükleme → 3. Önizleme → 4. Tamamlandı
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

enum _ImportStep { selectFile, loading, preview, done }

class _ImportScreenState extends ConsumerState<ImportScreen> {
  _ImportStep _step = _ImportStep.selectFile;
  double _progress = 0;
  String _progressStatus = '';
  ImportResult? _result;
  List<bool> _selectedFlags = [];
  bool _isSaving = false;
  String? _errorMessage;
  BulkImportResult? _importStats;

  final _importService = ImportService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Ekstre İçe Aktar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return switch (_step) {
      _ImportStep.selectFile => _buildSelectFileStep(),
      _ImportStep.loading => _buildLoadingStep(),
      _ImportStep.preview => _buildPreviewStep(),
      _ImportStep.done => _buildDoneStep(),
    };
  }

  // ─── ADIM 1: DOSYA SEÇ ───
  Widget _buildSelectFileStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withAlpha(80)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, color: AppColors.accent, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dosyanız yalnızca bu cihazda işlenir. '
                    'Hiçbir sunucuya yüklenmez.',
                    style: TextStyle(color: AppColors.accent, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _FileTypeCard(
            icon: Icons.table_chart_outlined,
            title: 'Excel Ekstresi (.xlsx)',
            subtitle: 'Garanti, Ziraat, İş Bankası, Akbank, Yapı Kredi',
            color: Colors.greenAccent.shade700,
            onTap: _pickExcelFile,
          ),
          const SizedBox(height: 16),
          const Text(
            'Bankalar arası menüsünden "Excel olarak indir" seçeneğini '
            'kullanarak .xlsx formatında dosyayı indirin.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── ADIM 2: YÜKLEME ───
  Widget _buildLoadingStep() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: _progress > 0 ? _progress : null,
              strokeWidth: 6,
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '${(_progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _progressStatus,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── ADIM 3: ÖNİZLEME ───
  Widget _buildPreviewStep() {
    final result = _result!;
    final selectedCount = _selectedFlags.where((f) => f).length;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Column(
            children: [
              Text(
                '${result.successfullyParsed} işlem bulundu',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$selectedCount / ${result.transactions.length} seçili',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              if (result.parseErrors > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${result.parseErrors} satır okunamadı (geçersiz tarih/tutar)',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: result.transactions.length,
            itemBuilder: (ctx, i) {
              final tx = result.transactions[i];
              return CheckboxListTile(
                value: _selectedFlags[i],
                onChanged:
                    (v) => setState(() => _selectedFlags[i] = v ?? false),
                activeColor: AppColors.accent,
                title: Text(
                  tx.description,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${tx.date.day}.${tx.date.month}.${tx.date.year}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                secondary: Text(
                  '${tx.amount >= 0 ? '+' : ''}₺${tx.amount.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    color:
                        tx.amount >= 0 ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSaving || selectedCount == 0 ? null : _saveSelected,
              icon:
                  _isSaving
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.save_alt),
              label: Text(
                '$selectedCount İşlemi İçe Aktar',
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
        ),
      ],
    );
  }

  // ─── ADIM 4: TAMAMLANDI ───
  Widget _buildDoneStep() {
    final stats = _importStats;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.greenAccent,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              stats != null
                  ? '${stats.added} işlem eklendi'
                  : 'İşlemler eklendi',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (stats != null) ...[
              const SizedBox(height: 8),
              if (stats.skipped > 0)
                Text(
                  '${stats.skipped} işlem zaten mevcut (atlandı)',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (stats.errors > 0)
                Text(
                  '${stats.errors} satır okunamadı',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Eklenen işlemler Gemini tarafından analiz edilecek.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Dashboard\'a Dön'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickExcelFile() async {
    setState(() => _errorMessage = null);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) {
      setState(() => _errorMessage = 'Dosya okunamadı. Tekrar deneyin.');
      return;
    }

    // .xls veya .csv seçilirse (system picker bypass durumunda) hata göster
    final ext = file.extension?.toLowerCase() ?? '';
    if (ext != 'xlsx') {
      setState(
        () =>
            _errorMessage =
                'Yalnızca .xlsx dosyası desteklenmektedir. Lütfen Excel formatında (.xlsx) dışa aktarın.',
      );
      return;
    }

    setState(() => _step = _ImportStep.loading);

    try {
      final importResult = await _importService.importFromExcel(
        bytes: file.bytes!,
        onProgress: (p, s) {
          if (mounted)
            setState(() {
              _progress = p;
              _progressStatus = s;
            });
        },
      );

      if (mounted) {
        setState(() {
          _result = importResult;
          _selectedFlags = List.filled(importResult.transactions.length, true);
          _step = _ImportStep.preview;
        });
      }
    } on ImportException catch (e) {
      if (mounted)
        setState(() {
          _step = _ImportStep.selectFile;
          _errorMessage = e.message;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _step = _ImportStep.selectFile;
          _errorMessage = 'Beklenmedik hata: $e';
        });
    }
  }

  Future<void> _saveSelected() async {
    setState(() => _isSaving = true);
    final toSave = <Transaction>[];
    for (int i = 0; i < _result!.transactions.length; i++) {
      if (_selectedFlags[i]) toSave.add(_result!.transactions[i]);
    }

    try {
      final repo = ref.read(transactionRepositoryProvider);
      final stats = await repo.addBulk(toSave);

      ref.invalidate(allTransactionsProvider);
      ref.invalidate(currentMonthTransactionsProvider);
      ref.invalidate(monthlySpendingProvider);
      ref.invalidate(monthlySummaryProvider);

      if (mounted)
        setState(() {
          _importStats = stats;
          _step = _ImportStep.done;
        });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kaydedilemedi: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _FileTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FileTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
