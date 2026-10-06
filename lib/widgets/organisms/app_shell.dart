import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../atoms/us_icon.dart';

class _Destination {
  const _Destination(this.label, this.icon);
  final String label;
  final UsIconData icon;
}

/// Navigation shell: a bottom NavigationBar under 840 dp and a side
/// NavigationRail from 840 dp up. Same five tabs at every width:
/// Home, Chat, Timeline, Love Notes, Profile.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
    this.chatUnread = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  /// Unread messages, shown as a count on the Chat tab.
  final int chatUnread;

  static const chatTab = 1;

  static const _destinations = [
    _Destination('Home', UsIcons.home),
    _Destination('Chat', UsIcons.chat),
    _Destination('Timeline', UsIcons.timeline),
    _Destination('Love Notes', UsIcons.loveNotes),
    _Destination('Profile', UsIcons.profile),
  ];

  /// The tab icon, with the unread count on Chat. It takes its colour from
  /// the bar's IconTheme, so selected and unselected follow the theme.
  Widget _icon(BuildContext context, int i) {
    final d = _destinations[i];
    final icon = UsIcon(d.icon, size: 22);
    if (i != chatTab || chatUnread <= 0) return icon;
    final scheme = Theme.of(context).colorScheme;
    return Badge(
      backgroundColor: scheme.primary,
      textColor: scheme.onPrimary,
      label: Text(chatUnread > 99 ? '99+' : '$chatUnread'),
      child: icon,
    );
  }

  String _label(int i) {
    final d = _destinations[i];
    return i == chatTab && chatUnread > 0
        ? '${d.label}, $chatUnread unread'
        : d.label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppSpacing.expandedMin) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: true,
                  minExtendedWidth: AppSpacing.railWidth,
                  selectedIndex: currentIndex,
                  onDestinationSelected: onDestinationSelected,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxl,
                    ),
                    child: Text(
                      'USpace',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  destinations: [
                    for (var i = 0; i < _destinations.length; i++)
                      NavigationRailDestination(
                        icon: Semantics(
                          label: _label(i),
                          excludeSemantics: true,
                          child: _icon(context, i),
                        ),
                        label: Text(_destinations[i].label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          );
        }

        return Scaffold(
          body: child,
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.colorScheme.outline),
              ),
            ),
            child: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: [
                for (var i = 0; i < _destinations.length; i++)
                  NavigationDestination(
                    icon: _icon(context, i),
                    label: _destinations[i].label,
                    tooltip: _label(i),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
