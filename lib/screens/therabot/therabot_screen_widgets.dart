part of 'therabot_screen.dart';

// The Therabot hub's smaller pieces: the rename dialog, header, session
// card, the two people, action cards and the privacy note.

/// Owns its text controller, so it is disposed only after the dialog has
/// finished closing.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this reflection'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            maxLength: 60,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. The weekend plans',
            ),
          ),
          Text(
            'Either of you can rename it until you have both chosen a next step. '
            'Then the name is kept for your history.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// "Therabot" and its line, a small glowing reflection mark, and the menu.
class _HubHeader extends StatelessWidget {
  const _HubHeader({required this.menu});

  final Widget menu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Therabot opens as a page from Home, so it needs its own way back.
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canPop)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const UsIcon(UsIcons.back, size: 22),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Therabot',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: NotePalette.cream,
                  ),
                ),
              ),
              Text(
                'Private relationship reflection',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: NotePalette.muted,
                ),
              ),
            ],
          ),
        ),
        menu,
      ],
    );
  }
}

/// THIS SESSION: you and your partner side by side, joined by a small
/// heart, with each of your statuses and the time left underneath.
class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.title,
    required this.me,
    required this.partner,
    required this.partnerName,
    required this.myStatus,
    required this.myActive,
    required this.myDone,
    required this.partnerStatus,
    required this.partnerDone,
    required this.expiresAt,
  });

  final String? title;
  final Profile? me;
  final Profile? partner;
  final String partnerName;
  final String myStatus;
  final bool myActive;
  final bool myDone;
  final String partnerStatus;
  final bool partnerDone;
  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final avatar = narrow ? 56.0 : 66.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: therabotCardDecoration(radius: AppRadius.panel + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            (title ?? 'This session').toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: NotePalette.muted,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Person(
                  name: 'You',
                  realName: me?.displayName ?? 'You',
                  imageUrl: me?.avatarUrl,
                  status: myStatus,
                  active: myActive && !myDone,
                  done: myDone,
                  size: avatar,
                ),
              ),
              // The heart between you, at avatar height.
              SizedBox(
                height: avatar,
                width: narrow ? 56 : 76,
                child: const _HeartLink(),
              ),
              Expanded(
                child: _Person(
                  name: partnerName,
                  realName: partner?.displayName ?? partnerName,
                  imageUrl: partner?.avatarUrl,
                  status: partnerStatus,
                  active: false,
                  done: partnerDone,
                  size: avatar,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(height: 1, color: NotePalette.pink.withValues(alpha: 0.15)),
          const SizedBox(height: AppSpacing.md),
          ExpiryNote(expiresAt: expiresAt),
        ],
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({
    required this.name,
    required this.realName,
    required this.imageUrl,
    required this.status,
    required this.active,
    required this.done,
    required this.size,
  });

  final String name;
  final String realName;
  final String? imageUrl;
  final String status;
  final bool active;
  final bool done;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$name: $status',
      excludeSemantics: true,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: NotePalette.pink.withValues(
                      alpha: done || active ? 0.75 : 0.3,
                    ),
                    width: 1.5,
                  ),
                ),
                child: AvatarCircle(
                  name: realName,
                  imageUrl: imageUrl,
                  size: size,
                  background: UsPalette.cardRaised,
                ),
              ),
              if (done)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: NotePalette.background,
                      shape: BoxShape.circle,
                    ),
                    child: const UsIcon(UsIcons.check,
                      size: 18,
                      color: NotePalette.pink,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: NotePalette.cream,
            ),
          ),
          Text(
            status,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: active || done ? NotePalette.pink : NotePalette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two thin lines with a quiet dot between them (steps of the flow).
class _HeartLink extends StatelessWidget {
  const _HeartLink();

  @override
  Widget build(BuildContext context) {
    Widget line() => Expanded(
      child: Container(
        height: 1,
        color: NotePalette.pink.withValues(alpha: 0.35),
      ),
    );
    return ExcludeSemantics(
      child: Row(
        children: [
          line(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: NotePalette.muted,
                shape: BoxShape.circle,
              ),
            ),
          ),
          line(),
        ],
      ),
    );
  }
}

/// The one main thing to do now: a burgundy card with a title, a line or
/// two, and the big pink button.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.body,
    this.button,
    this.onPressed,
    this.secondary,
    this.quiet = false,
  });

  final UsIconData icon;
  final String title;
  final String body;
  final String? button;
  final VoidCallback? onPressed;
  final Widget? secondary;

  /// A secondary card: plain plum, outlined button, so the main action
  /// stays the strongest thing on the screen.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: UsPalette.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: UsPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1, right: AppSpacing.md),
                child: UsIcon(icon, size: 20, color: NotePalette.pink),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: NotePalette.cream,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: NotePalette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (button != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: button!,
              variant: quiet
                  ? AppButtonVariant.outlined
                  : AppButtonVariant.filled,
              fullWidth: true,
              onPressed: onPressed,
            ),
          ],
          if (secondary != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(alignment: Alignment.centerLeft, child: secondary),
          ],
        ],
      ),
    );
  }
}

/// The one privacy line on the hub, matching what Therabot really does:
/// neither of you ever sees the other's answers or private summary.
class _PrivacyBlock extends StatelessWidget {
  const _PrivacyBlock({required this.partnerName});

  final String partnerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1, right: AppSpacing.sm),
          child: UsIcon(UsIcons.lock, size: 16, color: NotePalette.muted),
        ),
        Expanded(
          child: Text(
            'Only you see your answers. A shared reflection uses short '
            'summaries, never your words.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: NotePalette.muted,
            ),
          ),
        ),
      ],
    );
  }
}
