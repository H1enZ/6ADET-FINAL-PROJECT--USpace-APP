import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "USpace" with a small heart after it: the brand mark on Splash,
/// Login/Signup and the Home header. One widget, so it looks identical
/// everywhere; only [size] changes.
class USpaceWordmark extends StatelessWidget {
  const USpaceWordmark({
    super.key,
    this.size = 24,
    this.color,
    this.heartColor,
    this.isHeader = false,
  });

  /// Font size of the word. The heart scales with it.
  final double size;

  /// Defaults to the theme's plum (secondary) for the word...
  final Color? color;

  /// ...and its rose (primary) for the heart.
  final Color? heartColor;

  /// True where the wordmark is the screen title (the Home header).
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The word grows with the system text size, so the heart and its spacing
    // follow the same scale and the mark keeps its proportions.
    final s = MediaQuery.textScalerOf(context).scale(size);
    return Semantics(
      label: 'USpace',
      header: isHeader,
      excludeSemantics: true,
      // With very large text on a narrow phone the mark would be wider than
      // the screen: it shrinks to fit instead (never larger than designed).
      child: FittedBox(fit: BoxFit.scaleDown, child: _mark(scheme, s)),
    );
  }

  Widget _mark(ColorScheme scheme, double s) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'USpace',
        style: GoogleFonts.playfairDisplay(
          fontSize: size,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          height: 1.1,
          color: color ?? scheme.secondary,
        ),
      ),
      // Sits a little high, like a superscript, as in the logo.
      Padding(
        padding: EdgeInsets.only(left: s * 0.08, top: s * 0.04),
        child: Icon(
          Icons.favorite_rounded,
          size: s * 0.42,
          color: heartColor ?? scheme.primary,
        ),
      ),
    ],
  );
}
