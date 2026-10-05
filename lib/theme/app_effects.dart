import 'package:flutter/material.dart';

/// Soft depth, background gradients, motion timing and the mood palette for
/// the Home redesign. Colours that are not mood-specific stay in AppColors.

/// Soft, low-contrast shadows: depth without hard edges.
class AppShadows {
  AppShadows._();

  /// Resting cards and tiles.
  static List<BoxShadow> soft(ColorScheme scheme) => [
    BoxShadow(
      color: _tint(scheme).withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 3),
    ),
  ];

  /// The mood hero and other raised surfaces.
  static List<BoxShadow> raised(ColorScheme scheme) => [
    BoxShadow(
      color: _tint(scheme).withValues(alpha: 0.12),
      blurRadius: 28,
      offset: const Offset(0, 6),
    ),
  ];

  /// A selected tile: a soft glow in its own accent colour.
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.20),
      blurRadius: 16,
      offset: const Offset(0, 3),
    ),
  ];

  // A warm rose shadow reads softer than grey on the cream background; in
  // dark mode plain black keeps surfaces from glowing.
  static Color _tint(ColorScheme scheme) => scheme.brightness == Brightness.dark
      ? Colors.black
      : const Color(0xFF8A3A55);
}

/// Background washes for Splash, Login/Signup and decorative surfaces.
class AppGradients {
  AppGradients._();

  /// Soft peach to blush: warm, not loud.
  static LinearGradient blush(Brightness brightness) =>
      brightness == Brightness.dark
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1420), Color(0xFF2A1724)],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1EA), Color(0xFFFBE1E6)],
        );

  // On the light blush the caption grey and the rose are just under 4.5:1,
  // so text placed straight on it is nudged a little toward plum (5:1+).
  // The dark gradient already passes with the plain tokens.

  /// Secondary text sitting directly on [blush].
  static Color onBlushText(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
      ? scheme.onSurfaceVariant
      : Color.lerp(scheme.onSurfaceVariant, scheme.secondary, 0.25)!;

  /// Links and text buttons sitting directly on [blush].
  static Color onBlushLink(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
      ? scheme.primary
      : Color.lerp(scheme.primary, scheme.secondary, 0.25)!;
}

/// Shared motion timing, so every screen animates with the same feel.
/// Gentle, never bouncy. Respect motionOff(context) at the call site.
class AppMotion {
  AppMotion._();

  /// Press feedback: down fast, release a touch slower.
  static const Duration pressIn = Duration(milliseconds: 90);
  static const Duration pressOut = Duration(milliseconds: 160);

  static const Duration quick = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 450);
  static const Duration slow = Duration(milliseconds: 600);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  /// A strong ease-out for things that respond to a touch: moves at once,
  /// then settles softly. Reads more decisive than easeOutCubic.
  static const Curve snappy = Cubic(0.23, 1, 0.32, 1);
}

/// One mood's colours: the hero background, its accent and its particles.
@immutable
class MoodColors {
  const MoodColors({
    required this.background,
    required this.backgroundDark,
    required this.accent,
    required this.accentDark,
    required this.particle,
  });

  /// Two-stop hero gradient in light mode (top-left to bottom-right).
  final List<Color> background;

  /// The same mood, deepened for dark mode so the art still pops.
  final List<Color> backgroundDark;

  /// Selected outline and icons in light mode, at least 3:1 on white.
  /// Not for body text: text on the hero uses the theme's onSurface.
  final Color accent;

  /// The same accent, lightened for dark surfaces.
  final Color accentDark;

  /// Floating hearts / sparkles / kisses.
  final Color particle;

  List<Color> gradientFor(Brightness b) =>
      b == Brightness.dark ? backgroundDark : background;

  Color accentFor(Brightness b) => b == Brightness.dark ? accentDark : accent;
}

/// The eight selectable moods' palettes, keyed by the mood's database name.
class AppMoodColors {
  AppMoodColors._();

  static const loved = MoodColors(
    background: [Color(0xFFFFE3EA), Color(0xFFFBC6D3)],
    backgroundDark: [Color(0xFF4A1F2D), Color(0xFF6B2840)],
    accent: Color(0xFFD9466E),
    accentDark: Color(0xFFF17C9A),
    particle: Color(0xFFF17C9A),
  );
  static const happy = MoodColors(
    background: [Color(0xFFFFF4D9), Color(0xFFFFDFB0)],
    backgroundDark: [Color(0xFF4A3A1C), Color(0xFF684A1E)],
    accent: Color(0xFFB86A10),
    accentDark: Color(0xFFFFC85C),
    particle: Color(0xFFFFC85C),
  );
  static const calm = MoodColors(
    background: [Color(0xFFE6F0FB), Color(0xFFE6E0F7)],
    backgroundDark: [Color(0xFF1E2A3E), Color(0xFF2B2648)],
    accent: Color(0xFF4E6FAE),
    accentDark: Color(0xFFA9BEEB),
    particle: Color(0xFFB7C8EC),
  );
  static const emotional = MoodColors(
    background: [Color(0xFFEFE4F8), Color(0xFFF8DCE8)],
    backgroundDark: [Color(0xFF33244A), Color(0xFF4A2440)],
    accent: Color(0xFF8A5CB8),
    accentDark: Color(0xFFC9A8E6),
    particle: Color(0xFFC9A8E6),
  );
  static const needAHug = MoodColors(
    background: [Color(0xFFFFEDE0), Color(0xFFF6DDC8)],
    backgroundDark: [Color(0xFF45301F), Color(0xFF573A26)],
    accent: Color(0xFFA8653A),
    accentDark: Color(0xFFE8B48F),
    particle: Color(0xFFE8B48F),
  );
  static const flirty = MoodColors(
    background: [Color(0xFFFFE1E6), Color(0xFFFFC3C8)],
    backgroundDark: [Color(0xFF4F1A24), Color(0xFF6E1F2C)],
    accent: Color(0xFFD52F47),
    accentDark: Color(0xFFF57A8C),
    particle: Color(0xFFF2566B),
  );
  static const romantic = MoodColors(
    background: [Color(0xFFFCE4EC), Color(0xFFF3CBDD)],
    backgroundDark: [Color(0xFF47203A), Color(0xFF5E2648)],
    accent: Color(0xFFC2477F),
    accentDark: Color(0xFFEFA0C1),
    particle: Color(0xFFEFA0C1),
  );
  static const excited = MoodColors(
    background: [Color(0xFFFFF0DA), Color(0xFFFFD9E6)],
    backgroundDark: [Color(0xFF4A3420), Color(0xFF5B2440)],
    accent: Color(0xFFB36A08),
    accentDark: Color(0xFFFFC94D),
    particle: Color(0xFFFFC94D),
  );
}
