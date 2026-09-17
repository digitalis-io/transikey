import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF1F6FEB);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.compact,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}

/// Lease and connection status colours. Fixed hues so that green / yellow /
/// red keep their meaning in both themes.
abstract final class StatusColors {
  static const active = Color(0xFF2DA44E);
  static const expiringSoon = Color(0xFFD4A72C);
  static const expired = Color(0xFFCF222E);
  static const unknown = Color(0xFF8C959F);
}
