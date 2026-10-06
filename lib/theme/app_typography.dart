import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The USpace type scale, from docs/03-design-system.md.
///
/// Two families do the work: Playfair Display for major headings only
/// (countdowns, hero titles, the capsule reveal) and Inter for everything
/// else. Playfair never goes on labels, buttons, chips or body text.
/// Two expressive faces are reserved for one place each: Lora for letter
/// bodies (Love Notes, Time Capsules) and Caveat for Timeline handwriting.
///
/// Screens use the Material slots by name (textTheme.titleLarge), or the
/// helpers below for the expressive styles, never an inline fontSize.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(ColorScheme scheme) {
    return TextTheme(
      // Countdown numerals, the capsule reveal.
      displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 36, fontWeight: FontWeight.w600, height: 1.1),
      // Hero titles (Notes, Capsules, the Home mood word).
      headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 26, fontWeight: FontWeight.w600, height: 1.2),
      headlineSmall: GoogleFonts.playfairDisplay(
          fontSize: 22, fontWeight: FontWeight.w600, height: 1.2),
      // Screen and sheet titles.
      titleLarge: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, height: 1.3,
          letterSpacing: -0.2),
      // Card titles, dialog headings.
      titleMedium: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w600, height: 1.35),
      titleSmall: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, height: 1.35),
      // Button labels.
      labelLarge: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
      // Section labels and chips.
      labelMedium: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, height: 1.3,
          letterSpacing: 0.6),
      // Text typed into inputs and chat (TextField reads bodyLarge).
      bodyLarge: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w400, height: 1.5),
      // Default reading text.
      bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, height: 1.45),
      // Supporting text.
      bodySmall: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w400, height: 1.4),
      // Timestamps and captions. 11 is the floor.
      labelSmall: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w500, height: 1.3,
          letterSpacing: 0.4),
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }

  /// Playfair at a custom size, for major headings that need one.
  static TextStyle display(double size, {Color? color}) =>
      GoogleFonts.playfairDisplay(
          fontSize: size, fontWeight: FontWeight.w600, height: 1.15,
          color: color);

  /// Letter bodies: Love Notes and Time Capsules only.
  static TextStyle letter({Color? color, double size = 17}) =>
      GoogleFonts.lora(fontSize: size, height: 1.6, color: color);

  /// Handwriting: Timeline captions and tape labels only.
  static TextStyle hand({Color? color, double size = 20}) =>
      GoogleFonts.caveat(fontSize: size, height: 1.2, color: color);

  /// Pen script on parchment: Time Capsule letter bodies and sign-offs.
  static TextStyle capsuleHand({Color? color, double size = 22}) =>
      GoogleFonts.laBelleAurore(fontSize: size, height: 1.75, color: color);

  /// Pen script, lightly joined: Timeline month tags only.
  static TextStyle monthTag({Color? color, double size = 22}) =>
      GoogleFonts.laBelleAurore(fontSize: size, height: 1.25, color: color);
}
