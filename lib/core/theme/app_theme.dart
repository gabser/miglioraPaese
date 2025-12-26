import 'package:flutter/material.dart';
import 'package:goodtime/core/theme/app_tokens.dart';

/// Tema centralizzato basato su Material 3 e ColorScheme derivato da seed.
class AppTheme {
  const AppTheme._();

  /// Restituisce il tema chiaro dell'applicazione.
  static ThemeData light() {
    const seedColor = Colors.indigo;
    final colorScheme = ColorScheme.fromSeed(seedColor: seedColor);
    final baseTextTheme = Typography.material2021()
        .black
        .apply(bodyColor: colorScheme.onSurface, displayColor: colorScheme.onSurface);

    final baseChipTheme = ChipThemeData(
      labelStyle: baseTextTheme.labelLarge,
      side: BorderSide(color: colorScheme.outlineVariant),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.s12,
        vertical: AppTokens.s8 / 2,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      backgroundColor: colorScheme.surfaceVariant,
      selectedColor: colorScheme.primaryContainer,
      secondarySelectedColor: colorScheme.secondaryContainer,
      disabledColor: colorScheme.onSurface.withOpacity(0.12),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: baseTextTheme,
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: colorScheme.surfaceVariant,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radius),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s16,
            vertical: AppTokens.s12,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radius),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s16,
            vertical: AppTokens.s12,
          ),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      chipTheme: baseChipTheme,
    );
  }
}
