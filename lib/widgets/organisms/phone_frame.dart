import 'dart:math' as math;

import 'package:flutter/material.dart';

/// USpace is a phone app. On a phone-sized window it fills the screen as
/// is; on a wider window (a laptop or desktop browser) it is shown inside a
/// realistic phone, centred on a USpace backdrop.
///
/// The phone always has a 390 x 844 screen (a modern phone, about 9 : 19.5),
/// whatever the window size. If the window is too small to show it at full
/// size, the whole phone is scaled down, keeping its proportions; it is
/// never stretched, cropped or made taller to fill the window.
///
/// Used once, from MaterialApp.builder, so it wraps the app's Navigator:
/// dialogs, sheets, snack bars, tooltips and menus all open inside the
/// phone. To keep the Navigator (and everything open on it) in place while
/// the window is resized across [breakpoint], the widget tree is the same
/// in both modes; only sizes, scale and decorations change. It reads the
/// window size from MediaQuery (no LayoutBuilder), never moves the app
/// between parents, and adds no scrolling of its own.
///
/// Inside the phone, MediaQuery reports the phone's screen size, so the app
/// lays itself out exactly as it does on a phone. Padding and insets are
/// left untouched: the phone's decorations (camera, speaker, home bar, side
/// buttons) sit in the bezel, outside the screen, and never cover or catch
/// taps meant for the app.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  /// Windows wider than this show the phone.
  static const double breakpoint = 600;

  /// The phone's screen, in the app's logical pixels.
  static const Size screenSize = Size(390, 844);

  static const double _sideBezel = 13;
  static const double _endBezel = 17; // top and bottom: camera, home bar
  static const double _screenRadius = 34;
  static const double _bodyRadius = _screenRadius + _sideBezel;

  /// The whole device, bezel included, at full size.
  static const Size _bodySize = Size(390 + 2 * _sideBezel, 844 + 2 * _endBezel);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final window = media.size;
    final framed = window.width > breakpoint;
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;

    // Room around the phone; less on short windows so the phone stays big.
    final margin = window.height >= 800 ? 32.0 : 16.0;
    final scale = framed
        ? math.max(
            0.0,
            math.min(
              1.0,
              math.min(
                (window.width - 2 * margin) / _bodySize.width,
                (window.height - 2 * margin) / _bodySize.height,
              ),
            ),
          )
        : 1.0;
    final screen = framed ? screenSize : window;
    final body = framed ? _bodySize : window;

    return DecoratedBox(
      decoration: framed ? _backdrop(scheme) : const BoxDecoration(),
      child: Center(
        // The device is laid out at full size, then scaled as one piece.
        child: SizedBox(
          width: body.width * scale,
          height: body.height * scale,
          child: FittedBox(
            child: SizedBox.fromSize(
              size: body,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  DecoratedBox(
                    decoration: framed
                        ? _body(scheme, dark)
                        : const BoxDecoration(),
                    child: Padding(
                      padding: framed
                          ? const EdgeInsets.symmetric(
                              horizontal: _sideBezel,
                              vertical: _endBezel,
                            )
                          : EdgeInsets.zero,
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
                              data: framed
                                  ? media.copyWith(size: screen)
                                  : media,
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Decorations: in the bezel and on the sides only.
                  Positioned(
                    top: (_endBezel - 9) / 2,
                    left: 0,
                    right: 0,
                    child: _Decoration(
                      visible: framed,
                      child: const _CameraSpeaker(),
                    ),
                  ),
                  Positioned(
                    bottom: (_endBezel - 4) / 2,
                    left: 0,
                    right: 0,
                    child: _Decoration(
                      visible: framed,
                      child: const _HomeIndicator(),
                    ),
                  ),
                  Positioned(
                    left: -3,
                    top: 150,
                    child: _Decoration(
                      visible: framed,
                      child: const _SideButtons(heights: [30, 58, 58]),
                    ),
                  ),
                  Positioned(
                    right: -3,
                    top: 200,
                    child: _Decoration(
                      visible: framed,
                      child: const _SideButtons(heights: [90]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static BoxDecoration _backdrop(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 1.1,
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
    color: const Color(0xFF0E0C10),
    borderRadius: BorderRadius.circular(_bodyRadius),
    // A thin metal rim around the black glass.
    border: Border.all(
      color: dark ? const Color(0xFF4A4250) : const Color(0xFF5A5260),
      width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.50 : 0.22),
        blurRadius: 40,
        spreadRadius: -8,
        offset: const Offset(0, 24),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.30 : 0.10),
        blurRadius: 6,
        offset: const Offset(0, 2),
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

/// A slim speaker grille with the front camera beside it, in the top bezel.
class _CameraSpeaker extends StatelessWidget {
  const _CameraSpeaker();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const SizedBox(width: 17), // balances the camera: grille stays centred
      Container(
        width: 56,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2530),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 8),
      Container(
        width: 9,
        height: 9,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment(-0.3, -0.3),
            radius: 0.8,
            colors: [Color(0xFF3B4A66), Color(0xFF15141B)],
          ),
        ),
      ),
    ],
  );
}

/// The home indicator bar, in the bottom bezel.
class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 120,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFF5C5563),
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
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF3A3440),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
    ],
  );
}
