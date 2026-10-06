import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/us_icons.dart';

export '../../theme/us_icons.dart';

/// Draws a [UsIconData] like an [Icon]: it reads size and colour from the
/// surrounding IconTheme unless given, and is hidden from screen readers
/// unless [semanticLabel] is set.
class UsIcon extends StatelessWidget {
  const UsIcon(this.icon, {super.key, this.size, this.color, this.semanticLabel});

  final UsIconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    final c = color ?? theme.color ?? Theme.of(context).colorScheme.onSurface;
    final svg = SvgPicture.asset(
      icon.asset,
      width: s,
      height: s,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
    final sized = SizedBox.square(dimension: s, child: svg);
    return semanticLabel == null
        ? ExcludeSemantics(child: sized)
        : Semantics(label: semanticLabel, image: true, child: sized);
  }
}
