import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/chat_reaction.dart';

/// A reaction's picture: the final artwork from assets/reactions/ once it
/// has been added, otherwise a soft drawn stand-in (a glossy disc with an
/// icon). Dropping the PNG into assets/reactions/ is enough; no code change.
///
/// Always decorative: whoever places it gives the readable name.
class ReactionArt extends StatelessWidget {
  const ReactionArt({super.key, required this.view, required this.size});

  ReactionArt.of(ChatReaction reaction, {super.key, required this.size})
    : view = ReactionView.of(reaction.key)!;

  final ReactionView view;
  final double size;

  // Read the asset manifest once per app run (as MoodArt does).
  static Future<Set<String>>? _assets;
  static Set<String>? _loaded;

  static Future<Set<String>> _available() =>
      _assets ??= AssetManifest.loadFromAssetBundle(rootBundle)
          .then((m) => _loaded = m.listAssets().toSet())
          .catchError((Object _) => _loaded = <String>{});

  @override
  Widget build(BuildContext context) {
    final reaction = view.reaction;
    final Widget art;
    if (reaction == null) {
      // Legacy Wow / Like: the original emoji, read-only.
      art = _EmojiDisc(emoji: view.emoji ?? '', size: size);
    } else {
      Widget pick(BuildContext context, Set<String>? assets) {
        final fallback = _Fallback(reaction: reaction, size: size);
        if (!(assets?.contains(reaction.assetPath) ?? false)) return fallback;
        return Image.asset(
          reaction.assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          // Decode near display size (with room for the pick's pop), not
          // the full artwork size.
          cacheWidth: (size * 1.25 * MediaQuery.devicePixelRatioOf(context))
              .ceil(),
          errorBuilder: (context, _, _) => fallback,
        );
      }

      // Once the manifest has been read, build straight away (no
      // FutureBuilder, no extra rebuild per chip).
      final loaded = _loaded;
      art = loaded != null
          ? pick(context, loaded)
          : FutureBuilder<Set<String>>(
              future: _available(),
              builder: (context, snap) => pick(context, snap.data),
            );
    }
    return ExcludeSemantics(
      child: SizedBox.square(dimension: size, child: art),
    );
  }
}

/// Stand-in art until the final PNGs are added: a glossy disc in the
/// reaction's colour with a white icon.
class _Fallback extends StatelessWidget {
  const _Fallback({required this.reaction, required this.size});

  final ChatReaction reaction;
  final double size;

  static const _look = <ChatReaction, (IconData, Color, Color)>{
    ChatReaction.love: (
      Icons.favorite_rounded,
      Color(0xFFFF8FA8),
      Color(0xFFD63B62),
    ),
    ChatReaction.inLove: (
      Icons.auto_awesome_rounded,
      Color(0xFFFFA3C4),
      Color(0xFFE0457B),
    ),
    ChatReaction.laugh: (
      Icons.sentiment_very_satisfied_rounded,
      Color(0xFFFFD36E),
      Color(0xFFF0A020),
    ),
    ChatReaction.hug: (
      Icons.diversity_1_rounded,
      Color(0xFFF8B992),
      Color(0xFFD9805A),
    ),
    ChatReaction.kiss: (
      Icons.sentiment_satisfied_alt_rounded,
      Color(0xFFFF9C9C),
      Color(0xFFDA4F5E),
    ),
    ChatReaction.puppyEyes: (
      Icons.pets_rounded,
      Color(0xFFE8BC8C),
      Color(0xFFB9825A),
    ),
    ChatReaction.aww: (Icons.spa_rounded, Color(0xFFE3B8F2), Color(0xFFA76BC9)),
    ChatReaction.sad: (
      Icons.sentiment_dissatisfied_rounded,
      Color(0xFFA9C8F2),
      Color(0xFF5F8BCB),
    ),
    ChatReaction.upset: (
      Icons.mood_bad_rounded,
      Color(0xFFF2A99A),
      Color(0xFFC4624E),
    ),
    ChatReaction.hereForYou: (
      Icons.volunteer_activism_rounded,
      Color(0xFFF7B3C8),
      Color(0xFFC9577D),
    ),
    ChatReaction.proudOfYou: (
      Icons.emoji_events_rounded,
      Color(0xFFFFD98A),
      Color(0xFFD9A030),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, light, deep) = _look[reaction]!;
    return _GlossyDisc(
      light: light,
      deep: deep,
      size: size,
      child: Icon(icon, size: size * 0.56, color: Colors.white),
    );
  }
}

/// The original emoji on a soft neutral disc (legacy Wow / Like).
class _EmojiDisc extends StatelessWidget {
  const _EmojiDisc({required this.emoji, required this.size});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _GlossyDisc(
      light: scheme.surfaceContainerHighest,
      deep: Color.lerp(scheme.surfaceContainerHighest, scheme.outline, 0.6)!,
      size: size,
      child: Text(
        emoji,
        // Fixed size: the disc is the size, not the system text scale.
        textScaler: TextScaler.noScaling,
        style: TextStyle(fontSize: size * 0.56, height: 1),
      ),
    );
  }
}

class _GlossyDisc extends StatelessWidget {
  const _GlossyDisc({
    required this.light,
    required this.deep,
    required this.size,
    required this.child,
  });

  final Color light;
  final Color deep;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.95,
          colors: [light, deep],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The soft highlight that makes it read as glossy.
          Positioned(
            left: size * 0.2,
            top: size * 0.1,
            child: Container(
              width: size * 0.36,
              height: size * 0.2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
