# SQLCipher — JNI üzerinden erişilen alanlar R8 tarafından silinmemeli
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Hive
-keep class com.hivedb.** { *; }

# Google Generative AI
-keep class com.google.ai.** { *; }

# Google Play Core (Flutter deferred components — uygulamada kullanılmıyor)
-dontwarn com.google.android.play.core.**

# OkHttp / http
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
