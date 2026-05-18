// ALTERA renk paleti - koyu, profesyonel finans uygulaması teması
import 'package:flutter/material.dart';

/// ALTERA uygulamasının tüm renk sabitlerini barındırır.
/// Hem dark hem light mode için MaterialColor tanımlamaları içerir.
class AppColors {
  AppColors._();

  // --- ANA RENKLER ---

  /// Derin lacivert - güven ve istikrar sembolü, birincil arka plan rengi
  static const Color primary = Color(0xFF0A1628);

  /// Elektrik mavisi - Gemini AI aksan rengi, interaktif öğeler
  static const Color accent = Color(0xFF00D4FF);

  /// Kart yüzey rengi - primary'den biraz açık, derinlik hissi verir
  static const Color surface = Color(0xFF111827);

  /// Koyu yüzey - modal ve drawer arka planı
  static const Color surfaceDark = Color(0xFF0D1520);

  /// Açık yüzey - input alanları ve chip'ler için
  static const Color surfaceLight = Color(0xFF1F2937);

  // --- DURUM RENKLERİ ---

  /// Pozitif bakiye, bütçe uyum göstergesi
  static const Color success = Color(0xFF10B981);

  /// Bütçe %80 doluluk uyarısı
  static const Color warning = Color(0xFFF59E0B);

  /// Bütçe aşımı, kritik durum
  static const Color danger = Color(0xFFEF4444);

  /// Bilgi rengi - nötr ajan log kayıtları
  static const Color info = Color(0xFF3B82F6);

  // --- METİN RENKLERİ ---

  /// Birincil metin rengi - başlıklar ve önemli içerik
  static const Color textPrimary = Color(0xFFF9FAFB);

  /// İkincil metin rengi - açıklamalar ve yardımcı bilgiler
  static const Color textSecondary = Color(0xFF9CA3AF);

  /// Üçüncül metin rengi - placeholder ve devre dışı öğeler
  static const Color textTertiary = Color(0xFF6B7280);

  // --- İŞLEM RENKLERİ ---

  /// Gelir işlemi rengi
  static const Color income = Color(0xFF10B981);

  /// Gider işlemi rengi
  static const Color expense = Color(0xFFEF4444);

  // --- KATEGORİ RENKLERİ ---
  static const Color categoryMarket = Color(0xFF10B981);
  static const Color categoryRestaurant = Color(0xFFF59E0B);
  static const Color categoryTransport = Color(0xFF3B82F6);
  static const Color categoryBill = Color(0xFF8B5CF6);
  static const Color categoryClothing = Color(0xFFEC4899);
  static const Color categoryEntertainment = Color(0xFF06B6D4);
  static const Color categoryHealth = Color(0xFFEF4444);
  static const Color categoryEducation = Color(0xFF84CC16);
  static const Color categoryInvestment = Color(0xFFF59E0B);
  static const Color categoryIncome = Color(0xFF10B981);
  static const Color categoryOther = Color(0xFF6B7280);

  // --- DARK TEMA MaterialColor SWATCH ---
  static const MaterialColor primarySwatch = MaterialColor(
    0xFF0A1628,
    <int, Color>{
      50: Color(0xFFE3E7EE),
      100: Color(0xFFB9C3D4),
      200: Color(0xFF8B9CB8),
      300: Color(0xFF5C749C),
      400: Color(0xFF395686),
      500: Color(0xFF0A1628),
      600: Color(0xFF091324),
      700: Color(0xFF07101E),
      800: Color(0xFF050D18),
      900: Color(0xFF03070F),
    },
  );

  // --- ACCENT MaterialColor SWATCH ---
  static const MaterialColor accentSwatch = MaterialColor(
    0xFF00D4FF,
    <int, Color>{
      50: Color(0xFFE0FAFF),
      100: Color(0xFFB3F3FF),
      200: Color(0xFF80ECFF),
      300: Color(0xFF4DE4FF),
      400: Color(0xFF26DEFF),
      500: Color(0xFF00D4FF),
      600: Color(0xFF00C2EF),
      700: Color(0xFF00AADB),
      800: Color(0xFF0093C8),
      900: Color(0xFF006FA7),
    },
  );

  /// Gradient - dashboard header için
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1628), Color(0xFF111827)],
  );

  /// Accent gradient - buton ve aktif öğeler için
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF00D4FF), Color(0xFF0EA5E9)],
  );
}
