// Kullanıcı ayarları ekranı
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/hive_boxes.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers.dart';

/// Kullanıcı ayarları ekranı.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _nameController = TextEditingController();
  final _incomeController = TextEditingController();
  bool _apiKeyVisible = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentValues();
  }

  Future<void> _loadCurrentValues() async {
    const storage = FlutterSecureStorage();
    final key = await storage.read(key: AppConstants.kSecureKeyGeminiApiKey);
    if (key != null) {
      _apiKeyController.text = key;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _nameController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Ayarlar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: profileAsync.when(
        data:
            (profile) => ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // Profil bölümü
                _SectionTitle(title: 'Profil'),
                _SettingsCard(
                  children: [
                    _EditableItem(
                      label: 'Adın',
                      value: profile.name,
                      onEdit: () => _editName(context, profile),
                    ),
                    const _Separator(),
                    _EditableItem(
                      label: 'Aylık Gelir',
                      value: '₺${profile.monthlyIncome.toStringAsFixed(0)}',
                      onEdit: () => _editIncome(context, profile),
                    ),
                  ],
                ),

                // Risk profili
                _SectionTitle(title: 'Risk Profili'),
                _SettingsCard(
                  children:
                      RiskProfile.values
                          .map(
                            (rp) => _RiskProfileOption(
                              profile: rp,
                              isSelected: profile.riskProfile == rp,
                              onSelect: () => _updateRiskProfile(profile, rp),
                            ),
                          )
                          .toList(),
                ),

                // Gemini API
                _SectionTitle(title: 'Gemini API'),
                _SettingsCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'API Key',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _apiKeyController,
                            obscureText: !_apiKeyVisible,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'AIza...',
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _apiKeyVisible
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: AppColors.textSecondary,
                                      size: 18,
                                    ),
                                    onPressed:
                                        () => setState(
                                          () =>
                                              _apiKeyVisible = !_apiKeyVisible,
                                        ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.save_outlined,
                                      color: AppColors.accent,
                                      size: 18,
                                    ),
                                    onPressed: _saveApiKey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'API key Google AI Studio\'dan alınabilir.\nUygulama içinde güvenli olarak saklanır.',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Ajan ayarları
                _SectionTitle(title: 'Ajan'),
                _SettingsCard(
                  children: [
                    _ToggleItem(
                      label: 'Otomatik Ajan Döngüsü',
                      subtitle: 'Her 5 dakikada bir çalışır',
                      value:
                          ref
                              .watch(orchestratorProvider.notifier)
                              .isAutoModeActive,
                      onChanged: (v) {
                        if (v) {
                          ref
                              .read(orchestratorProvider.notifier)
                              .startAutoMode();
                        } else {
                          ref
                              .read(orchestratorProvider.notifier)
                              .stopAutoMode();
                        }
                        setState(() {});
                      },
                    ),
                  ],
                ),

                // Veri yönetimi
                _SectionTitle(title: 'Veri'),
                _SettingsCard(
                  children: [
                    _ActionItem(
                      label: 'Ekstre İçe Aktar',
                      icon: Icons.upload_file_outlined,
                      color: AppColors.accent,
                      onTap: () => context.push('/import'),
                    ),
                    const _Separator(),
                    _ActionItem(
                      label: 'Geçmiş Ayları Görüntüle',
                      icon: Icons.archive_outlined,
                      color: AppColors.accent,
                      onTap: () => context.push('/archive'),
                    ),
                    const _Separator(),
                    _ActionItem(
                      label: 'Tüm Verileri Sıfırla',
                      icon: Icons.delete_forever,
                      color: AppColors.danger,
                      onTap: () => _resetAllData(context),
                    ),
                  ],
                ),

                // Hakkında
                _SectionTitle(title: 'Hakkında'),
                _SettingsCard(
                  children: [
                    _InfoItem(label: 'Uygulama', value: 'ALTERA v1.0.0'),
                    const _Separator(),
                    _InfoItem(label: 'AI', value: 'Gemini 2.0 Flash'),
                    const _Separator(),
                    _InfoItem(label: 'Etkinlik', value: 'BTK Hackathon 2026'),
                  ],
                ),
              ],
            ),
        loading:
            () => const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
        error:
            (_, __) => const Center(
              child: Text(
                'Profil yüklenemedi',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
      ),
    );
  }

  Future<void> _saveApiKey() async {
    // Non-printable karakterleri (ANSI escape, terminal prompt vs.) temizle
    final clean =
        _apiKeyController.text.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();
    const storage = FlutterSecureStorage();
    await storage.write(key: AppConstants.kSecureKeyGeminiApiKey, value: clean);
    ref.invalidate(geminiServiceProvider);
    ref.invalidate(portfolioInsightsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Key kaydedildi'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _updateRiskProfile(UserProfile current, RiskProfile rp) async {
    final updated = current.copyWith(
      riskProfile: rp,
      updatedAt: DateTime.now(),
    );
    final box = Hive.box<String>(HiveBoxes.userProfile);
    await box.put(
      AppConstants.kHiveKeyUserProfile,
      jsonEncode(updated.toJson()),
    );
    ref.invalidate(userProfileProvider);
  }

  Future<void> _editName(BuildContext context, UserProfile profile) async {
    _nameController.text = profile.name;
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'Adını Düzenle',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: TextField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Adın'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, _nameController.text),
                child: const Text('Kaydet'),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      final updated = profile.copyWith(name: result, updatedAt: DateTime.now());
      final box = Hive.box<String>(HiveBoxes.userProfile);
      await box.put(
        AppConstants.kHiveKeyUserProfile,
        jsonEncode(updated.toJson()),
      );
      ref.invalidate(userProfileProvider);
    }
  }

  Future<void> _editIncome(BuildContext context, UserProfile profile) async {
    _incomeController.text = profile.monthlyIncome.toStringAsFixed(0);
    final result = await showDialog<double>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'Aylık Gelir',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: TextField(
              controller: _incomeController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Aylık gelir (TL)',
                prefixText: '₺ ',
                prefixStyle: TextStyle(color: AppColors.accent),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed:
                    () => Navigator.pop(
                      ctx,
                      double.tryParse(_incomeController.text),
                    ),
                child: const Text('Kaydet'),
              ),
            ],
          ),
    );

    if (result != null) {
      final updated = profile.copyWith(
        monthlyIncome: result,
        updatedAt: DateTime.now(),
      );
      final box = Hive.box<String>(HiveBoxes.userProfile);
      await box.put(
        AppConstants.kHiveKeyUserProfile,
        jsonEncode(updated.toJson()),
      );
      ref.invalidate(userProfileProvider);
    }
  }

  Future<void> _resetAllData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'Tüm Verileri Sıfırla',
              style: TextStyle(color: AppColors.danger),
            ),
            content: const Text(
              'İşlemler, bütçeler ve ajan logları silinecek. Bu işlem geri alınamaz.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                child: const Text('Sıfırla'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      // Messenger'ı async gap öncesinde yakala
      final messenger = ScaffoldMessenger.of(context);
      await ref.read(dbHelperProvider).clearAllData();
      ref.invalidate(currentMonthTransactionsProvider);
      ref.invalidate(recentAgentLogsProvider);
      ref.invalidate(currentMonthBudgetsProvider);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Tüm veriler sıfırlandı'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────
// YARDIMCI WIDGET'LAR
// ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1F2937), width: 1),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFF1F2937),
      indent: 16,
    );
  }
}

class _EditableItem extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onEdit;

  const _EditableItem({
    required this.label,
    required this.value,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textTertiary,
            size: 18,
          ),
        ],
      ),
      onTap: onEdit,
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      ),
      trailing: Text(
        value,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleItem({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(
        label,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.accent,
    );
  }
}

class _ActionItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _RiskProfileOption extends StatelessWidget {
  final RiskProfile profile;
  final bool isSelected;
  final VoidCallback onSelect;

  const _RiskProfileOption({
    required this.profile,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(profile.emoji, style: const TextStyle(fontSize: 22)),
      title: Text(
        profile.displayNameTr,
        style: TextStyle(
          color: isSelected ? AppColors.accent : AppColors.textPrimary,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: Text(
        profile.descriptionTr,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
      ),
      trailing:
          isSelected
              ? const Icon(
                Icons.check_circle,
                color: AppColors.accent,
                size: 20,
              )
              : null,
      onTap: onSelect,
    );
  }
}
