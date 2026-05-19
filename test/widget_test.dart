// App smoke test — Hive ve platform plugin'leri gerektiren full widget testi
// device/emulator olmadan çalıştırılamaz; unit testler için ayrı dosyalara bakın.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Placeholder — tam entegrasyon testi için cihaz gerekir', () {
    // Full widget testi Hive, SQLite ve bildirim plugin'leri gerektirdiğinden
    // CI'da unit test dosyaları çalıştırılır: privacy_filter_test, transaction_model_test,
    // budget_test, gemini_service_test.
    expect(true, isTrue);
  });
}
