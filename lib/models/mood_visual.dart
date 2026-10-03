import 'package:flutter/material.dart';

import '../theme/app_effects.dart';
import 'mood.dart';

/// What floats around a mood's illustration on the Home hero.
enum MoodParticles { hearts, glow, sparkles, kisses, drift, none }

/// How a mood looks on Home: words, colours, particles and artwork.
/// One per Home mood; older moods borrow the nearest one's look.
@immutable
class MoodVisual {
  const MoodVisual._({
    required this.mood,
    required this.quote,
    required this.colors,
    required this.particles,
    required this.artDescription,
  });

  final Mood mood;

  /// A short line for the hero, under the mood.
  final String quote;
  final MoodColors colors;
  final MoodParticles particles;

  /// What the final artwork shows. Also its screen-reader description.
  final String artDescription;

  String get dbValue => mood.dbValue;
  String get label => mood.label;

  /// The artwork slot: a transparent PNG (about 1024×1024), soft 3D style,
  /// named by the mood's database value. Until the file is added the app
  /// draws a placeholder (see MoodArt).
  String get assetPath => 'assets/moods/${mood.dbValue}.png';

  List<Color> gradientFor(Brightness b) => colors.gradientFor(b);
  Color accentFor(Brightness b) => colors.accentFor(b);

  /// The visual for [mood]. Older history-only moods use the closest Home
  /// mood's colours and art; their own label is still shown.
  static MoodVisual of(Mood mood) => _byMood[mood] ?? _byMood[_nearest(mood)]!;

  static Mood _nearest(Mood legacy) => switch (legacy) {
    Mood.relaxed || Mood.tired => Mood.calm,
    Mood.stressed || Mood.sad || Mood.upset => Mood.emotional,
    Mood.anxious || Mood.lonely => Mood.needAHug,
    _ => Mood.loved,
  };

  static const all = <MoodVisual>[
    MoodVisual._(
      mood: Mood.loved,
      quote: 'Wrapped up in warm, fuzzy love.',
      colors: AppMoodColors.loved,
      particles: MoodParticles.hearts,
      artDescription: 'A heart hugging itself',
    ),
    MoodVisual._(
      mood: Mood.happy,
      quote: 'Sunshine on the inside today.',
      colors: AppMoodColors.happy,
      particles: MoodParticles.glow,
      artDescription: 'A smiling sun',
    ),
    MoodVisual._(
      mood: Mood.calm,
      quote: 'Slow breaths, soft thoughts.',
      colors: AppMoodColors.calm,
      particles: MoodParticles.drift,
      artDescription: 'A peaceful sleeping cloud',
    ),
    MoodVisual._(
      mood: Mood.emotional,
      quote: 'Feeling it all, and that is okay.',
      colors: AppMoodColors.emotional,
      particles: MoodParticles.drift,
      artDescription: 'A teary purple cloud',
    ),
    MoodVisual._(
      mood: Mood.needAHug,
      quote: 'A long, warm hug would help.',
      colors: AppMoodColors.needAHug,
      particles: MoodParticles.hearts,
      artDescription: 'A soft teddy bear',
    ),
    MoodVisual._(
      mood: Mood.flirty,
      quote: 'Feeling a little cheeky today.',
      colors: AppMoodColors.flirty,
      particles: MoodParticles.kisses,
      artDescription: 'A blushing face blowing a kiss',
    ),
    MoodVisual._(
      mood: Mood.romantic,
      quote: 'Heart full, thinking of us.',
      colors: AppMoodColors.romantic,
      particles: MoodParticles.hearts,
      artDescription: 'Two floating pink hearts',
    ),
    MoodVisual._(
      mood: Mood.excited,
      quote: 'Can barely sit still!',
      colors: AppMoodColors.excited,
      particles: MoodParticles.sparkles,
      artDescription: 'A star-eyed happy face',
    ),
  ];

  static final Map<Mood, MoodVisual> _byMood = {for (final v in all) v.mood: v};
}
