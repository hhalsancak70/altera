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

1. **Veri Toplama Ajanı** — Banka ve fatura kaynaklarından işlemleri çeker, AES-256 şifreli veritabanına yazar
2. **Analiz Ajanı (Gemini)** — Her işlemi Gemini 2.0 Flash'a göndererek kategori ve ihtiyaç/istek sınıflandırması yapar; kişisel veriler (IBAN, kart no, TC Kimlik) gönderilmeden önce maskelenir
3. **Aksiyon Ajanı** — Bütçe uyarısı gönderir, harcama anomalisi yakalar, ay sonunda tasarrufları otomatik yatırıma yönlendirir

Tüm veriler cihazda kalır. API key bile şifreli olarak cihaz güvenli deposunda saklanır.

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
    │        SQLite — sqflite_sqlcipher (AES-256)    │
    │   transactions · budgets · agent_logs          │
    │   investment_records · monthly_archives        │
    └────────────────────────────────────────────────┘
```

### Klasör Yapısı

```
lib/
├── core/
│   ├── agents/           # 3 otonom ajan + orchestrator
│   ├── constants/        # Renkler, sabitler
│   ├── database/         # SQLite (db_helper) + Hive (kutular)
│   ├── errors/           # Uygulama exception sınıfları
│   ├── models/           # Transaction, Budget, AgentLog, MonthlyArchive...
│   ├── providers.dart    # Tüm Riverpod provider'lar
│   ├── repositories/     # Veri erişim katmanı (TransactionRepository)
│   ├── security/         # PrivacyFilter — Gemini'ye gitmeden önce kişisel veri maskeleme
│   └── services/         # Gemini, BankMock, Import, YahooFinance, Cycle, Notification
├── features/
│   ├── archive/          # Geçmiş ay istatistikleri
│   ├── budget/           # Bütçe yönetimi
│   ├── agent_log/        # Ajan şeffaflık ekranı
│   ├── dashboard/        # Ana panel + widget'lar
│   ├── import/           # Excel / PDF banka ekstresi içe aktarma
│   ├── investments/      # Canlı piyasa verileri + Gemini yatırım önerileri
│   ├── onboarding/       # İlk açılış sihirbazı
│   ├── settings/         # Kullanıcı ayarları
│   └── transactions/     # İşlem listesi + filtreler + manuel ekleme
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
| Yerel Veritabanı | SQLite AES-256 (`sqflite_sqlcipher`) + Hive |
| Piyasa Verileri | Yahoo Finance v8 API (`http`) |
| Dosya İçe Aktarma | `file_picker` + `excel` (xlsx parse) |
| Grafikler | fl_chart 0.69 |
| Animasyon | Lottie + Shimmer |
| Bildirimler | flutter_local_notifications 17 |
| Güvenli Depolama | flutter_secure_storage 9 |
| Lokalizasyon | Flutter Gen (ARB) — TR + EN |

---

## Kurulum

### Gereksinimler

- Flutter SDK 3.29.3+
- Dart 3.7+
- Android SDK (minSdk 21)
- [Google AI Studio](https://aistudio.google.com) hesabı (ücretsiz Gemini API key)

### Adımlar

```bash
# 1. Repoyu klonla
git clone https://github.com/hhalsancak70/altera.git
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
   └── Duplicate kontrolü yap, AES-256 şifreli SQLite'a kaydet

2. Analiz Ajanı (Gemini 2.0 Flash)
   └── is_analyzed=0 olan işlemleri al
   └── PrivacyFilter ile IBAN/kart/TC maskeleme uygula
   └── Kategori (market/restoran/ulaşım...) + Tür (ihtiyaç/istek/gelir) al
   └── SQLite'ı güncelle

3. Aksiyon Ajanı
   └── Bütçe %80 doluysa → uyarı bildirimi + Gemini öneri
   └── Bütçe aşıldıysa → tehlike bildirimi
   └── Bu hafta geçen haftadan %50 fazla harcandıysa → anomali uyarısı
   └── Ay sonu + 500 TL+ tasarruf varsa → Gemini fon seç → simüle transfer
```

### Aylık Döngü (CycleService)

Uygulama her açılışında döngü kontrolü yapılır. Kullanıcının seçtiği gün (1–28) geldiğinde:
1. Geçen ayın istatistikleri `monthly_archives` tablosuna kalıcı olarak arşivlenir
2. Bütçe harcama sayaçları sıfırlanır (limitler korunur)
3. Kullanıcıya özet bildirimi gönderilir

### İçe Aktarma (ImportService)

Excel banka ekstresini uygulamaya aktarmak için:
- `features/import/` ekranından `.xlsx` dosyası seç
- Başlık satırı (Tarih, Açıklama, Tutar) otomatik algılanır
- Ziraat, Garanti, İş Bankası, Akbank, Yapı Kredi ve generic format desteklenir
- Parse edilen işlemler `is_analyzed=0` olarak kaydedilir; Gemini analizine girer

### Canlı Piyasa Verileri (YahooFinanceService)

Yatırım ekranında Yahoo Finance v8 API üzerinden anlık fiyatlar çekilir:

| Varlık | Sembol |
|--------|--------|
| Altın (Gram) | `GC=F` |
| Döviz (USD/TRY) | `TRY=X` |
| Bitcoin | `BTC-USD` |
| Ethereum | `ETH-USD` |
| Borsa İstanbul 100 | `XU100.IS` |
| S&P 500 ETF | `SPY` |
| Gümüş | `SI=F` |
| Euro/TRY | `EURTRY=X` |

Gemini, kullanıcı profiline ve mevcut tasarruf miktarına göre bu varlıklar arasından öneri üretir.

### Gemini Entegrasyonu

Her işlem için Gemini'ye gönderilmeden önce `PrivacyFilter` devreye girer:
- IBAN → `[IBAN]`
- 16 haneli kart numarası → `[KART]`
- Türk telefon numarası → `[TEL]`
- TC Kimlik No → `[TCKN]`

Ardından Gemini'ye gönderilen prompt: işlem açıklaması (maks 100 karakter, temizlenmiş) + mutlak tutar.  
Dönen cevap: `{category, type, reason}` JSON. `_extractJson` helper'ı tutarsız metni de ayrıştırır.

---

## Özellikler

- **Offline-first**: Gemini API yoksa uygulama çökmez; işlemler `is_analyzed=0` olarak bekler
- **Şifreli veritabanı**: AES-256 ile SQLite — cihaz çalınsa bile veri okunamaz
- **Gizlilik filtresi**: IBAN, kart no, TC Kimlik Gemini'ye asla gönderilmez
- **Şeffaf AI**: Her Gemini kararı "✨ Gemini Gerekçesi" ile gösterilir
- **Banka ekstresi içe aktarma**: `.xlsx` dosyasından işlem aktarımı (Ziraat, Garanti, İş, Akbank, Yapı Kredi)
- **Canlı piyasa**: Yahoo Finance üzerinden altın, döviz, kripto ve BIST hisse fiyatları
- **Aylık arşiv**: Her ay kapanışında otomatik istatistik arşivleme
- **Rate limiting**: Gemini API çağrıları arasında 200ms bekleme
- **Maksimum log**: 500 kayıt üzerinde otomatik temizlik
- **Güvenli API key**: `flutter_secure_storage` ile şifreli, kaynak kodda asla yok
- **Dark mode öncelikli**: Tam dark + light tema desteği
- **TR + EN**: Türkçe ve İngilizce lokalizasyon
- **Portrait-only**: Android için optimize edilmiş

---

## Veri Gizliliği

ALTERA tamamen yerel çalışır:

| Veri | Nerede |
|------|--------|
| İşlemler, bütçeler, loglar, arşivler | SQLite AES-256 (cihaz) |
| Kullanıcı profili, ajan durumu | Hive (cihaz) |
| Gemini API key | flutter_secure_storage (şifreli) |
| Sunucu, bulut, analitik | **Yok** |

Gemini API çağrıları sırasında **yalnızca maskelenmiş** işlem açıklaması ve mutlak tutar gönderilir. Bu veriler Gemini'nin kendi [gizlilik politikasına](https://policies.google.com/privacy) tabidir.

---

## Geliştirme

### Mock Veri

`assets/data/mock_transactions.json` içinde gerçekçi Türk bankası işlemleri vardır (Migros, Starbucks, İstanbulkart, ISKI, Netflix vs.). Demo için gerçek banka entegrasyonu veya dosya yükleme gerekmez.

### Yeni Kategori Eklemek

1. [lib/core/models/transaction.dart](lib/core/models/transaction.dart) — `TransactionCategory` enum'una ekle
2. [lib/core/constants/app_colors.dart](lib/core/constants/app_colors.dart) — `categoryColors` map'ine renk ekle
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
