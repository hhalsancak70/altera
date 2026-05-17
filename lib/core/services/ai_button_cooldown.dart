// AI butonlarına spam koruması — kullanıcı aynı butonu hızlı hızlı basamasın
import '../constants/app_constants.dart';

/// In-memory cooldown — uygulama kapanınca sıfırlanır.
/// Kalıcı limit için [ApiQuotaTracker] kullanılır.
class AiButtonCooldown {
  AiButtonCooldown._();

  static final _lastCallTimes = <String, DateTime>{};

  /// Buton şu an basılabilir mi? Basılabilirse zamanı kaydet.
  /// `key` her buton için benzersiz: 'chat', 'insight', 'budget_suggest' vb.
  static bool tryUse(String key) {
    final now = DateTime.now();
    final last = _lastCallTimes[key];
    if (last == null) {
      _lastCallTimes[key] = now;
      return true;
    }
    final elapsed = now.difference(last).inSeconds;
    if (elapsed >= AppConstants.kAiButtonCooldownSeconds) {
      _lastCallTimes[key] = now;
      return true;
    }
    return false;
  }

  /// Kalan cooldown süresi (saniye). 0 = hazır.
  static int remainingSeconds(String key) {
    final last = _lastCallTimes[key];
    if (last == null) return 0;
    final elapsed = DateTime.now().difference(last).inSeconds;
    final remaining = AppConstants.kAiButtonCooldownSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }
}
