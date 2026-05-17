// İlk açılış sihirbazı - 3 adım onboarding
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/hive_boxes.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers.dart';
import '../../core/utils/api_key_storage.dart';

/// İlk açılış sihirbazı (3 adım).
/// Adım 1: ALTERA'ya hoşgeldin
/// Adım 2: Gemini API key girişi
/// Adım 3: Risk profili seçimi + aylık gelir
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _apiKeyController = TextEditingController();
  final _nameController = TextEditingController();
  final _incomeController = TextEditingController();
  RiskProfile _selectedRisk = RiskProfile.balanced;

  @override
  void dispose() {
    _pageController.dispose();
    _apiKeyController.dispose();
    _nameController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // İlerleme göstergesi
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: List.generate(3, (i) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    height: 3,
                    decoration: BoxDecoration(
                      color: i <= _currentPage
                          ? AppColors.accent
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomePage(),
                  _ApiKeyPage(controller: _apiKeyController),
                  _ProfilePage(
                    nameController: _nameController,
                    incomeController: _incomeController,
                    selectedRisk: _selectedRisk,
                    onRiskChanged: (r) => setState(() => _selectedRisk = r),
                  ),
                ],
              ),
            ),

            // Navigasyon butonları
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                        setState(() => _currentPage--);
                      },
                      child: const Text('Geri'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _currentPage == 2 ? _finish : _nextPage,
                    child: Text(
                      _currentPage == 2 ? 'Başla!' : 'Devam',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage++);
  }

  Future<void> _finish() async {
    // API key kaydet
    if (_apiKeyController.text.isNotEmpty) {
      await writeGeminiApiKey(_apiKeyController.text);
    }

    // Kullanıcı profili oluştur
    final profile = UserProfile(
      id: const Uuid().v4(),
      name: _nameController.text.isEmpty ? 'Kullanıcı' : _nameController.text,
      riskProfile: _selectedRisk,
      monthlyIncome: double.tryParse(_incomeController.text) ?? 0.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final box = Hive.box<String>(HiveBoxes.userProfile);
    await box.put(AppConstants.kHiveKeyUserProfile, jsonEncode(profile.toJson()));

    ref.invalidate(userProfileProvider);
    ref.invalidate(geminiServiceProvider);

    if (mounted) context.go('/');
  }
}

class _WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: AppColors.primary,
              size: 52,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'ALTERA\'ya\nHoşgeldin!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Gemini 2.0 Flash destekli 3 otonom ajan seni finansal hedeflerine ulaştıracak.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 40),
          const _FeatureRow(icon: Icons.analytics_outlined, text: 'Harcamalarını otomatik kategorize eder'),
          const _FeatureRow(icon: Icons.account_balance_wallet_outlined, text: 'Bütçe aşımında uyarı ve öneri verir'),
          const _FeatureRow(icon: Icons.trending_up, text: 'Tasarruflarını yatırıma yönlendirir'),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiKeyPage extends StatelessWidget {
  final TextEditingController controller;

  const _ApiKeyPage({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.key_outlined, color: AppColors.accent, size: 40),
          const SizedBox(height: 16),
          const Text(
            'Gemini API Key',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ALTERA\'nın AI özelliklerini kullanmak için Google AI Studio\'dan ücretsiz API key almalısın.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'AIzaSy...',
              labelText: 'API Key',
              prefixIcon: Icon(Icons.vpn_key_outlined, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, color: AppColors.success, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'API key cihazında şifreli olarak saklanır, hiçbir sunucuya gönderilmez.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController incomeController;
  final RiskProfile selectedRisk;
  final ValueChanged<RiskProfile> onRiskChanged;

  const _ProfilePage({
    required this.nameController,
    required this.incomeController,
    required this.selectedRisk,
    required this.onRiskChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_outline, color: AppColors.accent, size: 40),
          const SizedBox(height: 16),
          const Text(
            'Profil Oluştur',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: nameController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Adın',
              labelText: 'Ad Soyad',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: incomeController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Aylık gelirin',
              labelText: 'Aylık Gelir (TL)',
              prefixText: '₺ ',
              prefixStyle: TextStyle(color: AppColors.accent),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Risk Profili',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...RiskProfile.values.map((rp) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => onRiskChanged(rp),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selectedRisk == rp
                          ? AppColors.accent.withValues(alpha: 0.1)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selectedRisk == rp
                            ? AppColors.accent
                            : const Color(0xFF1F2937),
                        width: selectedRisk == rp ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(rp.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rp.displayNameTr,
                                style: TextStyle(
                                  color: selectedRisk == rp
                                      ? AppColors.accent
                                      : AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                rp.descriptionTr,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selectedRisk == rp)
                          const Icon(Icons.check_circle,
                              color: AppColors.accent, size: 20),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
