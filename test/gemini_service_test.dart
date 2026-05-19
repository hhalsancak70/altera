import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:altera/core/services/gemini_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock flutter_secure_storage'ı null döndürecek şekilde ayarla (key yok).
  // İOS/macOS kanalı: plugins.it_nomads.com/flutter_secure_storage
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  group('GeminiService.initialize', () {
    test('API key olmadan initialize GeminiException fırlatır', () async {
      await expectLater(
        GeminiService.initialize(),
        throwsA(isA<GeminiException>()),
      );
    });
  });

  group('GeminiService.withKey', () {
    test('Geçersiz key ile oluşturulan servis exception fırlatmaz', () {
      expect(() => GeminiService.withKey('fake-key'), returnsNormally);
    });
  });

  group('GeminiService.isRateLimitError', () {
    test('429 hata kodunu tanır', () {
      expect(
        GeminiService.isRateLimitError('Error: 429 Too Many Requests'),
        isTrue,
      );
    });

    test('quota exceeded tanır', () {
      expect(
        GeminiService.isRateLimitError('RESOURCE_EXHAUSTED quota exceeded'),
        isTrue,
      );
    });

    test('Normal hata mesajı rate limit değil', () {
      expect(
        GeminiService.isRateLimitError('Network connection failed'),
        isFalse,
      );
    });
  });
}
