import 'package:flutter/material.dart';

import '../models/mood.dart';
import '../services/auth_service.dart';
import '../services/mood_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';

/// The last five weeks of moods: each day shows your mood and your
/// partner's shared mood (their latest check-in that day).
class MoodHistoryScreen extends StatefulWidget {
  const MoodHistoryScreen({
    super.key,
    required this.coupleId,
    required this.myUserId,
    required this.partnerId,
    required this.partnerName,
  });

  final String coupleId;
  final String myUserId;
  final String? partnerId;
  final String partnerName;

  @override
  State<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends State<MoodHistoryScreen> {
  List<MoodEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await MoodService.recent(widget.coupleId);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted =
        theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final today = DateTime.now();
    final days = [
      for (var i = 0; i < 35; i++) today.subtract(Duration(days: i)),
    ];

    Widget cell(MoodEntry? e) => SizedBox(
          width: 44,
          child: Text(e?.mood.emoji ?? '\u00B7',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: e == null ? 18 : 22)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Mood history')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                if (_error != null)
                  Text(_error!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.error)),
                Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    SizedBox(
                        width: 44,
                        child: Text('You',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall)),
                    SizedBox(
                        width: 44,
                        child: Text(widget.partnerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall)),
                  ],
                ),
                const Divider(),
                for (final day in days)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: Text(longDate(day), style: muted)),
                        cell(latestMoodOn(_entries, widget.myUserId, day)),
                        cell(widget.partnerId == null
                            ? null
                            : latestMoodOn(_entries, widget.partnerId!, day)),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Private check-ins only appear in your own column. '
                  'Your partner sees only the moods you shared.',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
    );
  }
}
