import 'dart:async';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/redaction.dart';
import '../app.dart';
import '../providers/core_providers.dart';
import 'tray_service.dart';

/// Application entry point: window setup, crash handlers, provider scope.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logger = AppLogger();
  _installCrashHandlers(logger);

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Transikey',
      size: Size(1180, 760),
      minimumSize: Size(860, 560),
      center: true,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  // The macOS build runs without the App Sandbox (see README).
  await FilePicker.skipEntitlementsChecks();
  await TrayService.instance.init();

  runApp(
    ProviderScope(
      overrides: [loggerProvider.overrideWithValue(logger)],
      // Failed Vault calls must surface to the user, not retry silently.
      retry: (_, __) => null,
      child: const TransikeyApp(),
    ),
  );
}

/// Errors are redacted before they are logged. A future crash reporter must
/// receive [Redaction.crashReport] output only.
void _installCrashHandlers(AppLogger logger) {
  FlutterError.onError = (details) {
    logger.error(
      'flutter.error',
      error: Redaction.crashReport(details.exception),
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error(
      'platform.error',
      error: Redaction.crashReport(error),
      stackTrace: stack,
    );
    return true;
  };
}
