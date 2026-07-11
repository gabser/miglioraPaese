import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

/// Tema centralizzato basato sul mockup civic game moderno.
class AppTheme {
  const AppTheme._();

  /// Restituisce il tema chiaro dell'applicazione.
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppTokens.blue,
      onPrimary: Colors.white,
      primaryContainer: AppTokens.blueSoft,
      onPrimaryContainer: AppTokens.navy,
      secondary: AppTokens.success,
      onSecondary: Colors.white,
      secondaryContainer: AppTokens.successSoft,
      onSecondaryContainer: Color(0xFF0F6E48),
      tertiary: AppTokens.warning,
      onTertiary: Colors.white,
      tertiaryContainer: AppTokens.warningSoft,
      onTertiaryContainer: Color(0xFF7A5600),
      error: AppTokens.danger,
      onError: Colors.white,
      errorContainer: AppTokens.dangerSoft,
      onErrorContainer: Color(0xFF8A281C),
      background: AppTokens.appBackground,
      onBackground: AppTokens.ink,
      surface: AppTokens.surface,
      onSurface: AppTokens.ink,
      surfaceVariant: Color(0xFFF0F3F8),
      onSurfaceVariant: AppTokens.muted,
      outline: Color(0xFFD5DAE4),
      outlineVariant: AppTokens.line,
      shadow: Color(0xFF122044),
      scrim: Color(0xFF122044),
      inverseSurface: AppTokens.navyDark,
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFF9FC0FF),
      surfaceTint: AppTokens.blue,
    );
    final baseTextTheme = Typography.material2021().black.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
      fontFamily: 'Roboto',
    );
    final textTheme = baseTextTheme.copyWith(
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.08,
        letterSpacing: 0,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.12,
        letterSpacing: 0,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.35,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.1,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.1,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.1,
      ),
    );

    final baseChipTheme = ChipThemeData(
      labelStyle: baseTextTheme.labelLarge,
      side: BorderSide(color: colorScheme.outlineVariant),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.s12,
        vertical: AppTokens.s8 / 2,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primaryContainer,
      secondarySelectedColor: colorScheme.secondaryContainer,
      disabledColor: colorScheme.onSurface.withOpacity(0.12),
    );

    const transitionsBuilder = _AppPageTransitionsBuilder();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.background,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      scaffoldBackgroundColor: colorScheme.background,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: MaterialStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            fontWeight: states.contains(MaterialState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(MaterialState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        selectedIconTheme: const IconThemeData(color: AppTokens.blue),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s16,
          vertical: AppTokens.s12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
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
            borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s16,
            vertical: AppTokens.s12,
          ),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s16,
            vertical: AppTokens.s12,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith(
            (states) => states.contains(MaterialState.selected)
                ? colorScheme.primaryContainer
                : colorScheme.surface,
          ),
          foregroundColor: MaterialStateProperty.resolveWith(
            (states) => states.contains(MaterialState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          side: MaterialStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(MaterialState.selected)
                  ? colorScheme.primary.withOpacity(0.45)
                  : colorScheme.outlineVariant,
            ),
          ),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
            ),
          ),
        ),
      ),
      chipTheme: baseChipTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: transitionsBuilder,
          TargetPlatform.iOS: transitionsBuilder,
          TargetPlatform.linux: transitionsBuilder,
          TargetPlatform.macOS: transitionsBuilder,
          TargetPlatform.windows: transitionsBuilder,
          TargetPlatform.fuchsia: transitionsBuilder,
        },
      ),
    );
  }
}

class _AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const _AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fadeAnimation = animation.drive(
      CurveTween(curve: AppMotion.standard),
    );

    final offsetAnimation = animation.drive(
      Tween<Offset>(
        begin: const Offset(0, 0.025),
        end: Offset.zero,
      ).chain(CurveTween(curve: AppMotion.standard)),
    );

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(position: offsetAnimation, child: child),
    );
  }
}
