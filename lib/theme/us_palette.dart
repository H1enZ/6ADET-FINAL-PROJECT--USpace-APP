import 'package:flutter/material.dart';

/// The one USpace palette. Every colour a screen or painter needs comes from
/// here (or from the ColorScheme built from it in AppColors), so a change to
/// the brand is a change to this file only. Values and contrast ratios are
/// recorded in docs/03-design-system.md.
class UsPalette {
  UsPalette._();

  // Backgrounds, darkest to lightest.
  /// Screen background: near-black plum.
  static const ink = Color(0xFF140C14);

  /// Sections, the nav bar, quiet cards.
  static const surface = Color(0xFF1E1320);

  /// Cards, sheets, inputs.
  static const card = Color(0xFF2A1426);

  /// Selected or raised cards.
  static const cardRaised = Color(0xFF34182F);

  // Accents.
  /// Primary actions, active nav, links. Dusty rose: 8.7:1 on [ink].
  static const rose = Color(0xFFE39AAE);

  /// A lighter dusty rose for accent text, icons and highlights on dark.
  static const roseLight = Color(0xFFEDB6C4);

  /// Text and icons on [rose] (8.0:1).
  static const onRose = Color(0xFF2A0F1C);

  /// The single strongest call to action, with [cream] text (4.6:1).
  static const roseDeep = Color(0xFFC23F66);

  /// Accent text, selected chip text.
  static const blush = Color(0xFFF3D3DB);

  /// Rose-brown. Non-text only (1.6:1): dividers, paper shadows.
  static const cocoa = Color(0xFF5A3440);

  // Text.
  /// Primary text and paper (15.7:1 on [card]).
  static const cream = Color(0xFFFFF3EC);

  /// Secondary text and timestamps (8.8:1 on [card]).
  static const muted = Color(0xFFCDB3C0);

  // Lines.
  /// Card and input borders.
  static const line = Color(0x33F6A9C1);

  /// A selected or focused border.
  static const lineStrong = Color(0x99F6A9C1);

  // Timeline corkboard. Surfaces only: no text sits directly on cork, so
  // month names and captions are always on paper.
  /// The board's warm cocoa cork.
  static const cork = Color(0xFF6A4438);

  /// Lighter cork, for the board's soft tonal patches.
  static const corkLight = Color(0xFF7A5040);

  /// Deep cork: the board frame's shading and tag string holes.
  static const corkDeep = Color(0xFF3E2228);

  // Status.
  static const sage = Color(0xFF7FBFA0);
  static const error = Color(0xFFF2A0A6);
}
