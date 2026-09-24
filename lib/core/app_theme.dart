import 'package:flutter/material.dart';
import 'app_colors.dart';

/// One place for the numbers every screen used to invent: corners, gaps, and
/// the type scale the HUD is built on. Sizes are logical pixels, so they hold
/// from a 320dp phone to a tablet.
class AppRadius {
  static const double chip = 12;
  static const double pill = 20;
  static const double card = 24;
}

class AppSpace {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 14;
  static const double l = 20;
  static const double xl = 28;

  /// Horizontal gutter every full-bleed screen shares.
  static const double screen = 20;
}

class AppType {
  static const String family = 'Rubik';

  static const TextStyle display = TextStyle(
    fontFamily: family,
    color: AppColors.textLight,
    fontSize: 26,
    fontWeight: FontWeight.w900,
    letterSpacing: 3,
  );

  static const TextStyle title = TextStyle(
    fontFamily: family,
    color: AppColors.textLight,
    fontSize: 18,
    fontWeight: FontWeight.w900,
    letterSpacing: 2,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: family,
    color: AppColors.textLight,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );

  static const TextStyle body = TextStyle(
    fontFamily: family,
    color: AppColors.textLight,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: family,
    color: AppColors.textLight,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  /// The big readouts: coins, level numbers, timers.
  static const TextStyle stat = TextStyle(
    fontFamily: family,
    color: AppColors.textLight,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.5,
  );
}

class AppTheme {
  static ThemeData get dark {
    const scaffoldBackground = AppColors.background;

    final textTheme = TextTheme(
      displayLarge: AppType.display,
      displayMedium: AppType.display,
      headlineMedium: AppType.title,
      titleLarge: AppType.title,
      titleMedium: AppType.subtitle,
      bodyLarge: AppType.body,
      bodyMedium: AppType.body,
      bodySmall: AppType.caption,
      labelLarge: AppType.subtitle,
    ).apply(fontFamily: AppType.family);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppType.family,
      scaffoldBackgroundColor: scaffoldBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryButton,
        brightness: Brightness.dark,
        surface: scaffoldBackground,
      ),
      textTheme: textTheme,
      // Every screen draws its own blurred background, so the chrome has to
      // stay out of the way instead of painting a second bar over it.
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppType.title,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardBackground,
        contentTextStyle: AppType.subtitle,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        titleTextStyle: AppType.title,
        contentTextStyle: AppType.body,
      ),
      // The board is tapped hundreds of times a session; the stock ink splash
      // reads as a grey flash over the liquid.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      dividerColor: AppColors.cardBorder,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }
}
