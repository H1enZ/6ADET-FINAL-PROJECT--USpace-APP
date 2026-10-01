import 'package:flutter/material.dart';

import '../models/resolution_note.dart';
import '../services/affection_service.dart';
import '../services/auth_service.dart';
import '../services/support_service.dart';
import '../theme/app_spacing.dart';
import '../utils/daily_content.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/app_text_field.dart';
import '../widgets/atoms/section_label.dart';
import '../widgets/effects/floating_hearts.dart';

/// "Let's work it out": us, not the problem. Not about who is right. It
/// helps one partner say what they need right now, and lets the couple
/// take a break and come back later. Safety always comes first.
class WorkItOutScreen extends StatelessWidget {
  const WorkItOutScreen({
    super.key,
    required this.coupleId,
    required this.myUserId,
    required this.partnerName,
  });

  final String coupleId;
  final String myUserId;
  final String partnerName;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final needs = [
      (
        '💡', 'I need a solution',
        'Think it through calmly and find one next step together.',
        _SolutionPage(coupleId: coupleId, partnerName: partnerName),
      ),
      (
        '🫂', 'I need comfort',
        'Be heard and held, not fixed. Or comfort your partner.',
        _ComfortPage(coupleId: coupleId, partnerName: partnerName),
      ),
      (
        '❤️', 'I need affection',
        'Send a hug, a kiss or a cuddle, only if it feels right.',
        _AffectionPage(coupleId: coupleId, partnerName: partnerName),
      ),
      (
        '👂', 'I just need you to listen',
        'Say it all, without advice or interruptions.',
        _ListenPage(coupleId: coupleId, partnerName: partnerName),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Let's work it out")),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Us, not the problem.',
                      style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('What do you need from me right now?',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "This isn't about who is right. Pick what would help most. "
                    'You can pause and come back any time.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  for (final n in needs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Material(
                        color: scheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          side: BorderSide(color: scheme.outline),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _open(context, n.$4),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Row(
                              children: [
                                Text(n.$1, style: const TextStyle(fontSize: 32)),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n.$2, style: theme.textTheme.titleMedium),
                                      const SizedBox(height: 2),
                                      Text(n.$3,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                              color: scheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Ready to reconnect? (6 questions)',
                    icon: Icons.handshake_outlined,
                    variant: AppButtonVariant.outlined,
                    fullWidth: true,
                    onPressed: () => _open(
                        context, ResolutionPage(coupleId: coupleId, need: 'solution')),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Our saved notes',
                    icon: Icons.bookmark_outline,
                    variant: AppButtonVariant.outlined,
                    fullWidth: true,
                    onPressed: () => _open(
                      context,
                      ResolutionNotesPage(
                          coupleId: coupleId, myUserId: myUserId, partnerName: partnerName),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SafetyCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown on every "Let's work it out" page. Disagreements are normal;
/// fear, threats and control are not, and are not something to work out.
class SafetyCard extends StatelessWidget {
  const SafetyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyMedium;
    Widget line(String who, String number) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(who, style: body)),
              SelectableText(number,
                  style: theme.textTheme.labelLarge?.copyWith(color: scheme.error)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: scheme.error.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: scheme.error),
              const SizedBox(width: AppSpacing.sm),
              Text('Are you safe?', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'If anyone is hurting you, threatening you, controlling you, or you feel '
            'afraid, your safety comes first. That is not something to "work out" '
            'here, and you never have to make up, forgive or stay.',
            style: body,
          ),
          const SizedBox(height: AppSpacing.sm),
          line('Immediate danger', '911'),
          line('Abuse or violence by a partner (PNP Women and Children Protection Center)',
              '0919 777 7377'),
          line('Emotional crisis (National Center for Mental Health)', '0917 899 8727'),
          const SizedBox(height: AppSpacing.md),
          Text(
            'USpace is not therapy or counselling. If things keep feeling hard, '
            'talking to a counsellor can really help.',
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Shared page layout: a title, a gentle intro, the content, and the safety
/// card at the bottom.
class _NeedPage extends StatelessWidget {
  const _NeedPage({required this.title, required this.intro, required this.children});

  final String title;
  final String intro;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(intro,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.xl),
                  ...children,
                  const SizedBox(height: AppSpacing.xxl),
                  const SafetyCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

// ------------------------------------------------------------------ solution

class _SolutionPage extends StatefulWidget {
  const _SolutionPage({required this.coupleId, required this.partnerName});

  final String coupleId;
  final String partnerName;

  @override
  State<_SolutionPage> createState() => _SolutionPageState();
}

class _SolutionPageState extends State<_SolutionPage> {
  final _fields = List.generate(4, (_) => TextEditingController());
  bool _shared = true;
  bool _saving = false;

  static const _prompts = [
    'What happened?',
    'What are you feeling?',
    'What do you wish your partner understood?',
    'What is one thing that could help resolve this?',
  ];

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_fields.every((c) => c.text.trim().isEmpty)) {
      _toast(context, 'Write at least one answer first.');
      return;
    }
    setState(() => _saving = true);
    try {
      // what happened, feeling, what we need, -, -, what could help
      await SupportService.save(
        coupleId: widget.coupleId,
        need: 'solution',
        answers: [_fields[0].text, _fields[1].text, _fields[2].text, '', '', _fields[3].text],
        shared: _shared,
        done: false,
      );
      if (!mounted) return;
      _toast(context, _shared ? 'Saved and shared with ${widget.partnerName}' : 'Saved privately');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _NeedPage(
      title: 'I need a solution',
      intro: 'Write it down first. It helps to slow down before talking it through.',
      children: [
        for (var i = 0; i < 4; i++) ...[
          AppTextField(
            label: _prompts[i],
            controller: _fields[i],
            maxLength: 2000,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const SectionLabel(text: 'Talking it through calmly'),
        for (final tip in const [
          'Talk about one thing at a time.',
          'Say "I feel… when…" instead of "You always…".',
          'Listen to understand, not to reply.',
          'If it gets heated, take a 20-minute break and agree when to come back.',
          'Look for one small step you can both try, not a perfect answer.',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text('\u2022  $tip', style: theme.textTheme.bodyMedium),
          ),
        const SizedBox(height: AppSpacing.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _shared,
          onChanged: (v) => setState(() => _shared = v),
          title: Text('Share with ${widget.partnerName}'),
          subtitle: Text(_shared ? 'You can both read it in Our saved notes.' : 'Only you will see it.'),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(label: 'Save', onPressed: _save, isLoading: _saving, fullWidth: true),
      ],
    );
  }
}

// ------------------------------------------------------------------ comfort

class _ComfortPage extends StatefulWidget {
  const _ComfortPage({required this.coupleId, required this.partnerName});

  final String coupleId;
  final String partnerName;

  @override
  State<_ComfortPage> createState() => _ComfortPageState();
}

class _ComfortPageState extends State<_ComfortPage> {
  final _feelings = TextEditingController();
  final _comfort = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _feelings.dispose();
    _comfort.dispose();
    super.dispose();
  }

  Future<void> _send(String kind, String text, String done) async {
    if (text.trim().isEmpty) {
      _toast(context, 'Write something first.');
      return;
    }
    setState(() => _sending = true);
    try {
      await AffectionService.send(coupleId: widget.coupleId, kind: kind, message: text);
      if (!mounted) return;
      showFloatingHearts(context, emoji: '💗');
      _toast(context, done);
      _feelings.clear();
      _comfort.clear();
    } catch (e) {
      if (!mounted) return;
      _toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const phrases = [
      "I'm here for you.",
      "You don't have to go through this alone.",
      "I'm listening. Take your time.",
      'Do you want me to just listen, or help?',
      "Whatever you're feeling makes sense to me.",
    ];
    return _NeedPage(
      title: 'I need comfort',
      intro: "Sometimes we don't need it fixed. We just need to feel held.",
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Text(
            "It's okay to not be okay. Whatever you're carrying right now, "
            "you don't have to carry it alone. 🫂",
            style: theme.textTheme.titleMedium?.copyWith(color: scheme.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionLabel(text: 'Tell your partner how you feel'),
        AppTextField(
          label: 'How are you feeling?',
          controller: _feelings,
          maxLength: 1000,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Ask ${widget.partnerName} to listen',
          icon: Icons.favorite_border,
          onPressed: _sending
              ? null
              : () => _send('listen', _feelings.text,
                  '${widget.partnerName} will see that you need them'),
          fullWidth: true,
        ),
        const SizedBox(height: AppSpacing.xxl),
        const SectionLabel(text: 'Or comfort your partner'),
        Text('Tap a phrase to send it, or write your own:',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final p in phrases)
              ActionChip(
                label: Text(p),
                onPressed: _sending
                    ? null
                    : () => _send('comfort', p, 'Comfort sent to ${widget.partnerName} 💗'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Your own comforting message',
          controller: _comfort,
          maxLength: 1000,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Send comfort',
          variant: AppButtonVariant.outlined,
          onPressed: _sending
              ? null
              : () => _send('comfort', _comfort.text, 'Comfort sent to ${widget.partnerName} 💗'),
          fullWidth: true,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ affection

class _AffectionPage extends StatefulWidget {
  const _AffectionPage({required this.coupleId, required this.partnerName});

  final String coupleId;
  final String partnerName;

  @override
  State<_AffectionPage> createState() => _AffectionPageState();
}

class _AffectionPageState extends State<_AffectionPage> {
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send(String kind, String emoji, String label) async {
    setState(() => _sending = true);
    try {
      await AffectionService.send(coupleId: widget.coupleId, kind: kind, message: _note.text);
      if (!mounted) return;
      showFloatingHearts(context, emoji: emoji);
      _toast(context, '$label sent to ${widget.partnerName} $emoji');
      _note.clear();
    } catch (e) {
      if (!mounted) return;
      _toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gestures = [
      ('hug', '🫂', 'A big warm hug'),
      ('kiss', '💋', 'A kiss'),
      ('cuddle', '🤗', 'A cuddle'),
    ];
    return _NeedPage(
      title: 'I need affection',
      intro: 'Send a little love. Only if it feels right for both of you: '
          'it is always okay to say "not right now".',
      children: [
        Row(
          children: [
            for (final g in gestures)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Material(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _sending ? null : () => _send(g.$1, g.$2, g.$3),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Column(
                          children: [
                            Text(g.$2, style: const TextStyle(fontSize: 40)),
                            const SizedBox(height: AppSpacing.sm),
                            Text('Send ${g.$1 == 'hug' ? 'a hug' : g.$1 == 'kiss' ? 'a kiss' : 'a cuddle'}',
                                style: theme.textTheme.labelLarge
                                    ?.copyWith(color: scheme.onPrimaryContainer)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Add a sweet line (optional)',
          controller: _note,
          hintText: 'e.g. Wish I could hold you right now',
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('${widget.partnerName} sees it on Home with a little animation.',
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

// ------------------------------------------------------------------ listen

class _ListenPage extends StatefulWidget {
  const _ListenPage({required this.coupleId, required this.partnerName});

  final String coupleId;
  final String partnerName;

  @override
  State<_ListenPage> createState() => _ListenPageState();
}

class _ListenPageState extends State<_ListenPage> {
  final _text = TextEditingController();
  bool _busy = false;

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

  Future<void> _send() async {
    if (_text.text.trim().isEmpty) {
      _toast(context, 'Write what you want to say first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AffectionService.send(coupleId: widget.coupleId, kind: 'listen', message: _text.text);
      if (!mounted) return;
      _toast(context, 'Sent. ${widget.partnerName} will see that you want to talk.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _keepPrivate() async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await SupportService.save(
        coupleId: widget.coupleId,
        need: 'listen',
        answers: [_text.text],
        shared: false,
        done: false,
      );
      if (!mounted) return;
      _toast(context, 'Saved privately. Only you can see it.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _NeedPage(
      title: 'Just listen',
      intro: "I'm listening. Tell me what happened.",
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final s in const [
              'Today I felt…',
              "What's been on my mind is…",
              "I don't need advice, I just need…",
              'The hardest part was…',
            ])
              ActionChip(label: Text(s), onPressed: () => _start(s)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Say it all',
          controller: _text,
          maxLength: 1000,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          child: Text(
            'For ${widget.partnerName}: please read it all first. Listen to understand, '
            "not to reply. No advice unless they ask, and no \"but…\".",
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Send to ${widget.partnerName}',
          icon: Icons.send_outlined,
          onPressed: _busy ? null : _send,
          fullWidth: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Keep it private for now',
          variant: AppButtonVariant.outlined,
          onPressed: _busy ? null : _keepPrivate,
          fullWidth: true,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ resolution

/// The optional six-question resolution. Save and take a break any time;
/// nothing has to be resolved today.
class ResolutionPage extends StatefulWidget {
  const ResolutionPage({super.key, required this.coupleId, required this.need, this.note});

  final String coupleId;
  final String need;
  final ResolutionNote? note;

  @override
  State<ResolutionPage> createState() => _ResolutionPageState();
}

class _ResolutionPageState extends State<ResolutionPage> {
  late final List<TextEditingController> _fields = [
    for (final a in widget.note?.answers ?? resolutionQuestions.map((q) => (q, null)))
      TextEditingController(text: a?.$2),
  ];
  late bool _shared = widget.note?.isShared ?? true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save({required bool done}) async {
    if (_fields.every((c) => c.text.trim().isEmpty)) {
      _toast(context, 'Write at least one answer first.');
      return;
    }
    setState(() => _saving = true);
    try {
      await SupportService.save(
        coupleId: widget.coupleId,
        need: widget.note?.need ?? widget.need,
        answers: [for (final c in _fields) c.text],
        shared: _shared,
        done: done,
        id: widget.note?.id,
      );
      if (!mounted) return;
      if (done) showFloatingHearts(context);
      _toast(context, done ? 'Saved. Thank you for working on this together 💗' : 'Saved. Come back whenever you are ready.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _NeedPage(
      title: 'Ready to reconnect?',
      intro: 'Answer what you can. Skip anything that does not feel right yet. '
          'There is no rush, and no one has to apologise or forgive to finish this.',
      children: [
        for (var i = 0; i < resolutionQuestions.length; i++) ...[
          AppTextField(
            label: '${i + 1}. ${resolutionQuestions[i]}',
            controller: _fields[i],
            maxLength: 2000,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _shared,
          onChanged: (v) => setState(() => _shared = v),
          title: const Text('Share with my partner'),
          subtitle: Text(_shared ? 'You can both read it.' : 'Only you will see it.'),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'We talked it through',
          icon: Icons.favorite_border,
          onPressed: _saving ? null : () => _save(done: true),
          isLoading: _saving,
          fullWidth: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Save and take a break',
          variant: AppButtonVariant.outlined,
          onPressed: _saving ? null : () => _save(done: false),
          fullWidth: true,
        ),
      ],
    );
  }
}

/// Your notes and your partner's shared ones. Paused notes can be continued.
class ResolutionNotesPage extends StatefulWidget {
  const ResolutionNotesPage({
    super.key,
    required this.coupleId,
    required this.myUserId,
    required this.partnerName,
  });

  final String coupleId;
  final String myUserId;
  final String partnerName;

  @override
  State<ResolutionNotesPage> createState() => _ResolutionNotesPageState();
}

class _ResolutionNotesPageState extends State<ResolutionNotesPage> {
  List<ResolutionNote> _notes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notes = await SupportService.notes(widget.coupleId);
      if (!mounted) return;
      setState(() {
        _notes = notes;
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

  Future<void> _continue(ResolutionNote n) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ResolutionPage(coupleId: widget.coupleId, need: n.need, note: n),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _delete(ResolutionNote n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this note?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupportService.delete(n.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    const needLabels = {
      'solution': '💡 Solution',
      'comfort': '🫂 Comfort',
      'affection': '❤️ Affection',
      'listen': '👂 Listen',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Our saved notes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                children: [
                  if (_error != null) Text(_error!, style: TextStyle(color: scheme.error)),
                  if (_notes.isEmpty && _error == null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.huge),
                      child: Text('No notes yet. They appear here when you save one.',
                          textAlign: TextAlign.center, style: muted),
                    ),
                  for (final n in _notes)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${needLabels[n.need] ?? n.need} \u00B7 '
                                    '${n.authorId == widget.myUserId ? 'You' : widget.partnerName}',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                Chip(
                                  label: Text(n.isDone ? 'Talked through' : 'On a break'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            Text(
                              '${timeAgo(n.updatedAt)}${n.isShared ? '' : ' \u00B7 private'}',
                              style: theme.textTheme.labelSmall,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            for (final a in n.answers)
                              if (a.$2 != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(a.$1, style: theme.textTheme.labelSmall),
                                      Text(a.$2!, style: theme.textTheme.bodyMedium),
                                    ],
                                  ),
                                ),
                            if (n.authorId == widget.myUserId)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(onPressed: () => _delete(n), child: const Text('Delete')),
                                  if (!n.isDone)
                                    FilledButton.tonal(
                                      onPressed: () => _continue(n),
                                      child: const Text('Continue'),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
