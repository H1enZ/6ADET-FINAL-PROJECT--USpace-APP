import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../services/profile_service.dart';
import '../theme/app_spacing.dart';
import '../theme/us_palette.dart';
import '../utils/anniversary.dart';
import '../widgets/atoms/app_text_field.dart';
import '../widgets/atoms/avatar_circle.dart';
import '../widgets/atoms/us_icon.dart';
import '../widgets/atoms/section_label.dart';
import 'splash_screen.dart';
import '../widgets/effects/smooth_scroll.dart';
import '../widgets/molecules/us_states.dart';
import '../widgets/effects/motion.dart';
import '../services/couple_sync.dart';

/// Your profile: photo, name, birthday, and your partner at a glance.
/// You can only change your own details (the database enforces it).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Mouse-wheel scrolling glides instead of jumping.
  final _scroll = SmoothScrollController();

  late Profile _me = widget.profile;
  Profile? _partner;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  CoupleSyncHandle? _live;

  @override
  void initState() {
    super.initState();
    _load();
    // Your partner's name, photo and birthday, and the anniversary.
    try {
      _live = CoupleSync.listen(widget.profile.coupleId!, const {'profiles', 'couples'}, () {
        if (mounted) _load();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _live?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final coupleId = widget.profile.coupleId!;
      final members =
          await ProfileService.withPhotos(await CoupleService.members(coupleId));
      if (!mounted) return;
      setState(() {
        for (final m in members) {
          if (m.userId == widget.profile.userId) {
            _me = m;
          } else {
            _partner = m;
          }
        }
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

  void _showMessage(String text, {bool error = false}) =>
      showUsMessage(context, text, error: error);

  /// Runs a change, shows a message, and reloads. Blocks double taps.
  Future<void> _run(Future<void> Function() change, String done) async {
    setState(() => _busy = true);
    try {
      await change();
      await _load();
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- photo

  Future<void> _photoOptions() async {
    final hasPhoto = _me.avatarPath != null;
    final choice = await _showActions(context, [
      (
        'pick',
        UsIcons.image,
        hasPhoto ? 'Choose a new photo' : 'Add a photo',
        false,
      ),
      if (hasPhoto) ('remove', UsIcons.trash, 'Remove photo', true),
    ]);
    if (choice == 'pick') await _pickPhoto();
    if (choice == 'remove') {
      final path = _me.avatarPath!;
      await _run(() => ProfileService.removePhoto(path), 'Photo removed');
    }
  }

  Future<void> _pickPhoto() async {
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
    } catch (_) {
      _showMessage('That photo could not be opened. Try another one.', error: true);
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final dot = file.name.lastIndexOf('.');
    final ext = dot == -1 ? 'jpg' : file.name.substring(dot + 1);
    final oldPath = _me.avatarPath;
    await _run(
      () => ProfileService.uploadPhoto(bytes, ext, oldPath: oldPath),
      'Photo updated',
    );
  }

  // ---------- name

  Future<void> _editName() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(current: _me.displayName),
    );
    if (name == null || name == _me.displayName) return;
    await _run(() => ProfileService.updateName(name), 'Name updated');
  }

  // ---------- birthday

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _me.birthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.input,
      helpText: 'Your birthday',
    );
    if (picked == null) return;
    await _run(() => ProfileService.updateBirthday(picked), 'Birthday saved');
  }

  Future<void> _removeBirthday() async {
    await _run(() => ProfileService.updateBirthday(null), 'Birthday removed');
  }

  /// No birthday yet: straight to the picker. Otherwise change or remove.
  Future<void> _birthdayOptions() async {
    if (_me.birthday == null) return _pickBirthday();
    final choice = await _showActions(context, [
      ('change', UsIcons.calendar, 'Change date', false),
      ('remove', UsIcons.trash, 'Remove birthday', true),
    ]);
    if (choice == 'change') await _pickBirthday();
    if (choice == 'remove') await _removeBirthday();
  }

  Future<void> _unlink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _UnlinkDialog(partnerName: _partner?.displayName),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await CoupleService.leaveCouple();
      if (!mounted) return;
      restartFlow(context); // back to Splash, which now opens Pair
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(friendlyError(e), error: true);
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (!mounted) return;
    restartFlow(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final birthday = _me.birthday;
    final partner = _partner;
    final leaving = partner == null ? 'Leave this space' : 'Unlink partner';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const SkeletonList(count: 4, height: 72)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.sm,
                  AppSpacing.screenMargin,
                  AppSpacing.huge,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppSpacing.formMaxWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            UsErrorNotice(message: _error!, onRetry: _load),
                            const SizedBox(height: AppSpacing.lg),
                          ],

                          // Photo, name, email.
                          Center(
                            child: _AvatarButton(
                              profile: _me,
                              onTap: _busy ? null : _photoOptions,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            _me.displayName,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            AuthService.user?.email ?? '',
                            textAlign: TextAlign.center,
                            style: muted,
                          ),
                          const SizedBox(height: AppSpacing.xxxl),

                          _Group(
                            label: 'You',
                            children: [
                              _Row(
                                icon: UsIcons.profile,
                                title: 'Name',
                                value: _me.displayName,
                                onTap: _busy ? null : _editName,
                              ),
                              _Row(
                                icon: UsIcons.calendar,
                                title: 'Birthday',
                                value: birthday == null
                                    ? 'Add'
                                    : longDate(birthday),
                                subtitle: birthday == null
                                    ? 'Your partner gets a countdown on Home.'
                                    : birthdayLine(
                                        birthday: birthday,
                                        isMe: true,
                                        name: _me.displayName,
                                      ),
                                onTap: _busy ? null : _birthdayOptions,
                              ),
                            ],
                          ),

                          if (partner != null)
                            _Group(
                              label: 'Your partner',
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(
                                    AppSpacing.cardPadding,
                                  ),
                                  child: Row(
                                    children: [
                                      AvatarCircle(
                                        name: partner.displayName,
                                        imageUrl: partner.avatarUrl,
                                        size: 44,
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              partner.displayName,
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                            Text(
                                              partner.birthday == null
                                                  ? 'No birthday added yet'
                                                  : birthdayLine(
                                                      birthday:
                                                          partner.birthday!,
                                                      isMe: false,
                                                      name:
                                                          partner.displayName,
                                                    ),
                                              style: muted,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                          _Group(
                            label: 'Account',
                            children: [
                              _Row(
                                icon: UsIcons.logout,
                                title: 'Sign out',
                                onTap: _busy ? null : _signOut,
                                chevron: false,
                              ),
                            ],
                          ),

                          _Group(
                            label: 'Your space',
                            children: [
                              _Row(
                                icon: UsIcons.unlink,
                                title: leaving,
                                subtitle: partner == null
                                    ? 'Nobody else has joined yet. Leaving '
                                          'deletes this space and everything '
                                          'in it.'
                                    : '${partner.displayName} keeps your '
                                          'memories, notes and bucket list, '
                                          'and gets a new invite code.',
                                destructive: true,
                                onTap: _busy ? null : _unlink,
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

/// A small sheet of actions; returns the chosen key, or null.
Future<String?> _showActions(
  BuildContext context,
  List<(String, UsIconData, String, bool)> actions,
) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (key, icon, label, destructive) in actions)
                ListTile(
                  minTileHeight: 56,
                  leading: UsIcon(
                    icon,
                    size: 22,
                    color: destructive ? scheme.error : scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    label,
                    style: destructive ? TextStyle(color: scheme.error) : null,
                  ),
                  onTap: () => Navigator.of(context).pop(key),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Your photo with a small, quiet camera badge. The whole thing is the button.
class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.profile, required this.onTap});

  final Profile profile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Change photo',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 56,
        child: Stack(
          children: [
            AvatarCircle(
              name: profile.displayName,
              imageUrl: profile.avatarUrl,
              size: 96,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: UsPalette.cardRaised,
                  shape: BoxShape.circle,
                  border: Border.all(color: UsPalette.lineStrong),
                ),
                child: UsIcon(
                  UsIcons.camera,
                  size: 16,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled card of rows, split by hairlines.
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(text: label),
          Material(
            color: UsPalette.card,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: UsPalette.line),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: AppSpacing.cardPadding,
                      color: UsPalette.line,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One settings row: icon, title (and a quiet line under it), the current
/// value on the right, and a chevron when it opens something.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.subtitle,
    this.destructive = false,
    this.chevron = true,
  });

  final UsIconData icon;
  final String title;
  final String? value;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: [title, value, subtitle].whereType<String>().join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardPadding,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                UsIcon(
                  icon,
                  size: 22,
                  color: destructive ? scheme.error : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: destructive ? scheme.error : scheme.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      value!,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                if (chevron) ...[
                  const SizedBox(width: AppSpacing.xs),
                  UsIcon(
                    UsIcons.chevronRight,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Owns its text controller, so it is disposed only when the dialog is gone.
class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.current});

  final String current;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final _name = TextEditingController(text: widget.current);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter the name your partner will see.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Your name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Name',
            controller: _name,
            usIcon: UsIcons.profile,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// Asks for confirmation by typing CONFIRM (then Enter), so it cannot happen by accident.
/// Closes with `true` only when confirmed.
class _UnlinkDialog extends StatefulWidget {
  const _UnlinkDialog({required this.partnerName});

  /// Null when nobody has joined yet.
  final String? partnerName;

  @override
  State<_UnlinkDialog> createState() => _UnlinkDialogState();
}

class _UnlinkDialogState extends State<_UnlinkDialog> {
  final _typed = TextEditingController();

  @override
  void initState() {
    super.initState();
    _typed.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  static const _word = 'CONFIRM';

  bool get _ready => _typed.text.trim().toUpperCase() == _word;

  /// Typing CONFIRM and pressing Enter unlinks, no click needed.
  void _submit() {
    if (_ready) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = widget.partnerName;
    final points = name == null
        ? [
            'This space and everything in it will be deleted.',
            'You can start a new space or join someone else afterwards.',
          ]
        : [
            "You won't see your shared memories, notes, bucket list or chat anymore.",
            '$name keeps everything, including what you added.',
            '$name gets a new invite code. You can only rejoin if they send it to you.',
            'This cannot be undone.',
          ];

    return AlertDialog(
      icon: UsIcon(UsIcons.unlink, size: 28, color: scheme.error),
      title: Text(name == null ? 'Leave this space?' : 'Unlink from $name?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('\u2022  ', style: theme.textTheme.bodyMedium),
                    Expanded(
                      child: Text(p, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Type $_word and press Enter',
              controller: _typed,
              hintText: _word,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _ready
                  ? 'Press Enter to ${name == null ? 'leave' : 'unlink'}.'
                  : 'Nothing happens until you type $_word.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: _ready ? scheme.error : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _ready ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          child: Text(name == null ? 'Leave' : 'Unlink'),
        ),
      ],
    );
  }
}
