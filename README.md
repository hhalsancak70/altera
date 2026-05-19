<div align="center">

# ALTERA

**Gemini 2.0 Flash destekli 3 otonom ajandan oluşan kişisel finans yönetim uygulaması**

[![Flutter](https://img.shields.io/badge/Flutter-3.29.3-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.7-0175C2?logo=dart)](https://dart.dev)
[![Gemini](https://img.shields.io/badge/Gemini-2.0_Flash-4285F4?logo=google)](https://ai.google.dev)
[![BTK Hackathon](https://img.shields.io/badge/BTK_Akademi-Hackathon_2026-orange)](https://btkakademi.gov.tr)

> BTK Akademi × Google Hackathon 2026 — **ALTERA** harcamalarını analiz eder, bütçeni korur ve tasarruflarını otomatik olarak yatırıma yönlendirir.

</div>

> **Finansal Uyarı:** ALTERA bir yatırım danışmanlığı aracı değildir. Uygulama tarafından üretilen yatırım önerileri yalnızca bilgilendirme amaçlıdır; finansal tavsiye niteliği taşımaz. Kullanıcı onayı olmadan gerçek bir işlem gerçekleştirilmez. Yatırım kararlarınızı vermeden önce lisanslı bir finansal danışmana başvurunuz.

---

## Nedir?

ALTERA, tamamen yerel çalışan (backend yok, sunucu yok) bir Flutter uygulamasıdır. Uygulama açık olduğu sürece periyodik kontrol yapan üç ajan çalışır:

1. **Veri Toplama Ajanı** — Excel banka ekstresinden işlemleri içe aktarır, duplicate kontrolü yaparak AES-256 şifreli veritabanına yazar
2. **Analiz Ajanı (Gemini)** — Her işlemi Gemini 2.0 Flash'a göndererek kategori ve ihtiyaç/istek sınıflandırması yapar; kişisel veriler (IBAN, kart no, TC Kimlik, e-posta) gönderilmeden önce maskelenir
3. **Aksiyon Ajanı** — Bütçe uyarısı gönderir, harcama anomalisi yakalar, ay sonunda tasarrufları simüle yatırıma yönlendirir

Tüm veriler cihazda kalır. API key şifreli olarak cihaz güvenli deposunda saklanır ve kaynak kodda yer almaz.

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
│   ├── services/         # Gemini, Import, YahooFinance, Cycle, Notification
│   └── utils/            # Para parser (money_parser.dart) vb.
├── features/
│   ├── archive/          # Geçmiş ay istatistikleri
│   ├── budget/           # Bütçe yönetimi
│   ├── agent_log/        # Ajan şeffaflık ekranı
│   ├── dashboard/        # Ana panel + widget'lar
│   ├── import/           # Excel banka ekstresi içe aktarma (.xlsx)
│   ├── investments/      # Canlı piyasa verileri + Gemini yatırım önerileri
│   ├── onboarding/       # İlk açılış sihirbazı
│   ├── settings/         # Kullanıcı ayarları
│   └── transactions/     # İşlem listesi + filtreler + manuel ekleme
├── l10n/                 # Kısmi Türkçe arayüz (ARB tabanlı, tam lokalizasyon tamamlanmamış)
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

# 3. Uygulamayı başlat (debug)
flutter run
```

İlk açılışta onboarding sihirbazı seni karşılar:
1. **Hoşgeldin** — Uygulama özeti
2. **API Key** — [Google AI Studio](https://aistudio.google.com)'dan aldığın ücretsiz Gemini API key'ini gir
3. **Profil** — Ad, aylık gelir ve risk profili seç

> API key cihazında `flutter_secure_storage` ile şifreli olarak saklanır, hiçbir sunucuya gönderilmez ve kaynak kodda yer almaz.

---

## Release Signing (Android)

Release APK/AAB oluşturmak için `android/key.properties` dosyası gereklidir.
Bu dosya `.gitignore`'dadır ve repoya commit edilmez.

```properties
# android/key.properties (REPO'YA COMMIT ETMEYİN)
storePassword=<keystore_parolanız>
keyPassword=<anahtar_parolanız>
keyAlias=<anahtar_takma_adı>
storeFile=<keystore_dosyasının_mutlak_yolu>
```

Keystore oluşturmak için:
```bash
keytool -genkey -v -keystore altera-release.jks \
  -alias altera -keyalg RSA -keysize 2048 -validity 10000
```

> `key.properties` yoksa `flutter build apk --release` açık hata verir.
> `flutter run` ve `flutter build apk --debug` etkilenmez.

---

## Nasıl Çalışır?

### Ajan Döngüsü

Dashboard'daki **"Ajan Döngüsü"** butonuna bastığında veya otomatik mod açıkken her 5 dakikada bir (uygulama ön planda olduğu sürece):

```
1. Veri Toplama Ajanı
   └── Manuel eklenen veya import edilen yeni işlemleri topla
   └── Duplicate fingerprint kontrolü yap, AES-256 şifreli SQLite'a kaydet

2. Analiz Ajanı (Gemini 2.0 Flash)
   └── is_analyzed=0 olan işlemleri al
   └── PrivacyFilter ile IBAN/kart/TC/e-posta maskeleme uygula
   └── Kategori (market/restoran/ulaşım...) + Tür (ihtiyaç/istek/gelir) al
   └── SQLite'ı güncelle

3. Aksiyon Ajanı
   └── Bütçe %80 doluysa → uyarı bildirimi + Gemini öneri
   └── Bütçe aşıldıysa → tehlike bildirimi
   └── Bu hafta geçen haftadan %50 fazla harcandıysa → anomali uyarısı
   └── Ay sonu + 500 TL+ tasarruf varsa → Gemini fon seç → simüle transfer
```

> Ajanlar yalnızca uygulama açık ve ön plandayken çalışır; gerçek bir arka plan servisi yoktur.

### Aylık Döngü (CycleService)

Uygulama her açılışında döngü kontrolü yapılır. Kullanıcının seçtiği gün (1–28) geldiğinde:
1. Geçen ayın istatistikleri `monthly_archives` tablosuna kalıcı olarak arşivlenir
2. İşlem yoksa arşiv oluşturulmaz
3. Kullanıcıya özet bildirimi gönderilir

### İçe Aktarma (ImportService)

Excel banka ekstresini uygulamaya aktarmak için:
- `features/import/` ekranından `.xlsx` dosyası seç (maks 20 MB)
- Başlık satırı otomatik algılanır (Tarih + Tutar/Borç/Alacak sütunları)
- Borç/Alacak (Debit/Credit) ayrı sütunlu formatlar desteklenir
- Parse edilen işlemler `is_analyzed=0` olarak kaydedilir; Gemini analizine girer
- Import sonucu: okunan satır / eklenen / duplicate atlanan / hatalı satır
- Aynı dosya iki kez import edilirse duplicate kayıt oluşmaz (fingerprint kontrolü)

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

### Gemini Entegrasyonu

Her işlem için Gemini'ye gönderilmeden önce `PrivacyFilter` devreye girer:
- IBAN → `[IBAN]`
- 16 haneli kart numarası → `[KART]`
- Türk telefon numarası → `[TEL]`
- TC Kimlik No → `[TCKN]`
- E-posta → `[EMAIL]`

Ardından Gemini'ye gönderilen prompt: işlem açıklaması (maks 100 karakter, temizlenmiş) + mutlak tutar.
Dönen cevap: `{category, type, reason}` JSON. `_extractJson` helper'ı tutarsız metni de ayrıştırır.

---

## Özellikler

- **Offline-first**: Gemini API yoksa uygulama çökmez; işlemler `is_analyzed=0` olarak bekler
- **Şifreli veritabanı**: AES-256 ile SQLite — cihaz çalınsa bile veri okunamaz
- **Gizlilik filtresi**: IBAN, kart no, TC Kimlik, e-posta Gemini'ye asla gönderilmez
- **Şeffaf AI**: Her Gemini kararı "Gemini Gerekçesi" ile gösterilir
- **Banka ekstresi içe aktarma**: `.xlsx` dosyasından işlem aktarımı; Borç/Alacak sütunlu formatlar dahil
- **Türkçe para formatı**: `12,50` ve `1.234,56` formatları import ve manuel girişte desteklenir
- **Duplicate koruması**: Aynı dosyanın iki kez import edilmesi duplicate kayıt oluşturmaz
- **Canlı piyasa**: Yahoo Finance üzerinden altın, döviz, kripto ve BIST hisse fiyatları
- **Aylık arşiv**: Her ay kapanışında otomatik istatistik arşivleme (işlem yoksa arşiv oluşmaz)
- **Bildirimler**: Bütçe uyarısı, portföy hareketleri, ajan özeti (Android 13+ izni otomatik istenir)
- **Rate limiting**: Gemini API çağrıları arasında bekleme + retry mantığı
- **Maksimum log**: 500 kayıt üzerinde otomatik temizlik
- **Güvenli API key**: `flutter_secure_storage` ile şifreli — kaynak kodda asla yer almaz
- **Dark mode öncelikli**: Tam dark + light tema desteği
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

### Test

```bash
flutter test
flutter analyze
```

### Yeni Kategori Eklemek

1. [lib/core/models/transaction.dart](lib/core/models/transaction.dart) — `TransactionCategory` enum'una ekle
2. [lib/core/constants/app_colors.dart](lib/core/constants/app_colors.dart) — `categoryColors` map'ine renk ekle

---

## Yasal Uyarı

> **ALTERA bir yatırım danışmanlığı aracı değildir.** Uygulama tarafından üretilen yatırım önerileri yalnızca bilgilendirme amaçlıdır; finansal tavsiye niteliği taşımaz. Kullanıcı onayı olmadan gerçek bir al/sat işlemi gerçekleştirilmez. Yatırım kararlarınızı vermeden önce lisanslı bir finansal danışmana başvurunuz.

---

<div align="center">

**BTK Akademi × Google Hackathon 2026**

*ALTERA — Paranı yönet, geleceğini planla.*

</div>
