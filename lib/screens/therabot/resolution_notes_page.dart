// Our saved resolution notes (opened from Therabot) and the six-question
// resolution page used to continue a paused one.
import 'package:flutter/material.dart';

import '../../models/resolution_note.dart';
import '../../services/auth_service.dart';
import '../../services/support_service.dart';
import '../../theme/app_spacing.dart';
import '../../utils/daily_content.dart';
import '../../widgets/atoms/app_button.dart';
import '../../widgets/atoms/app_text_field.dart';
import '../../widgets/effects/floating_hearts.dart';
import '../../widgets/effects/motion.dart';
import '../../widgets/molecules/us_states.dart';
import '../../widgets/atoms/us_icon.dart';

/// Shown on every resolution page. Disagreements are normal;
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

void _toast(BuildContext context, String text, {bool error = false}) =>
    showUsMessage(context, text, error: error);



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
  // One box per question, filled in when continuing a saved note.
  late final List<TextEditingController> _fields = [
    for (var i = 0; i < resolutionQuestions.length; i++)
      TextEditingController(text: widget.note?.answers[i].$2),
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
      _toast(context, done ? 'Saved. Thank you for working on this together.' : 'Saved. Come back whenever you are ready.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _toast(context, friendlyError(e), error: true);
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
      _toast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const needLabels = {
      'solution': 'Solution',
      'comfort': 'Comfort',
      'affection': 'Affection',
      'listen': 'Listen',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Our saved notes')),
      body: _loading
          ? const SkeletonList()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                children: [
                  if (_error != null) ...[
                    UsErrorNotice(message: _error!, onRetry: _load),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (_notes.isEmpty && _error == null)
                    const UsEmptyState(
                      icon: UsIcons.note,
                      title: 'No saved notes yet',
                      message: 'They appear here when you save one.',
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
