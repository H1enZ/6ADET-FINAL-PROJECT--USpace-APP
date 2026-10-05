import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/therabot.dart';
import '../../services/affection_service.dart';
import '../../services/auth_service.dart';
import '../../services/support_service.dart';
import '../../services/therabot_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/atoms/app_button.dart';
import '../../widgets/atoms/app_text_field.dart';
import '../../widgets/effects/floating_hearts.dart';
import '../../widgets/effects/motion.dart';
import '../../widgets/therabot/therabot_widgets.dart';
import '../../models/love_note.dart';
import '../write_love_note_screen.dart';
import 'shared_memories_page.dart';

// The four next steps after a shared reflection. Each is a choice for one
// person; none is better than another. Nothing here is ever sent without a
// tap on Send, and every message can be edited first.

// ------------------------------------------------------------------ comfort

class TherabotComfortPage extends StatefulWidget {
  const TherabotComfortPage({
    super.key,
    required this.coupleId,
    required this.partnerName,
  });

  final String coupleId;
  final String partnerName;

  @override
  State<TherabotComfortPage> createState() => _TherabotComfortPageState();
}

class _ComfortOption {
  const _ComfortOption(this.emoji, this.label, this.kind, this.template);
  final String emoji;
  final String label;

  /// The affection kind it is sent as (see migration 006).
  final String kind;

  /// A starting point to edit, written by USpace (not generated).
  final String template;
}

class _TherabotComfortPageState extends State<TherabotComfortPage> {
  static const _options = [
    _ComfortOption('🫂', 'Hug', 'hug', ''),
    _ComfortOption(
      '💗',
      'Reassuring message',
      'comfort',
      "I'm here, and I care about you. We'll find our way through this together.",
    ),
    _ComfortOption(
      '👂',
      'Listen',
      'listen',
      "Could you just listen for a little while? I don't need it fixed, I just need you.",
    ),
    _ComfortOption(
      '🤍',
      "Remind me we're okay",
      'comfort',
      "Can you remind me we're okay? I just need to hear it from you.",
    ),
    _ComfortOption('✏️', 'Something else', 'comfort', ''),
  ];

  _ComfortOption? _picked;
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _pick(_ComfortOption o) {
    setState(() {
      _picked = o;
      _message.text = o.template;
    });
  }

  Future<void> _send() async {
    final o = _picked;
    if (o == null) return;
    final text = _message.text.trim();
    if (o.kind != 'hug' && text.isEmpty) {
      therabotToast(context, 'Write something first, in your own words.');
      return;
    }
    setState(() => _sending = true);
    try {
      await AffectionService.send(
        coupleId: widget.coupleId,
        kind: o.kind,
        message: text,
      );
      if (!mounted) return;
      showGesturePulse(context, o.emoji);
      setState(() {
        _picked = null;
        _message.clear();
      });
    } catch (e) {
      if (!mounted) return;
      therabotToast(context, therabotError(e).message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final o = _picked;
    return TherabotPage(
      title: '🫂 Comfort',
      children: [
        Text('Comfort can go both ways', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Ask for what would help, or offer it. Only if it feels right for you.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in _options)
              ChoiceChip(
                label: Text('${option.emoji}  ${option.label}'),
                selected: option == o,
                onSelected: _sending ? null : (_) => _pick(option),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (o != null && o.kind == 'hug')
          FadeSlideIn(
            child: TherabotCard(
              tinted: true,
              child: Column(
                children: [
                  const Text('🫂', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Send ${widget.partnerName} a hug',
                    onPressed: _send,
                    isLoading: _sending,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
          )
        else if (o != null)
          FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Your message (edit it so it sounds like you)',
                  controller: _message,
                  maxLength: 1000,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Nothing is sent until you tap Send.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Send to ${widget.partnerName}',
                  icon: Icons.send_outlined,
                  onPressed: _send,
                  isLoading: _sending,
                  fullWidth: true,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------------- talk

class TherabotTalkPage extends StatefulWidget {
  const TherabotTalkPage({
    super.key,
    required this.questions,
    required this.partnerName,
    this.names,
    this.onOpenChat,
  });

  /// The discussion questions from your shared reflection, as returned.
  final List<String> questions;

  /// Shows "Partner 1" / "Partner 2" in [questions] as usernames.
  final TherabotNames? names;
  final String partnerName;
  final VoidCallback? onOpenChat;

  @override
  State<TherabotTalkPage> createState() => _TherabotTalkPageState();
}

class _TherabotTalkPageState extends State<TherabotTalkPage> {
  int _at = 0;

  /// Written by USpace (not by the AI), used only if the reflection came
  /// back without discussion questions.
  static const _gentleQuestions = [
    'What felt hardest about this for you?',
    'What would help you feel heard right now?',
    'Is there anything you would like to understand better about how I see it?',
  ];

  List<String> get _questions =>
      widget.questions.isNotEmpty ? widget.questions : _gentleQuestions;

  Future<void> _copy() async {
    final qs = _questions;
    final text = [
      for (var i = 0; i < qs.length; i++)
        '${i + 1}. ${widget.names?.display(qs[i]) ?? qs[i]}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final qs = _questions;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return TherabotPage(
      title: '💬 Talk',
      children: [
        Text('Talk it through, gently', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          "This isn't about deciding who is right. It's about understanding each other.",
          style: muted,
        ),
        const SizedBox(height: AppSpacing.xl),
        TherabotCard(
          label: 'A few kind ground rules',
          child: SoftList(
            items: const [
              'Take turns. One speaks, the other listens to understand.',
              'Say "I feel…" rather than "You always…".',
              'Pause any time. You can come back to it later.',
              'Nobody has to apologise or agree to finish.',
            ],
          ),
        ),
        ...[
          const SizedBox(height: AppSpacing.xl),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Here in the app, one question at a time',
            style: theme.textTheme.titleMedium,
          ),
          if (widget.questions.isEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('A few gentle questions to start with.', style: muted),
          ],
          const SizedBox(height: AppSpacing.sm),
          AnimatedSwitcher(
            duration: Duration(milliseconds: motionOff(context) ? 0 : 280),
            child: TherabotCard(
              key: ValueKey(_at),
              tinted: true,
              label: 'Question ${_at + 1} of ${qs.length}',
              child: PartnerText(
                qs[_at],
                names: widget.names,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Previous',
                  variant: AppButtonVariant.outlined,
                  onPressed: _at > 0 ? () => setState(() => _at--) : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'Next question',
                  onPressed: _at < qs.length - 1
                      ? () => setState(() => _at++)
                      : null,
                ),
              ),
            ],
          ),
          if (widget.onOpenChat != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Talk in our chat',
              icon: Icons.chat_bubble_outline,
              variant: AppButtonVariant.outlined,
              onPressed: widget.onOpenChat,
              fullWidth: true,
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          SectionLabelText(
            'Talking in person instead?',
            actionLabel: 'Copy',
            onAction: _copy,
          ),
          TherabotCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Keep these handy for a walk, a call or a quiet moment together.',
                  style: muted,
                ),
                const SizedBox(height: AppSpacing.sm),
                SoftList(items: qs, names: widget.names),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A small heading with an optional action, matching SectionLabel's look.
class SectionLabelText extends StatelessWidget {
  const SectionLabelText(
    this.text, {
    super.key,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(text, style: theme.textTheme.titleMedium)),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

// -------------------------------------------------------------------- space

class TherabotSpacePage extends StatefulWidget {
  const TherabotSpacePage({
    super.key,
    required this.coupleId,
    required this.partnerName,
    this.onTalk,
  });

  final String coupleId;
  final String partnerName;
  final VoidCallback? onTalk;

  @override
  State<TherabotSpacePage> createState() => _TherabotSpacePageState();
}

class _TherabotSpacePageState extends State<TherabotSpacePage> {
  // Remembered on this device only, like the theme choice.
  // Per account, so someone else signing in on this device never sees it.
  static String get _key =>
      'therabot_space_until_${AuthService.user?.id ?? 'anon'}';

  DateTime? _until;
  Timer? _tick;
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _note.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = DateTime.tryParse(prefs.getString(_key) ?? '');
      // A check-in from hours ago is not brought back.
      if (saved != null &&
          saved.isAfter(DateTime.now().subtract(const Duration(hours: 2)))) {
        _set(saved.toLocal(), persist: false);
      }
    } catch (_) {
      // Storage unavailable: the timer still works for this visit.
    }
  }

  Future<void> _set(DateTime? until, {bool persist = true}) async {
    _tick?.cancel();
    if (!mounted) return;
    setState(() {
      _until = until;
      if (until != null) _note.text = _defaultNote(until);
    });
    if (until != null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (t) {
        // One last rebuild shows the check-in, then the timer stops.
        if (!DateTime.now().isBefore(until)) t.cancel();
        if (mounted) setState(() {});
      });
    }
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (until == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, until.toUtc().toIso8601String());
      }
    } catch (_) {}
  }

  String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  String _defaultNote(DateTime until) =>
      "I'm taking a little space for now. I'll check in around ${_clock(until)}. 💗";

  /// "Tonight": a check-in at 9 PM, or tomorrow morning if it is already late.
  DateTime _tonight(DateTime now) {
    final nine = DateTime(now.year, now.month, now.day, 21);
    if (now.isBefore(nine.subtract(const Duration(minutes: 30)))) return nine;
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9);
  }

  String _tonightLabel(DateTime now) {
    final at = _tonight(now);
    return at.day == now.day
        ? 'Tonight · ${_clock(at)}'
        : 'Tomorrow · ${_clock(at)}';
  }

  Future<void> _custom() async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 45))),
      helpText: 'Check in at',
    );
    if (picked == null) return;
    var at = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _set(at);
  }

  Future<void> _tellPartner() async {
    final text = _note.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await AffectionService.send(
        coupleId: widget.coupleId,
        kind: 'comfort',
        message: text,
      );
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      therabotToast(context, therabotError(e).message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final until = _until;
    final now = DateTime.now();
    final left = until?.difference(now);
    final done = left != null && left.inSeconds <= 0;

    String remaining(Duration d) {
      if (d.inHours >= 1) {
        return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
      }
      return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }

    final options = <(String, DateTime Function())>[
      ('10 minutes', () => now.add(const Duration(minutes: 10))),
      ('20 minutes', () => now.add(const Duration(minutes: 20))),
      ('30 minutes', () => now.add(const Duration(minutes: 30))),
      ('1 hour', () => now.add(const Duration(hours: 1))),
      (_tonightLabel(now), () => _tonight(now)),
    ];

    return TherabotPage(
      title: '⏸ Take Space',
      children: [
        Text('A little space is okay', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          "Taking space isn't a punishment, and it isn't giving up. Rest, breathe, do "
          "something kind for yourself. You don't have to pick the topic back up until you're ready.",
          style: muted,
        ),
        const SizedBox(height: AppSpacing.xl),
        if (until == null) ...[
          Text(
            'When would you like a gentle check-in?',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final o in options)
                ActionChip(label: Text(o.$1), onPressed: () => _set(o.$2())),
              ActionChip(
                avatar: const Icon(Icons.schedule, size: 18),
                label: const Text('Custom'),
                onPressed: _custom,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Come back to this page to see your check-in. No notification is '
            'sent, and it is only for you.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ] else if (!done) ...[
          TherabotCard(
            tinted: true,
            child: Column(
              children: [
                Text(
                  'Check-in at ${_clock(until)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  remaining(left!),
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Take your time.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Check in now',
                  variant: AppButtonVariant.outlined,
                  onPressed: () => _set(DateTime.now()),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'Stop timer',
                  variant: AppButtonVariant.outlined,
                  onPressed: () => _set(null),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          TherabotCard(
            label: 'Let ${widget.partnerName} know (optional)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _note,
                  maxLength: 1000,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                Text(
                  'Edit it first if you like. Nothing is sent until you tap Send.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    label: 'Send',
                    icon: Icons.send_outlined,
                    variant: AppButtonVariant.outlined,
                    isLoading: _sending,
                    onPressed: _tellPartner,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          FadeSlideIn(
            child: TherabotCard(
              tinted: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Check-in time 💗',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'How are you feeling now? There is no need to talk yet. Whatever you '
                    'choose is okay.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (widget.onTalk != null) ...[
            AppButton(
              label: "I'd like to talk",
              onPressed: () {
                _set(null);
                widget.onTalk!();
              },
              fullWidth: true,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppButton(
            label: 'A little more time',
            variant: AppButtonVariant.outlined,
            onPressed: () =>
                _set(DateTime.now().add(const Duration(minutes: 15))),
            fullWidth: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Done for now',
            variant: AppButtonVariant.outlined,
            onPressed: () => _set(null),
            fullWidth: true,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- reconnect

class TherabotReconnectPage extends StatefulWidget {
  const TherabotReconnectPage({
    super.key,
    required this.coupleId,
    required this.partnerName,
    this.anniversary,
  });

  final String coupleId;
  final String partnerName;
  final DateTime? anniversary;

  @override
  State<TherabotReconnectPage> createState() => _TherabotReconnectPageState();
}

class _TherabotReconnectPageState extends State<TherabotReconnectPage> {
  void _memories() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SharedMemoriesPage(
          coupleId: widget.coupleId,
          partnerName: widget.partnerName,
        ),
      ),
    );
  }

  Future<void> _appreciation() async {
    // An appreciation is a Thank You love note.
    final sent = await openWriteLoveNote(
      context,
      coupleId: widget.coupleId,
      partnerName: widget.partnerName,
      initial: NoteCategory.thankYou,
    );
    if (!sent || !mounted) return;
    showEnvelopeFly(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget tile(
      String emoji,
      String title,
      String subtitle,
      VoidCallback? onTap, {
      String? badge,
    }) {
      final enabled = onTap != null;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Material(
          color: scheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: BorderSide(color: scheme.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Semantics(
                enabled: enabled,
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (badge != null)
                      Chip(
                        label: Text(badge),
                        visualDensity: VisualDensity.compact,
                      )
                    else
                      Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return TherabotPage(
      title: '❤️ Reconnect',
      children: [
        Text(
          'Small ways back to each other',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Only if it feels right for you. It is always okay to wait.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        tile(
          '📸',
          'Shared memories',
          'Look back on a favourite moment from your Timeline together.',
          _memories,
        ),
        tile(
          '💌',
          'Write an appreciation letter',
          'Tell ${widget.partnerName} what you appreciate about them.',
          _appreciation,
        ),
      ],
    );
  }
}

// ------------------------------------------------- waiting: private notes

/// "Clarify my thoughts" or "Draft something for later" while you wait.
/// Saved only as a private note (Therabot › Saved notes, not
/// shared), never sent, never given to Therabot.
class TherabotPrivateNotePage extends StatefulWidget {
  const TherabotPrivateNotePage({
    super.key,
    required this.coupleId,
    required this.partnerName,
    required this.draft,
  });

  final String coupleId;
  final String partnerName;

  /// true: a draft to maybe share later; false: clarify my thoughts.
  final bool draft;

  @override
  State<TherabotPrivateNotePage> createState() =>
      _TherabotPrivateNotePageState();
}

class _TherabotPrivateNotePageState extends State<TherabotPrivateNotePage> {
  final _text = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _start(String starter) {
    final current = _text.text;
    _text.text = current.isEmpty ? '$starter ' : '$current\n$starter ';
    _text.selection = TextSelection.collapsed(offset: _text.text.length);
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty) {
      therabotToast(context, 'Write something first.');
      return;
    }
    // Counted the way the database counts (code points).
    if (_text.text.runes.length > 2000) {
      therabotToast(context, 'This is a little too long. Try shortening it.');
      return;
    }
    setState(() => _saving = true);
    try {
      await SupportService.save(
        coupleId: widget.coupleId,
        need: widget.draft ? 'comfort' : 'listen',
        answers: [_text.text],
        shared: false,
        done: false,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      therabotToast(context, therabotError(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final starters = widget.draft
        ? const [
            'I want you to know…',
            'What I appreciate about you is…',
            'Next time, could we…',
          ]
        : const [
            'What I am still feeling is…',
            'What I am unsure about is…',
            'What matters most to me is…',
          ];
    return TherabotPage(
      title: widget.draft ? 'Draft something for later' : 'Clarify my thoughts',
      children: [
        Text(
          widget.draft
              ? 'Write something you might want to say later. Nothing is sent: it is '
                    'kept privately in Therabot › Saved notes, for you to '
                    'share yourself later if you choose.'
              : 'A quiet place to untangle your thoughts while you wait. This is just for you.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final s in starters)
              ActionChip(label: Text(s), onPressed: () => _start(s)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: widget.draft ? 'Your draft' : 'Your thoughts',
          controller: _text,
          maxLength: 2000,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.md),
        PrivacyNote(
          '${widget.partnerName} can\'t see this, and Therabot doesn\'t read it. '
          'It does not change your approved summary.',
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Keep it privately',
          onPressed: _save,
          isLoading: _saving,
          fullWidth: true,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- completion

/// "We're okay for now", then "Did anything help today?". A suggested
/// insight is only ever saved when you tap Save.
class TherabotCompletionPage extends StatefulWidget {
  const TherabotCompletionPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<TherabotCompletionPage> createState() => _TherabotCompletionPageState();
}

enum _Helped { asking, yes, notReally }

class _TherabotCompletionPageState extends State<TherabotCompletionPage> {
  _Helped _step = _Helped.asking;
  final _insight = TextEditingController();
  List<String> _suggestions = const [];
  bool _loadingSuggestions = false;
  bool _saving = false;
  bool _saved = false;

  @override
  void dispose() {
    _insight.dispose();
    super.dispose();
  }

  Future<void> _yes() async {
    setState(() {
      _step = _Helped.yes;
      _loadingSuggestions = true;
    });
    try {
      // Your own private summary, if it is still within its 24 hours.
      final mine = await TherabotService.mySubmission(widget.sessionId);
      _suggestions = mine?.summary?.suggestedInsights ?? const [];
    } catch (_) {
      _suggestions = const [];
    }
    if (!mounted) return;
    setState(() {
      _loadingSuggestions = false;
      if (_suggestions.isNotEmpty) _insight.text = _suggestions.first;
    });
  }

  Future<void> _save() async {
    final text = _insight.text.trim();
    if (text.isEmpty) {
      therabotToast(context, 'Write a few words first.');
      return;
    }
    // Counted the way the database counts (code points).
    if (text.runes.length > therabotMaxInsightLength) {
      therabotToast(
        context,
        'Keep it to $therabotMaxInsightLength characters.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await TherabotService.saveInsight(text, sessionId: widget.sessionId);
      if (!mounted) return;
      showFloatingHearts(context, emoji: '✨');
      setState(() => _saved = true);
    } catch (e) {
      if (!mounted) return;
      therabotToast(context, therabotError(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _done() => Navigator.of(context).pop(true);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final Widget body = switch (_step) {
      _Helped.asking => Column(
        key: const ValueKey('asking'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Did anything help today?', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('Only you see your answer.', style: muted),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Yes', onPressed: _yes, fullWidth: true),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Not really',
            variant: AppButtonVariant.outlined,
            onPressed: () => setState(() => _step = _Helped.notReally),
            fullWidth: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(onPressed: _done, child: const Text('Skip')),
          ),
        ],
      ),
      _Helped.notReally => Column(
        key: const ValueKey('not-really'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TherabotCard(
            tinted: true,
            child: Text(
              "Thank you for being honest. Some days are just hard, and that's okay. "
              'You showed up for each other, and that counts. 💗',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Done', onPressed: _done, fullWidth: true),
        ],
      ),
      _Helped.yes =>
        _loadingSuggestions
            ? const TherabotThinking(
                key: ValueKey('loading'),
                lines: ['One moment…'],
              )
            : Column(
                key: const ValueKey('yes'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Something you'd like to remember?",
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _suggestions.isEmpty
                        ? 'Write one small thing that helped, in your own words.'
                        : 'Therabot suggested this from your own reflection. Change it, or '
                              'write your own.',
                    style: muted,
                  ),
                  if (_suggestions.length > 1) ...[
                    const SizedBox(height: AppSpacing.md),
                    // Full text, wrapped: tap one to put it in the box below.
                    for (final s in _suggestions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.input,
                              ),
                            ),
                          ),
                          onPressed: _saved ? null : () => _insight.text = s,
                          child: Text(s, softWrap: true),
                        ),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'My insight',
                    controller: _insight,
                    hintText:
                        'e.g. A short walk helps me cool down before we talk',
                    maxLength: therabotMaxInsightLength,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const PrivacyNote(
                    'Insights are private to you. You can delete them any time.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (_saved) ...[
                    TherabotCard(
                      tinted: true,
                      child: Text(
                        'Saved to your insights ✨',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(label: 'Done', onPressed: _done, fullWidth: true),
                  ] else ...[
                    AppButton(
                      label: 'Save to my insights',
                      icon: Icons.bookmark_add_outlined,
                      onPressed: _save,
                      isLoading: _saving,
                      fullWidth: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Not now',
                      variant: AppButtonVariant.outlined,
                      onPressed: _saving ? null : _done,
                      fullWidth: true,
                    ),
                  ],
                ],
              ),
    };

    return TherabotPage(
      title: "We're okay for now",
      children: [
        Text(
          '💗',
          style: theme.textTheme.displayLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          "Thank you for taking care of each other today. You don't have to have it "
          'all figured out.',
          textAlign: TextAlign.center,
          style: muted,
        ),
        const SizedBox(height: AppSpacing.xxl),
        AnimatedSwitcher(
          duration: Duration(milliseconds: motionOff(context) ? 0 : 300),
          child: body,
        ),
      ],
    );
  }
}
