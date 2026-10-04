import 'dart:math' as math;

import 'package:flutter/material.dart';

/// USpace is a phone app. On a phone-sized window it fills the screen as
/// is; on a wider window (a laptop or desktop browser) it is shown inside a
/// phone, centred on a USpace backdrop, at phone width and the window's
/// full height.
///
/// Used once, from MaterialApp.builder, so it wraps the app's Navigator:
/// dialogs, sheets, snack bars, tooltips and menus all open inside the
/// phone. To keep the Navigator (and everything open on it) in place while
/// the window is resized across [breakpoint], the widget tree is the same
/// in both modes; only sizes and decorations change. It reads the window
/// size from MediaQuery (no LayoutBuilder), never moves the app between
/// parents, and adds no scrolling of its own.
///
/// Inside the phone, MediaQuery reports the phone's screen size, so the app
/// lays itself out exactly as it does on a phone. Padding and insets are
/// left untouched: the phone's decorations sit in the bezel, outside the
/// screen, and never cover or catch taps meant for the app.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  /// Windows wider than this show the phone.
  static const double breakpoint = 600;

  /// The phone's screen width.
  static const double screenWidth = 412;

  static const double _bezel = 12;
  static const double _screenRadius = 40;
  static const double _bodyRadius = _screenRadius + _bezel;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final window = media.size;
    final framed = window.width > breakpoint;
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;

    // Room around the phone; less on short windows so the app keeps height.
    final margin = window.height >= 720 ? 24.0 : 8.0;
    final screen = framed
        ? Size(screenWidth, math.max(0, window.height - 2 * (margin + _bezel)))
        : window;

    return DecoratedBox(
      decoration: framed ? _backdrop(scheme) : const BoxDecoration(),
      child: Padding(
        padding: EdgeInsets.all(framed ? margin : 0),
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: framed
                    ? _body(scheme, dark)
                    : const BoxDecoration(),
                child: Padding(
                  padding: EdgeInsets.all(framed ? _bezel : 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      framed ? _screenRadius : 0,
                    ),
                    clipBehavior: framed ? Clip.antiAlias : Clip.none,
                    child: SizedBox.fromSize(
                      size: screen,
                      child: ColoredBox(
                        color: scheme.surface,
                        child: MediaQuery(
                          data: framed ? media.copyWith(size: screen) : media,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Decorations: in the bezel and on the sides only.
              Positioned(
                top: (_bezel - 4) / 2,
                left: 0,
                right: 0,
                child: _Decoration(visible: framed, child: const _Speaker()),
              ),
              Positioned(
                left: -2.5,
                top: 132,
                child: _Decoration(
                  visible: framed,
                  child: const _SideButtons(heights: [28, 52, 52]),
                ),
              ),
              Positioned(
                right: -2.5,
                top: 176,
                child: _Decoration(
                  visible: framed,
                  child: const _SideButtons(heights: [76]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static BoxDecoration _backdrop(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(0, -0.35),
        radius: 1.2,
        colors: dark
            ? [
                Color.alphaBlend(
                  scheme.primaryContainer.withValues(alpha: 0.55),
                  scheme.surface,
                ),
                scheme.surface,
                const Color(0xFF0C080E),
              ]
            : [
                scheme.primaryContainer,
                Color.alphaBlend(
                  scheme.primaryContainer.withValues(alpha: 0.45),
                  scheme.surface,
                ),
                Color.alphaBlend(
                  scheme.secondary.withValues(alpha: 0.10),
                  scheme.surface,
                ),
              ],
        stops: const [0, 0.55, 1],
      ),
    );
  }

  static BoxDecoration _body(ColorScheme scheme, bool dark) => BoxDecoration(
    color: const Color(0xFF141117),
    borderRadius: BorderRadius.circular(_bodyRadius),
    border: Border.all(
      color: dark ? const Color(0xFF3A3340) : const Color(0xFF4A4350),
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.55 : 0.28),
        blurRadius: 60,
        spreadRadius: -6,
        offset: const Offset(0, 28),
      ),
      BoxShadow(
        color: scheme.primary.withValues(alpha: dark ? 0.14 : 0.10),
        blurRadius: 90,
        spreadRadius: 4,
      ),
    ],
  );
}

/// Decorative only: never hit-tested, read by screen readers or focused.
class _Decoration extends StatelessWidget {
  const _Decoration({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(child: visible ? child : const SizedBox.shrink()),
  );
}

/// A slim speaker grille in the top bezel.
class _Speaker extends StatelessWidget {
  const _Speaker();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 64,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2731),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

/// Volume / power buttons along the side of the body.
class _SideButtons extends StatelessWidget {
  const _SideButtons({required this.heights});

  final List<double> heights;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final h in heights)
        Container(
          width: 3,
          height: h,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2530),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
    ],
  );
}
