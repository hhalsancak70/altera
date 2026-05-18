// Hive yerel veritabanı kutu tanımlamaları ve başlatma
import 'package:hive_flutter/hive_flutter.dart';

/// Hive kutu isimlerini tutan sabitler.
/// Tüm uygulama genelinde bu sabitler kullanılmalıdır.
class HiveBoxes {
  HiveBoxes._();

  /// Kullanıcı profili kutusu (UserProfile JSON)
  static const String userProfile = 'user_profile';

  /// Uygulama ayarları (tema, dil, bildirim tercihleri)
  static const String settings = 'settings';

  /// Orchestrator durum bilgisi (son çalışma zamanı, otomatik mod)
  static const String agentState = 'agent_state';
}

/// Hive'ı başlatan ve kutularını açan yardımcı fonksiyon.
/// main() içinde WidgetsFlutterBinding'den sonra çağrılır.
Future<void> initHive() async {
  await Hive.initFlutter();
  await Hive.openBox<String>(HiveBoxes.userProfile);
  await Hive.openBox<dynamic>(HiveBoxes.settings);
  await Hive.openBox<String>(HiveBoxes.agentState);
}
