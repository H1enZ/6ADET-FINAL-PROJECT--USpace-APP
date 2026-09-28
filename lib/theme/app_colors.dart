import 'package:flutter/material.dart';

/// The USpace palette as Material 3 colour roles.
/// Values come from docs/03-design-system.md.
class AppColors {
  AppColors._();

  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFC93A5F), // rose: buttons, active tab, countdown ring
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFF3D8DF), // blush: selected pill, chips, badges
    onPrimaryContainer: Color(0xFF2B2130),
    secondary: Color(0xFF4A2545), // plum: countdown card, headings
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFF3D8DF), // nav indicator uses this role
    onSecondaryContainer: Color(0xFF2B2130),
    tertiary: Color(0xFF4F7A67), // sage: done items, capsule ready to open
    onTertiary: Color(0xFFFFFFFF),
    error: Color(0xFFC6404F),
    onError: Color(0xFFFFFFFF),
    surface: Color(0xFFFFF8F5), // cream screen background
    onSurface: Color(0xFF2B2130),
    surfaceContainerHighest: Color(0xFFFFFFFF), // cards, sheets, inputs
    onSurfaceVariant: Color(0xFF7D6873), // timestamps, captions
    outline: Color(0xFFE2D6DC),
  );

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFF2708F),
    onPrimary: Color(0xFF3A0A19),
    primaryContainer: Color(0xFF5E2238),
    onPrimaryContainer: Color(0xFFFFD9E2),
    secondary: Color(0xFFE3BFD4),
    onSecondary: Color(0xFF2B1A28),
    secondaryContainer: Color(0xFF5E2238),
    onSecondaryContainer: Color(0xFFFFD9E2),
    tertiary: Color(0xFF7FBFA0),
    onTertiary: Color(0xFF10261C),
    error: Color(0xFFF2A0A6),
    onError: Color(0xFF3A0A10),
    surface: Color(0xFF17101A),
    onSurface: Color(0xFFF4EAEE),
    surfaceContainerHighest: Color(0xFF241A28),
    onSurfaceVariant: Color(0xFFC6AEBA),
    outline: Color(0xFF4A3A4F),
  );
}
