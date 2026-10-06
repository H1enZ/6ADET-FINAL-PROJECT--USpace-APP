import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../widgets/organisms/app_shell.dart';
import 'chat_tab.dart';
import 'home_screen.dart';
import 'love_notes_screen.dart';
import 'profile_screen.dart';
import 'timeline_screen.dart';

/// The signed-in, paired app: five tabs inside AppShell (Home, Chat,
/// Timeline, Love Notes, Profile). IndexedStack keeps each tab's state when
/// you switch away and back, and hidden tabs have their animations paused
/// (TickerMode).
///
/// Chat is the exception to keeping state: it is built only while its tab
/// is open, so it loads fresh, marks messages read and listens for new ones
/// exactly as it did when it was a pushed screen. Therabot is no longer a
/// tab; Home opens it as a page.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.profile});

  final Profile profile;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _chatTab = AppShell.chatTab;
  int _index = 0;
  int _chatUnread = 0;

  /// Bumped when leaving Chat, so Home recounts unread messages.
  final _homeRefresh = ValueNotifier<int>(0);

  /// Bumped when a notification opens a tab, so that tab is rebuilt and
  /// loads fresh (Timeline doesn't update live). Normal tab switches keep
  /// each tab's state.
  final _freshOpens = List.filled(5, 0);

  @override
  void dispose() {
    _homeRefresh.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) return;
    final leavingChat = _index == _chatTab;
    setState(() {
      _index = i;
      if (i == _chatTab) _chatUnread = 0;
    });
    if (leavingChat) _homeRefresh.value++;
  }

  void _openFromHome(int tab) {
    setState(() => _freshOpens[tab]++);
    _select(tab);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentIndex: _index,
      onDestinationSelected: _select,
      chatUnread: _index == _chatTab ? 0 : _chatUnread,
      child: IndexedStack(
        index: _index,
        children: [
          for (final (i, tab) in [
            HomeScreen(
              profile: widget.profile,
              onOpenTab: _openFromHome,
              refresh: _homeRefresh,
              onUnreadChanged: (n) {
                if (mounted && n != _chatUnread) {
                  setState(() => _chatUnread = n);
                }
              },
            ),
            _index == _chatTab
                ? ChatTab(profile: widget.profile)
                : const SizedBox.shrink(),
            TimelineScreen(
              key: ValueKey('timeline:${_freshOpens[2]}'),
              profile: widget.profile,
            ),
            LoveNotesScreen(
              key: ValueKey('notes:${_freshOpens[3]}'),
              profile: widget.profile,
            ),
            ProfileScreen(profile: widget.profile),
          ].indexed)
            TickerMode(enabled: i == _index, child: tab),
        ],
      ),
    );
  }
}
