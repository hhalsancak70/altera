// Emülatör/cihazda güvenilir API key depolama ayarları
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tüm uygulama genelinde kullanılan güvenli depolama instance'ı.
const appSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);
