import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/time_capsule_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/atoms/section_label.dart';
import '../../widgets/atoms/us_icon.dart';
import '../../utils/anniversary.dart';
import '../../utils/capsule_time.dart';
import '../../widgets/capsule/capsule_letter.dart';
import '../../widgets/capsule/candle_ceremony.dart';
import '../../widgets/capsule/monogram_seal.dart';
import '../../widgets/molecules/us_states.dart';

/// How the composer was left.
enum ComposerOutcome { sealed, deleteDraft }

/// Writing a Time Capsule: your draft, or a capsule you reopened during its
/// ten minutes ([editingId]). Saves as you type ("Saving..." / "Saved");
/// nothing reaches your partner until you seal it.
class CapsuleComposerScreen extends StatefulWidget {
  const CapsuleComposerScreen({
    super.key,
    required this.coupleId,
    required this.partnerName,
    this.myName = '',
    this.draftId,
    this.editingId,
    this.title,
    this.letter = '',
    this.unlockAt,
    this.photoPath,
    this.caption,
    this.anniversary,
  });

  final String coupleId;
  final String partnerName;

  /// Your name: its first letter is pressed into the wax seal.
  final String myName;

  /// Your existing draft, if any.
  final String? draftId;

  /// A capsule reopened during its grace period.
  final String? editingId;
  final String? title;
  final String letter;
  final DateTime? unlockAt;
  final String? photoPath;
  final String? caption;
  final DateTime? anniversary;

  @override
  State<CapsuleComposerScreen> createState() => _CapsuleComposerScreenState();
}

enum _Save { idle, saving, saved, failed }

class _CapsuleComposerScreenState extends State<CapsuleComposerScreen> {
  late final _title = TextEditingController(text: widget.title ?? '');
  late final _letter = TextEditingController(text: widget.letter);
  late final _caption = TextEditingController(text: widget.caption ?? '');
  late String? _id = widget.editingId ?? widget.draftId;
  late DateTime? _unlockAt = widget.unlockAt;
  late String? _photoPath = widget.photoPath;
  Uint8List? _photo;
  bool _photoFailed = false;
  bool _photoBusy = false;

  _Save _status = _Save.idle;
  String? _saveError;
  int _edits = 0; // bumped on every change
  int _savedEdits = 0;
  Timer? _debounce;
  Future<void> _chain = Future.value();
  bool _sealing = false;

  bool get _editing => widget.editingId != null;

  @override
  void initState() {
    super.initState();
    for (final c in [_title, _letter, _caption]) {
      c.addListener(_changed);
    }
    if (_photoPath != null) _loadPhoto();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _letter.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _loadPhoto() async {
    final path = _photoPath;
    final id = _id;
    if (path == null || id == null) return;
    setState(() => _photoFailed = false);
    try {
      // Through the capsule-photo function: your session can't read the
      // photo directly before the capsule is opened.
      final bytes = await TimeCapsuleService.previewPhoto(id);
      if (mounted && _photoPath == path) setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) setState(() => _photoFailed = true);
    }
  }

  int _lastLengths = -1;

  void _changed() {
    // Controllers also notify on selection changes; only real edits count.
    final lengths = Object.hash(_title.text, _letter.text, _caption.text);
    if (lengths == _lastLengths) return;
    _lastLengths = lengths;
    _markDirty();
  }

  void _markDirty() {
    _edits++;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), () => _save());
    if (_status != _Save.saving) setState(() => _status = _Save.idle);
  }

  bool get _isEmpty =>
      _title.text.trim().isEmpty &&
      _letter.text.trim().isEmpty &&
      _photoPath == null &&
      _unlockAt == null;

  /// Saves now (after any save already running). True when saved.
  Future<bool> _save({bool force = false}) {
    _debounce?.cancel();
    final done = _chain.then((_) => _saveOnce(force));
    _chain = done.then((_) {}, onError: (_) {});
    return done;
  }

  Future<bool> _saveOnce(bool force) async {
    final edits = _edits;
    if (_id == null && _isEmpty && !force) return true; // nothing to keep yet
    if (_id != null && edits == _savedEdits && _status == _Save.saved) {
      return true;
    }
    if (mounted) setState(() => _status = _Save.saving);
    try {
      final caption = _photoPath == null ? null : _caption.text;
      if (_editing) {
        await TimeCapsuleService.saveEdit(
          _id!,
          title: _title.text,
          letter: _letter.text,
          unlockAt: _unlockAt,
          photoPath: _photoPath,
          caption: caption,
        );
      } else {
        _id = await TimeCapsuleService.saveDraft(
          title: _title.text,
          letter: _letter.text,
          unlockAt: _unlockAt,
          photoPath: _photoPath,
          caption: caption,
        );
      }
      _savedEdits = edits;
      if (mounted) {
        setState(() {
          _status = edits == _edits ? _Save.saved : _Save.idle;
          _saveError = null;
        });
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = _Save.failed;
          _saveError = friendlyError(e);
        });
      }
      return false;
    }
  }

  void _showMessage(String text, {bool error = false}) =>
      showUsMessage(context, text, error: error);

  Future<void> _pickPhoto() async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
    } catch (e) {
      _showMessage(friendlyError(e), error: true);
      return;
    }
    if (file == null || !mounted) return;
    setState(() => _photoBusy = true);
    try {
      final bytes = await file.readAsBytes();
      final dot = file.name.lastIndexOf('.');
      final ext = dot == -1 ? 'jpg' : file.name.substring(dot + 1);
      // The photo lives in the capsule's own folder, so the capsule must
      // exist first.
      if (_id == null) {
        _edits++;
        if (!await _save(force: true) || _id == null) {
          throw AppException(
            "Couldn't start your draft. ${_saveError ?? 'Try again.'}",
          );
        }
      }
      final path = await TimeCapsuleService.uploadPhoto(
        widget.coupleId,
        _id!,
        bytes,
        ext,
      );
      final old = _photoPath;
      setState(() {
        _photoPath = path;
        _photo = bytes;
        _photoFailed = false;
      });
      _markDirty();
      if (await _save() && old != null) {
        unawaited(TimeCapsuleService.prunePhotos(_id!).catchError((_) {}));
      }
    } catch (e) {
      _showMessage(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    final old = _photoPath;
    setState(() {
      _photoPath = null;
      _photo = null;
      _caption.clear();
    });
    _markDirty();
    if (await _save() && old != null) {
      unawaited(TimeCapsuleService.prunePhotos(_id!).catchError((_) {}));
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = _unlockAt ?? now.add(const Duration(days: 1));
    final day = await showDatePicker(
      context: context,
      initialDate: current.isBefore(now) ? now : current,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 100),
      helpText: 'When should it open?',
    );
    if (day == null || !mounted) return;
    final time = TimeOfDay.fromDateTime(_unlockAt ?? DateTime(0, 1, 1, 8));
    setState(
      () => _unlockAt = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      ),
    );
    _markDirty();
  }

  Future<void> _pickTime() async {
    final current = _unlockAt ?? DateTime.now().add(const Duration(days: 1));
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_unlockAt ?? DateTime(0, 1, 1, 8)),
      helpText: 'At what time?',
    );
    if (time == null || !mounted) return;
    setState(
      () => _unlockAt = DateTime(
        current.year,
        current.month,
        current.day,
        time.hour,
        time.minute,
      ),
    );
    _markDirty();
  }

  /// Why it can't be sealed yet, or null.
  String? _problem() {
    if (_letter.text.trim().isEmpty) return 'Write your letter first.';
    final unlock = _unlockAt;
    if (unlock == null) return 'Choose when it opens.';
    if (!unlock.isAfter(
      TimeCapsuleService.now().add(const Duration(minutes: 1)),
    )) {
      return 'Choose a moment in the future for it to open.';
    }
    if (_photoBusy) return 'Wait for the photo to finish uploading.';
    return null;
  }

  Future<void> _preview() async {
    final problem = _problem();
    if (problem != null) {
      _showMessage(problem);
      return;
    }
    if (!await _save()) {
      _showMessage(
        "Couldn't save your capsule. ${_saveError ?? ''}".trim(),
        error: true,
      );
      return;
    }
    if (!mounted) return;
    final sealed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CapsulePreviewScreen(
          partnerName: widget.partnerName,
          senderName: widget.myName,
          title: _title.text.trim().isEmpty ? null : _title.text.trim(),
          letter: _letter.text,
          caption: _photoPath == null || _caption.text.trim().isEmpty
              ? null
              : _caption.text.trim(),
          hasPhoto: _photoPath != null,
          photo: _photo,
          unlockAt: _unlockAt!,
          resealing: _editing,
          onSeal: _seal,
        ),
      ),
    );
    if (sealed == true && mounted) {
      Navigator.of(context).pop(ComposerOutcome.sealed);
    }
  }

  /// Seals (after a last save). Throws with a friendly message on failure;
  /// the draft is kept either way.
  Future<void> _seal() async {
    if (_sealing) return;
    _sealing = true;
    try {
      if (!await _save()) {
        throw AppException(
          "Couldn't save your capsule. ${_saveError ?? ''}".trim(),
        );
      }
      await TimeCapsuleService.seal(_id!);
    } finally {
      _sealing = false;
    }
  }

  Future<void> _deleteDraft() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this draft?'),
        content: const Text('Your letter, photo and date will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete draft'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _save(); // so Undo brings back exactly what you wrote
    if (mounted) Navigator.of(context).pop(ComposerOutcome.deleteDraft);
  }

  Future<void> _cancelCapsule() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this capsule?'),
        content: Text(
          'It will be deleted, and ${widget.partnerName} will never know it existed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel capsule'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      _debounce?.cancel();
      await _chain;
      await TimeCapsuleService.cancel(_id!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showMessage(friendlyError(e), error: true);
    }
  }

  Widget _saveState(ThemeData theme) {
    final muted = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Semantics(
      liveRegion: true,
      child: switch (_status) {
        _Save.saving => Text('Saving...', style: muted),
        _Save.saved => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UsIcon(UsIcons.check, size: 16, color: theme.colorScheme.tertiary),
            const SizedBox(width: 4),
            Text('Saved', style: muted),
          ],
        ),
        _Save.failed => TextButton(
          onPressed: () => _save(),
          child: Text(
            "Couldn't save. Retry",
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
        _Save.idle => const SizedBox.shrink(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unlock = _unlockAt;
    final presets = capsulePresets(
      DateTime.now(),
      anniversary: widget.anniversary,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Keep what was typed before leaving.
        if (_edits != _savedEdits) await _save();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editing ? 'Edit your capsule' : 'Your time capsule'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Center(child: _saveState(theme)),
            ),
            if (!_editing && _id != null)
              IconButton(
                tooltip: 'Delete draft',
                onPressed: _deleteDraft,
                icon: const UsIcon(UsIcons.trash, size: 22),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.md,
            AppSpacing.screenMargin,
            120,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _editing
                          ? '${widget.partnerName} can\'t see this capsule while you edit. '
                                'Sealing it again starts a fresh ten minutes.'
                          : 'Only you can see this until you seal it. '
                                'It saves as you write.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // Photo first: a capsule is opened photo first, so it
                    // is written that way too.
                    const SectionLabel(text: 'Photo (optional)'),
                    if (_photoPath == null)
                      _PhotoDrop(
                        busy: _photoBusy,
                        onPick: _photoBusy ? null : _pickPhoto,
                      )
                    else ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: _photo != null
                              ? Image.memory(
                                  _photo!,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                )
                              : Container(
                                  color: scheme.primaryContainer,
                                  alignment: Alignment.center,
                                  child: _photoFailed
                                      ? TextButton(
                                          onPressed: _loadPhoto,
                                          child: const Text('Load photo'),
                                        )
                                      : const CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          TextButton.icon(
                            onPressed: _photoBusy ? null : _pickPhoto,
                            icon: const UsIcon(UsIcons.image, size: 18),
                            label: Text(
                              _photoBusy ? 'Uploading...' : 'Replace photo',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _photoBusy ? null : _removePhoto,
                            icon: const UsIcon(UsIcons.close, size: 18),
                            label: const Text('Remove photo'),
                          ),
                        ],
                      ),
                      TextField(
                        controller: _caption,
                        maxLength: TimeCapsuleService.captionMax,
                        textCapitalization: TextCapitalization.sentences,
                        buildCounter: _nearLimitCounter,
                        decoration: const InputDecoration(
                          hintText: 'A caption for the photo (optional)',
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    const SectionLabel(text: 'Title (optional)'),
                    TextField(
                      controller: _title,
                      maxLength: TimeCapsuleService.titleMax,
                      textCapitalization: TextCapitalization.sentences,
                      buildCounter: _nearLimitCounter,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Our first trip',
                        helperText: 'Hidden until it is opened',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const SectionLabel(text: 'Your letter'),
                    TextField(
                      controller: _letter,
                      maxLength: TimeCapsuleService.letterMax,
                      minLines: 8,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      buildCounter: _nearLimitCounter,
                      decoration: InputDecoration(
                        hintText: 'Dear ${widget.partnerName},',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const SectionLabel(text: 'When it opens'),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final p in presets.entries)
                          ChoiceChip(
                            label: Text(p.key),
                            selected: unlock == p.value,
                            onSelected: (_) {
                              setState(() => _unlockAt = p.value);
                              _markDirty();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const UsIcon(UsIcons.calendar, size: 18),
                          label: Text(
                            unlock == null ? 'Choose a date' : longDate(unlock),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const UsIcon(UsIcons.history, size: 18),
                          label: Text(
                            unlock == null
                                ? 'Choose a time'
                                : clockTime(unlock),
                          ),
                        ),
                      ],
                    ),
                    if (unlock != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        unlock.isAfter(TimeCapsuleService.now())
                            ? 'Opens ${longDate(unlock)} at ${clockTime(unlock)} (${opensIn(unlock, now: TimeCapsuleService.now())}), your time.'
                            : 'That moment has passed. Choose a time in the future.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: unlock.isAfter(TimeCapsuleService.now())
                              ? scheme.onSurfaceVariant
                              : scheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        if (_editing)
                          TextButton(
                            onPressed: _cancelCapsule,
                            style: TextButton.styleFrom(
                              foregroundColor: scheme.error,
                            ),
                            child: const Text('Cancel capsule'),
                          ),
                        OutlinedButton(
                          onPressed: _status == _Save.saving
                              ? null
                              : () => _save(),
                          child: Text(_editing ? 'Save changes' : 'Save draft'),
                        ),
                        FilledButton(
                          onPressed: _preview,
                          child: Text(
                            _editing ? 'Preview and seal again' : 'Preview',
                          ),
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

/// A field's count, shown only once you are near its limit (80%). The limit
/// itself is always enforced by maxLength.
Widget? _nearLimitCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  int? maxLength,
}) {
  final max = maxLength;
  if (max == null || currentLength < max * 0.8) return null;
  final theme = Theme.of(context);
  return Semantics(
    liveRegion: true,
    label: '${max - currentLength} characters left',
    child: ExcludeSemantics(
      child: Text(
        '$currentLength / $max',
        style: theme.textTheme.labelSmall?.copyWith(
          color: currentLength >= max
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

/// The empty photo area: a large dashed tile to tap, like Add Memory.
class _PhotoDrop extends StatelessWidget {
  const _PhotoDrop({required this.busy, required this.onPick});

  final bool busy;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: busy ? 'Uploading the photo' : 'Add a photo',
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: _Dashes(
          color: scheme.primary.withValues(alpha: 0.6),
        ),
        child: Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: onPick,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  busy
                      ? const SizedBox.square(
                          dimension: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : UsIcon(UsIcons.image, size: 32, color: scheme.primary),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    busy ? 'Uploading...' : 'Add a photo',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'It is the first thing they see when it opens',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dashes extends CustomPainter {
  _Dashes({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          const Radius.circular(AppRadius.card),
        ),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 13) {
        canvas.drawPath(metric.extractPath(d, d + 7), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Dashes old) => old.color != color;
}

/// The full capsule as it will be read, before sealing. "Preview opening"
/// plays the envelope here only: nothing is saved, shown to your partner,
/// marked opened or announced.
class CapsulePreviewScreen extends StatelessWidget {
  const CapsulePreviewScreen({
    super.key,
    required this.partnerName,
    this.senderName = '',
    required this.letter,
    required this.unlockAt,
    required this.onSeal,
    required this.hasPhoto,
    this.title,
    this.caption,
    this.photo,
    this.resealing = false,
  });

  final String partnerName;

  /// Who is sealing it: their initial goes into the wax.
  final String senderName;
  final String? title;
  final String letter;
  final String? caption;
  final bool hasPhoto;
  final Uint8List? photo;
  final DateTime unlockAt;
  final bool resealing;
  final Future<void> Function() onSeal;

  Future<void> _previewOpening(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _LocalOpening(
          senderName: senderName,
          title: title,
          letter: letter,
          caption: caption,
          hasPhoto: hasPhoto,
          photo: photo,
        ),
      ),
    );
  }

  Future<void> _seal(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(resealing ? 'Seal it again?' : 'Seal this time capsule?'),
        content: Text(
          'For the next ten minutes you can still edit or cancel it, and '
          '$partnerName won\'t see anything. After that it stays sealed until '
          '${longDate(unlockAt)} at ${clockTime(unlockAt)}, and nobody can read it '
          'until $partnerName opens it. Not even you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Seal it'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await onSeal();
    } catch (e) {
      if (!context.mounted) return;
      showUsMessage(
        context,
        'Not sealed: ${friendlyError(e)} Your draft is safe.',
        error: true,
      );
      return;
    }
    if (!context.mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Sealing',
      barrierColor: Colors.black.withValues(alpha: 0.96),
      pageBuilder: (context, _, _) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Material(
            color: Colors.transparent,
            child: Semantics(
              liveRegion: true,
              label: 'Your time capsule is sealed',
              child: CapsuleSealingCeremony(
                width: (MediaQuery.sizeOf(context).width - 64).clamp(
                  200.0,
                  320.0,
                ),
                initial: sealInitial(senderName),
                title: title,
                letter: letter,
                caption:
                    'Opens ${longDate(unlockAt)} at ${clockTime(unlockAt)}',
                onDone: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ),
    );
    if (context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          AppSpacing.md,
          AppSpacing.screenMargin,
          120,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: CapsuleLetter(
                title: title,
                letter: letter,
                caption: caption,
                hasPhoto: hasPhoto,
                photo: photo,
                header: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Only you can see this preview.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'To $partnerName',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'Opens ${longDate(unlockAt)} at ${clockTime(unlockAt)}, your time',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: () => _previewOpening(context),
                icon: const UsIcon(UsIcons.loveNotes, size: 20),
                label: const Text('Preview opening'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep editing'),
              ),
              FilledButton.icon(
                onPressed: () => _seal(context),
                icon: const UsIcon(UsIcons.lock, size: 20),
                label: Text(resealing ? 'Seal again' : 'Seal capsule'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Preview opening": the envelope and reveal, entirely on this device.
class _LocalOpening extends StatefulWidget {
  const _LocalOpening({
    required this.senderName,
    required this.letter,
    required this.hasPhoto,
    this.title,
    this.caption,
    this.photo,
  });

  final String? title;
  final String senderName;
  final String letter;
  final String? caption;
  final bool hasPhoto;
  final Uint8List? photo;

  @override
  State<_LocalOpening> createState() => _LocalOpeningState();
}

class _LocalOpeningState extends State<_LocalOpening> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = (MediaQuery.sizeOf(context).width - 64).clamp(220.0, 360.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Preview opening')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          Text(
            'This is how it will open. Only on this device: nothing is sent.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _revealed
                  ? CapsuleLetter(
                      reveal: true,
                      title: widget.title,
                      letter: widget.letter,
                      caption: widget.caption,
                      hasPhoto: widget.hasPhoto,
                      photo: widget.photo,
                    )
                  : CapsuleOpeningCeremony(
                      width: width,
                      initial: sealInitial(widget.senderName),
                      title: widget.title,
                      letter: widget.letter,
                      photo: widget.photo,
                      onReveal: () => setState(() => _revealed = true),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
