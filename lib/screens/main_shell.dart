import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../widgets/organisms/app_shell.dart';
import 'home_screen.dart';
import 'love_notes_screen.dart';
import 'profile_screen.dart';
import 'timeline_screen.dart';
import 'therabot/therabot_tab.dart';

/// The signed-in, paired app: five tabs inside AppShell.
/// IndexedStack keeps each tab's state when you switch away and back.
/// Hidden tabs have their animations paused (TickerMode). Therabot is the
/// exception to keeping state: it is built only while its tab is open, so it
/// loads fresh each time (as it did when it was a pushed screen) and its
/// polling stops when you leave.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.profile});

  final Profile profile;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _therabotTab = 3;
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      child: IndexedStack(
        index: _index,
        children: [
          for (final (i, tab) in [
            HomeScreen(profile: widget.profile),
            TimelineScreen(profile: widget.profile),
            LoveNotesScreen(profile: widget.profile),
            _index == _therabotTab
                ? TherabotTab(profile: widget.profile)
                : const SizedBox.shrink(),
            ProfileScreen(profile: widget.profile),
          ].indexed)
            TickerMode(enabled: i == _index, child: tab),
        ],
      ),
    );
  }
}
