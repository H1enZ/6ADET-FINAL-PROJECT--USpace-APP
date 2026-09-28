/// Spacing on a 4 dp base unit, from docs/03-design-system.md.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  static const double screenMargin = 20;
  static const double screenMarginWide = 24;
  static const double cardPadding = 16;
  static const double touchTarget = 48;
  static const double railWidth = 220;
  static const double navBarHeight = 64;

  /// Widths where the layout changes.
  static const double compactMax = 600;
  static const double expandedMin = 840;

  /// Forms keep a readable width instead of stretching on desktop.
  static const double formMaxWidth = 420;
}

class AppRadius {
  AppRadius._();

  static const double chipBar = 4;
  static const double input = 13;
  static const double bubble = 16;
  static const double card = 18;
  static const double panel = 22;
}
