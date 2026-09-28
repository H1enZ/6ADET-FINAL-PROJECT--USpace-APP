import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The six-style type scale from docs/03-design-system.md.
/// Screens use these by name (Theme.of(context).textTheme.titleLarge),
/// never an inline fontSize.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(ColorScheme scheme) {
    return TextTheme(
      // Countdown numerals
      displayLarge: GoogleFonts.poppins(
          fontSize: 44, fontWeight: FontWeight.w700, height: 1.1),
      // Screen titles
      titleLarge: GoogleFonts.poppins(
          fontSize: 21, fontWeight: FontWeight.w700, height: 1.25),
      // Card titles, dialog headings
      titleMedium: GoogleFonts.poppins(
          fontSize: 15, fontWeight: FontWeight.w700, height: 1.3),
      // Button labels
      labelLarge: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
      // Default reading text
      bodyMedium: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w400, height: 1.45),
      // Text typed into inputs (Flutter's TextField reads bodyLarge)
      bodyLarge: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w400, height: 1.4),
      // Timestamps and small-caps labels. 10.5 is the floor.
      labelSmall: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          height: 1.3,
          letterSpacing: 0.8),
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }
}
