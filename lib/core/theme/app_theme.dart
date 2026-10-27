import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static final ThemeData dark = _buildDarkTheme();

  static ThemeData _buildDarkTheme() {
    const primary = Color(0xFF9B8AFB);
    const background = Color(0xFF101116);
    const surface = Color(0xFF1C1D25);
    const textPrimary = Color(0xFFF5F5F7);
    const textSecondary = Color(0xFFA3A3AD);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: primary,
          onPrimary: background,
          surface: surface,
          onSurface: textPrimary,
          onSurfaceVariant: textSecondary,
        );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
    );

    return theme.copyWith(
      textTheme: theme.textTheme
          .apply(bodyColor: textPrimary, displayColor: textPrimary)
          .copyWith(
            bodySmall: theme.textTheme.bodySmall?.copyWith(
              color: textSecondary,
            ),
          ),
    );
  }
}
