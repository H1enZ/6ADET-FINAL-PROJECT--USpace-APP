import 'package:flutter/foundation.dart';

/// One icon from the USpace line set in assets/icons/.
@immutable
class UsIconData {
  const UsIconData(this.name);

  /// The file name without .svg, e.g. 'home'.
  final String name;

  String get asset => 'assets/icons/$name.svg';
}

/// The USpace icon set: 24 px grid, 1.75 stroke, round caps and joins.
/// Use these instead of emoji or mixed Material icon styles.
abstract final class UsIcons {
  // Navigation.
  static const home = UsIconData('home');
  static const chat = UsIconData('chat');
  static const timeline = UsIconData('timeline');
  static const loveNotes = UsIconData('love-notes');
  static const profile = UsIconData('profile');

  // Home and actions.
  static const bell = UsIconData('bell');
  static const flip = UsIconData('flip');
  static const history = UsIconData('history');
  static const therabot = UsIconData('therabot');
  static const question = UsIconData('question');
  static const addMemory = UsIconData('add-memory');
  static const planDate = UsIconData('plan-date');
  static const timeCapsule = UsIconData('time-capsule');

  // Memory tags.
  static const tagFirstDate = UsIconData('tag-first-date');
  static const tagAnniversary = UsIconData('tag-anniversary');
  static const tagOuting = UsIconData('tag-outing');
  static const tagTravel = UsIconData('tag-travel');
  static const tagCelebration = UsIconData('tag-celebration');
  static const tagEveryday = UsIconData('tag-everyday');
  static const tagSpecial = UsIconData('tag-special');
  static const tag = UsIconData('tag');

  // General.
  static const back = UsIconData('back');
  static const chevronRight = UsIconData('chevron-right');
  static const close = UsIconData('close');
  static const plus = UsIconData('plus');
  static const heart = UsIconData('heart');
  static const lock = UsIconData('lock');
  static const mood = UsIconData('mood');
  static const sparkle = UsIconData('sparkle');
  static const calendar = UsIconData('calendar');
  static const pin = UsIconData('pin');
  static const more = UsIconData('more');
  static const trash = UsIconData('trash');
  static const star = UsIconData('star');
  static const note = UsIconData('note');
  static const check = UsIconData('check');
  static const chevronUp = UsIconData('chevron-up');
  static const chevronDown = UsIconData('chevron-down');
  static const copy = UsIconData('copy');
  static const minusCircle = UsIconData('minus-circle');

  static const search = UsIconData('search');
  static const undo = UsIconData('undo');

  // Timeline editor.
  static const arrange = UsIconData('arrange');
  static const frame = UsIconData('frame');
  static const resize = UsIconData('resize');
  static const rotate = UsIconData('rotate');
  static const layers = UsIconData('layers');
  static const link = UsIconData('link');
  static const palette = UsIconData('palette');

  // Therabot.
  static const eye = UsIconData('eye');
  static const eyeOff = UsIconData('eye-off');
  static const shuffle = UsIconData('shuffle');
  static const route = UsIconData('route');

  // Bucket list.
  static const coins = UsIconData('coins');
  static const globe = UsIconData('globe');

  // Profile and sign in.
  static const mail = UsIconData('mail');
  static const logout = UsIconData('logout');
  static const camera = UsIconData('camera');
  static const unlink = UsIconData('unlink');
  static const key = UsIconData('key');
  static const alertCircle = UsIconData('alert-circle');

  // Love note types.
  static const flower = UsIconData('flower');
  static const moon = UsIconData('moon');

  // Chat composer.
  static const send = UsIconData('send');
  static const image = UsIconData('image');
  static const smile = UsIconData('smile');
  static const keyboard = UsIconData('keyboard');

  // Care (Therabot and Work it out).
  static const hug = UsIconData('hug');
  static const idea = UsIconData('idea');
  static const listen = UsIconData('listen');
  static const edit = UsIconData('edit');
  static const breathe = UsIconData('breathe');
}
