// Gemini API key okuma/yazma — tüm depolama yollarını tek yerden yönetir
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import 'secure_storage_config.dart';

/// Eski sürümlerde kullanılan varsayılan depolama (emülatör uyumluluğu).
const _legacySecureStorage = FlutterSecureStorage();

/// API key'i güvenli depodan okur; eski kayıtları yeni depoya taşır.
Future<String?> readGeminiApiKey() async {
  var key =
      await appSecureStorage.read(key: AppConstants.kSecureKeyGeminiApiKey);
  key = key?.trim();

  if (key != null && key.isNotEmpty) return key;

  // Önceki sürüm farklı Android ayarıyla kaydetmiş olabilir
  final legacy =
      await _legacySecureStorage.read(key: AppConstants.kSecureKeyGeminiApiKey);
  final legacyKey = legacy?.trim();
  if (legacyKey == null || legacyKey.isEmpty) return null;

  await appSecureStorage.write(
    key: AppConstants.kSecureKeyGeminiApiKey,
    value: legacyKey,
  );
  return legacyKey;
}

/// API key'i kaydeder ve okunarak doğrular.
Future<void> writeGeminiApiKey(String key) async {
  final trimmed = key.trim();
  await appSecureStorage.write(
    key: AppConstants.kSecureKeyGeminiApiKey,
    value: trimmed,
  );
  // Eski depoyu da güncelle — geri uyumluluk
  await _legacySecureStorage.write(
    key: AppConstants.kSecureKeyGeminiApiKey,
    value: trimmed,
  );
}

Future<bool> hasGeminiApiKey() async {
  final key = await readGeminiApiKey();
  return key != null && key.isNotEmpty;
}
