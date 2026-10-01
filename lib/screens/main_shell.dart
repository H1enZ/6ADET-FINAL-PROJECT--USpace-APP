import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../widgets/organisms/app_shell.dart';
import 'home_screen.dart';
import 'love_notes_screen.dart';
import 'profile_screen.dart';
import 'timeline_screen.dart';
import 'bucket_list_screen.dart';

/// The signed-in, paired app: five tabs inside AppShell.
/// IndexedStack keeps each tab's state when you switch away and back.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.profile});

  final Profile profile;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      child: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            profile: widget.profile,
            onOpenTab: (i) => setState(() => _index = i),
          ),
          TimelineScreen(profile: widget.profile),
          LoveNotesScreen(profile: widget.profile),
          BucketListScreen(profile: widget.profile),
          ProfileScreen(profile: widget.profile),
        ],
      ),
    );
  }
}
