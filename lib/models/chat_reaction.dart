import 'package:flutter/material.dart';

/// USpace chat reactions. The app writes only these keys to
/// message_reactions.emoji (migration 013).
enum ChatReaction {
  // Quick reactions, in tray order.
  love('love', 'Love'),
  inLove('in_love', 'In Love'),
  laugh('laugh', 'Laugh'),
  hug('hug', 'Hug'),
  kiss('kiss', 'Kiss'),
  puppyEyes('puppy_eyes', 'Puppy Eyes'),

  // Behind "More".
  aww('aww', 'Aww', quick: false),
  sad('sad', 'Sad', quick: false),
  upset('upset', 'Upset', quick: false),
  hereForYou('here_for_you', 'Here For You', quick: false),
  proudOfYou('proud_of_you', 'Proud of You', quick: false);

  const ChatReaction(this.key, this.label, {this.quick = true});

  /// The value stored in the database.
  final String key;

  /// The name shown and read out ("Here For You").
  final String label;

  /// In the first row of the tray; the rest are behind "More".
  final bool quick;

  /// Final artwork. Until it is added, a drawn fallback is shown.
  String get assetPath => 'assets/reactions/$key.png';

  static List<ChatReaction> get quickReactions => [
    for (final r in values)
      if (r.quick) r,
  ];

  static List<ChatReaction> get moreReactions => [
    for (final r in values)
      if (!r.quick) r,
  ];

  static ChatReaction? fromKey(String key) {
    for (final r in values) {
      if (r.key == key) return r;
    }
    return null;
  }
}

/// How a stored reaction is shown. New keys map to their reaction. The six
/// original emoji (still in older rows) are shown read-only: four have a
/// close USpace reaction and use its art; Wow and Like have none, so they
/// keep their own emoji. None of them is ever written again.
@immutable
class ReactionView {
  const ReactionView._({
    required this.label,
    this.reaction,
    this.emoji,
    this.legacy = false,
  });

  /// The USpace reaction whose art is shown, or null for Wow / Like.
  final ChatReaction? reaction;

  /// The original emoji, for the two legacy values without a USpace match.
  final String? emoji;

  final String label;

  /// Stored as one of the original six emoji (an older reaction).
  final bool legacy;

  /// What groups chips together. An older emoji never shares a chip with
  /// the new reaction it resembles, so each chip's name stays accurate.
  String get identity => legacy ? 'legacy:$label' : reaction!.key;

  static const _legacy = <String, ReactionView>{
    '❤️': ReactionView._(
      label: 'Love',
      reaction: ChatReaction.love,
      legacy: true,
    ),
    '😂': ReactionView._(
      label: 'Laugh',
      reaction: ChatReaction.laugh,
      legacy: true,
    ),
    '🥰': ReactionView._(
      label: 'In Love',
      reaction: ChatReaction.inLove,
      legacy: true,
    ),
    '😢': ReactionView._(
      label: 'Sad',
      reaction: ChatReaction.sad,
      legacy: true,
    ),
    '😮': ReactionView._(label: 'Wow', emoji: '😮', legacy: true),
    '👍': ReactionView._(label: 'Like', emoji: '👍', legacy: true),
  };

  /// The view for a stored value, or null if it is not one we know.
  static ReactionView? of(String stored) {
    final r = ChatReaction.fromKey(stored);
    if (r != null) return ReactionView._(label: r.label, reaction: r);
    return _legacy[stored];
  }
}
