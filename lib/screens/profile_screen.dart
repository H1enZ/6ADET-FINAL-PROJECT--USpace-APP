import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../services/profile_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/app_text_field.dart';
import '../widgets/atoms/avatar_circle.dart';
import '../widgets/atoms/section_label.dart';
import 'splash_screen.dart';

/// Your profile: photo, name, birthday, and your partner at a glance.
/// You can only change your own details (the database enforces it).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Profile _me = widget.profile;
  Profile? _partner;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Runs a change, shows a message, and reloads. Blocks double taps.
  Future<void> _run(Future<void> Function() change, String done) async {
    setState(() => _busy = true);
    try {
      await change();
      await _load();
      if (!mounted) return;
      _showMessage(done);
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- photo

  Future<void> _photoOptions() async {
    final hasPhoto = _me.avatarPath != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(hasPhoto ? 'Choose a new photo' : 'Add a photo'),
              onTap: () => Navigator.of(context).pop('pick'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () => Navigator.of(context).pop('remove'),
              ),
          ],
        ),
      ),
    );
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
      _showMessage('That photo could not be opened. Try another one.');
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
      _showMessage(friendlyError(e));
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
    final muted =
        theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final birthday = _me.birthday;
    final partner = _partner;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          maxWidth: AppSpacing.formMaxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            Text(_error!,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: scheme.error)),
                            const SizedBox(height: AppSpacing.lg),
                          ],

                          // Photo with a camera button
                          Center(
                            child: Stack(
                              children: [
                                AvatarCircle(
                                  name: _me.displayName,
                                  imageUrl: _me.avatarUrl,
                                  size: 112,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: IconButton.filled(
                                    tooltip: 'Change photo',
                                    onPressed: _busy ? null : _photoOptions,
                                    icon: const Icon(
                                        Icons.photo_camera_outlined),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Name
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  _me.displayName,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit name',
                                onPressed: _busy ? null : _editName,
                                icon: const Icon(Icons.edit_outlined, size: 20),
                              ),
                            ],
                          ),
                          Text(AuthService.user?.email ?? '',
                              textAlign: TextAlign.center, style: muted),
                          const SizedBox(height: AppSpacing.xxxl),

                          // Birthday
                          SectionLabel(
                            text: 'Birthday',
                            actionLabel: birthday == null ? 'Add' : 'Change',
                            onAction: _busy ? null : _pickBirthday,
                          ),
                          if (birthday == null)
                            Text(
                              'Add your birthday so your partner gets a '
                              'countdown on Home. Only the two of you can see it.',
                              style: muted,
                            )
                          else ...[
                            Text(longDate(birthday),
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              birthdayLine(
                                birthday: birthday,
                                isMe: true,
                                name: _me.displayName,
                              ),
                              style: muted,
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: _busy ? null : _removeBirthday,
                                child: const Text('Remove birthday'),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xxl),

                          // Partner
                          if (partner != null) ...[
                            const SectionLabel(text: 'Your partner'),
                            Row(
                              children: [
                                AvatarCircle(
                                  name: partner.displayName,
                                  imageUrl: partner.avatarUrl,
                                  size: 48,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(partner.displayName,
                                          style: theme.textTheme.titleMedium),
                                      Text(
                                        partner.birthday == null
                                            ? 'No birthday added yet'
                                            : birthdayLine(
                                                birthday: partner.birthday!,
                                                isMe: false,
                                                name: partner.displayName,
                                              ),
                                        style: muted,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                          ],

                          // Account
                          const SectionLabel(text: 'Account'),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: AppButton(
                              label: 'Sign out',
                              icon: Icons.logout,
                              variant: AppButtonVariant.outlined,
                              onPressed: _busy ? null : _signOut,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),

                          // Danger zone
                          SectionLabel(
                              text: partner == null ? 'Leave this space' : 'Unlink partner'),
                          Text(
                            partner == null
                                ? 'Nobody else has joined yet. Leaving deletes this space '
                                    'and everything in it.'
                                : 'You will leave the space you share with '
                                    '${partner.displayName}. They keep your memories, notes '
                                    'and bucket list, and get a new invite code.',
                            style: muted,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _unlink,
                              icon: const Icon(Icons.link_off),
                              label: Text(partner == null ? 'Leave this space' : 'Unlink partner'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: scheme.error,
                                side: BorderSide(color: scheme.error),
                                minimumSize: const Size(64, AppSpacing.touchTarget),
                              ),
                            ),
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
            prefixIcon: Icons.person_outline,
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
      icon: Icon(Icons.link_off, color: scheme.error),
      title: Text(name == null ? 'Leave this space?' : 'Unlink from $name?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text('\u2022  $p', style: theme.textTheme.bodyMedium),
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
