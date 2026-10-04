import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class NexoTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: NexoColors.brand,
      onPrimary: NexoColors.onBrand,
      secondary: NexoColors.brand,
      onSecondary: NexoColors.onBrand,
      error: NexoColors.error,
      onError: NexoColors.onBrand,
      surface: NexoColors.surface,
      onSurface: NexoColors.onSurface,
      outline: NexoColors.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: NexoColors.background,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        // Saldos: tipografía grande y legible.
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: NexoColors.onSurface,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: const CardThemeData(
        color: NexoColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: NexoColors.border),
          borderRadius: BorderRadius.all(Radius.circular(NexoRadius.md)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(kMinTapTarget + 4),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(NexoRadius.sm)),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: NexoColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(NexoRadius.sm)),
        ),
      ),
    );
  }
}
