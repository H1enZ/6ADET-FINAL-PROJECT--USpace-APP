import 'package:flutter/material.dart';

import 'us_palette.dart';

/// The USpace palette as Material 3 colour roles. USpace ships dark only
/// (main.dart pins ThemeMode.dark); the values live in UsPalette.
class AppColors {
  AppColors._();

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: UsPalette.rose,
    onPrimary: UsPalette.onRose,
    primaryContainer: Color(0xFF4A1F36), // selected pills, badges, nav pill
    onPrimaryContainer: UsPalette.blush,
    secondary: UsPalette.blush,
    onSecondary: UsPalette.onRose,
    secondaryContainer: Color(0xFF4A1F36),
    onSecondaryContainer: UsPalette.blush,
    tertiary: UsPalette.sage,
    onTertiary: Color(0xFF10261C),
    error: UsPalette.error,
    onError: Color(0xFF3A0A10),
    surface: UsPalette.ink,
    onSurface: UsPalette.cream,
    surfaceContainerLowest: UsPalette.ink,
    surfaceContainerLow: UsPalette.surface,
    surfaceContainer: UsPalette.surface,
    surfaceContainerHigh: UsPalette.card,
    surfaceContainerHighest: UsPalette.card, // cards, sheets, inputs
    onSurfaceVariant: UsPalette.muted,
    outline: UsPalette.line,
    outlineVariant: UsPalette.line,
  );
}
