<div align="center">

# ALTERA

**Gemini 2.0 Flash destekli 3 otonom ajandan oluşan kişisel finans yönetim uygulaması**

[![Flutter](https://img.shields.io/badge/Flutter-3.29.3-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.7-0175C2?logo=dart)](https://dart.dev)
[![Gemini](https://img.shields.io/badge/Gemini-2.0_Flash-4285F4?logo=google)](https://ai.google.dev)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![BTK Hackathon](https://img.shields.io/badge/BTK_Akademi-Hackathon_2026-orange)](https://btkakademi.gov.tr)

> BTK Akademi × Google Hackathon 2026 — **ALTERA** harcamalarını analiz eder, bütçeni korur ve tasarruflarını otomatik olarak yatırıma yönlendirir.

</div>

---

## Nedir?

ALTERA, tamamen yerel çalışan (backend yok, sunucu yok) bir Flutter uygulamasıdır. Üç otonom ajan sürekli arka planda çalışır:

1. **Veri Toplama Ajanı** — Banka ve fatura kaynaklarından işlemleri çeker, veritabanına yazar
2. **Analiz Ajanı (Gemini)** — Her işlemi Gemini 2.0 Flash'a göndererek kategori ve ihtiyaç/istek sınıflandırması yapar
3. **Aksiyon Ajanı** — Bütçe uyarısı gönderir, harcama anomalisi yakalar, ay sonunda tasarrufları otomatik yatırıma yönlendirir

Tüm veriler cihazda kalır. API key bile şifreli olarak cihaz güvenli deposunda saklanır.

---

## Ekran Görüntüleri

| Dashboard | İşlemler | Bütçe |
|-----------|----------|-------|
| _Ana kontrol paneli, ajan durumu ve aylık özet_ | _Harcama listesi, Gemini kategorileri_ | _Bütçe limitleri ve kullanım çubukları_ |

| Yatırım | Ajan Log | Ayarlar |
|---------|----------|---------|
| _Fon önerileri ve simüle transfer_ | _Ajan kararları şeffaflık merkezi_ | _Profil, API key ve ajan ayarları_ |

---

## Mimari

```
┌─────────────────────────────────────────────────────────┐
│                      ORCHESTRATOR                        │
│           (LangGraph ilhamlı durum makinesi)            │
│  Idle → Collecting → Analyzing → Acting → Completed     │
└──────────┬──────────────┬──────────────┬────────────────┘
           │              │              │
    ┌──────▼──────┐ ┌─────▼──────┐ ┌────▼──────────┐
    │   Ajan 1    │ │   Ajan 2   │ │    Ajan 3     │
    │   Veri      │ │  Gemini    │ │   Aksiyon     │
    │  Toplama    │ │  Analiz    │ │  (Bütçe +     │
    │             │ │            │ │   Yatırım)    │
    └──────┬──────┘ └─────┬──────┘ └────┬──────────┘
           │              │              │
    ┌──────▼──────────────▼──────────────▼──────────┐
    │              SQLite (sqflite)                  │
    │   transactions · budgets · agent_logs          │
    │   investment_records                           │
    └────────────────────────────────────────────────┘
```

### Klasör Yapısı

```
lib/
├── core/
│   ├── agents/           # 3 otonom ajan + orchestrator
│   ├── constants/        # Renkler, sabitler
│   ├── database/         # SQLite (db_helper) + Hive (kutular)
│   ├── models/           # Transaction, Budget, AgentLog...
│   ├── providers.dart    # Tüm Riverpod provider'lar
│   └── services/         # Gemini, BankMock, Notification
├── features/
│   ├── dashboard/        # Ana panel + widget'lar
│   ├── transactions/     # İşlem listesi + filtreler
│   ├── budget/           # Bütçe yönetimi
│   ├── investments/      # Yatırım önerileri
│   ├── agent_log/        # Ajan şeffaflık ekranı
│   ├── settings/         # Kullanıcı ayarları
│   └── onboarding/       # İlk açılış sihirbazı
├── l10n/                 # TR + EN lokalizasyon
└── shared/
    ├── theme/            # AppTheme (dark/light)
    └── widgets/          # AlteraBottomNav, paylaşılan widget'lar
```

---

## Teknoloji Yığını

| Katman | Teknoloji |
|--------|-----------|
| Framework | Flutter 3.29.3 |
| Dil | Dart 3.7 |
| AI | Google Gemini 2.0 Flash (`google_generative_ai ^0.4.6`) |
| State Management | Riverpod 2.5 (`flutter_riverpod`) |
| Navigasyon | GoRouter 14 |
| Yerel Veritabanı | SQLite (`sqflite`) + Hive |
| Grafikler | fl_chart 0.69 |
| Bildirimler | flutter_local_notifications 17 |
| Güvenli Depolama | flutter_secure_storage 9 |
| Lokalizasyon | Flutter Gen (ARB) — TR + EN |

---

## Kurulum

### Gereksinimler

- Flutter SDK 3.29.3+
- Dart 3.7+
- Android SDK (minSdk 21) veya iOS 12+
- [Google AI Studio](https://aistudio.google.com) hesabı (ücretsiz Gemini API key)

### Adımlar

```bash
# 1. Repoyu klonla
git clone https://github.com/KULLANICI_ADIN/altera.git
cd altera

# 2. Bağımlılıkları yükle
flutter pub get

# 3. Lokalizasyon dosyalarını üret
flutter gen-l10n

# 4. Uygulamayı başlat
flutter run
```

İlk açılışta onboarding sihirbazı seni karşılar:
1. **Hoşgeldin** — Uygulama özeti
2. **API Key** — [Google AI Studio](https://aistudio.google.com)'dan aldığın ücretsiz Gemini API key'ini gir
3. **Profil** — Ad, aylık gelir ve risk profili seç

> API key cihazında şifreli olarak saklanır, hiçbir sunucuya gönderilmez.

---

## Nasıl Çalışır?

### Ajan Döngüsü

Dashboard'daki **"Ajan Döngüsü"** butonuna bastığında veya otomatik mod açıkken her 30 saniyede bir:

```
1. Veri Toplama Ajanı
   └── Banka mock servisinden yeni işlemleri çek
   └── Duplicate kontrolü yap, SQLite'a kaydet

2. Analiz Ajanı (Gemini 2.0 Flash)
   └── is_analyzed=0 olan işlemleri Gemini'ye gönder
   └── Kategori (market/restoran/ulaşım...) + Tür (ihtiyaç/istek/gelir) al
   └── SQLite'ı güncelle

3. Aksiyon Ajanı
   └── Bütçe %80 doluysa → uyarı bildirimi + Gemini öneri
   └── Bütçe aşıldıysa → tehlike bildirimi
   └── Bu hafta geçen haftadan %50 fazla harcandıysa → anomali uyarısı
   └── Ay sonu + 500 TL+ tasarruf varsa → Gemini fon seç → simüle transfer
```

### Gemini Entegrasyonu

Her işlem için Gemini'ye gönderilen prompt şablonu:
- İşlem açıklaması ve tutarı
- Mevcut kategori seçenekleri (enum olarak)
- Dönen cevap: JSON `{category, type, reason}`

Gemini yanıtı tutarsız metin içerse bile `_extractJson` helper'ı düzgün JSON'ı ayıklar.

---

## Özellikler

- **Offline-first**: Gemini API yoksa uygulama çökmez; işlemler `is_analyzed=0` olarak bekler
- **Şeffaf AI**: Her Gemini kararı "✨ Gemini Gerekçesi" ile gösterilir
- **Rate limiting**: Gemini API çağrıları arasında 200ms bekleme
- **Maksimum log**: 500 kayıt üzerinde otomatik temizlik
- **Güvenli API key**: `flutter_secure_storage` ile şifreli, kaynak kodda asla yok
- **Dark mode öncelikli**: Tam dark + light tema desteği
- **TR + EN**: Türkçe ve İngilizce lokalizasyon
- **Portrait-only**: iOS ve Android için optimize edilmiş

---

## Veri Gizliliği

ALTERA tamamen yerel çalışır:

| Veri | Nerede |
|------|--------|
| İşlemler, bütçeler, loglar | SQLite (cihaz) |
| Kullanıcı profili, ajan durumu | Hive (cihaz) |
| Gemini API key | flutter_secure_storage (şifreli) |
| Sunucu, bulut, analitik | **Yok** |

Sadece Gemini API çağrıları sırasında işlem verisi Google'ın Gemini API'sine gönderilir. Bu Gemini'nin kendi [gizlilik politikasına](https://policies.google.com/privacy) tabidir.

---

## Geliştirme

### Mock Veri

`assets/data/mock_transactions.json` içinde 39 gerçekçi Türk bankası işlemi vardır (Migros, Starbucks, İstanbulkart, ISKI, Netflix vs.). Demo için gerçek banka entegrasyonu gerekmez.

### Yeni Kategori Eklemek

1. `lib/core/models/transaction.dart` — `TransactionCategory` enum'una ekle
2. `lib/core/constants/app_colors.dart` — `categoryColors` map'ine renk ekle
3. `lib/l10n/app_tr.arb` + `app_en.arb` — lokalizasyon string'i ekle
4. `assets/data/mock_transactions.json` — örnek veri ekle (isteğe bağlı)

### Test

```bash
flutter test
flutter analyze
```

---

## Lisans

MIT © 2026 — Detaylar için [LICENSE](LICENSE) dosyasına bak.

---

<div align="center">

**BTK Akademi × Google Hackathon 2026**

*ALTERA — Paranı yönet, geleceğini planla.*

</div>
