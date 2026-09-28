import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../widgets/organisms/app_shell.dart';
import 'coming_soon_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

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
          HomeScreen(profile: widget.profile),
          const ComingSoonScreen(
            title: 'Timeline',
            icon: Icons.photo_library_outlined,
            message: 'Your shared memories, with photos, newest first.',
          ),
          const ComingSoonScreen(
            title: 'Love Notes',
            icon: Icons.favorite_border,
            message: 'Notes to each other, and Time Capsules sealed '
                'until a date you choose.',
          ),
          const ComingSoonScreen(
            title: 'Bucket List',
            icon: Icons.check_circle_outline,
            message: 'Things you want to do together.',
          ),
          ProfileScreen(profile: widget.profile),
        ],
      ),
    );
  }
}
