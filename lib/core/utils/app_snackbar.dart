// Uygulama geneli snackbar — alt menünün üstünde, takılmadan kaybolur
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// [MaterialApp] scaffoldMessengerKey ile bağlanmalıdır.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Alt navigasyonun üzerinde kısa süreli bildirim gösterir.
void showAppSnackBar(
  String message, {
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor ?? AppColors.surfaceLight,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
    ),
  );
}
