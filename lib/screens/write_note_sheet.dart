import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/note_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/app_text_field.dart';

/// Write a love note. Closes with `true` once sent. (Time Capsules have
/// their own screen now; this sheet no longer seals notes.)
class WriteNoteSheet extends StatefulWidget {
  const WriteNoteSheet({
    super.key,
    required this.coupleId,
    required this.partnerName,
  });

  final String coupleId;
  final String partnerName;

  @override
  State<WriteNoteSheet> createState() => _WriteNoteSheetState();
}

class _WriteNoteSheetState extends State<WriteNoteSheet> {
  final _body = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_body.text.trim().isEmpty) {
      setState(() => _error = 'Write your note first.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await NoteService.send(coupleId: widget.coupleId, body: _body.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        0,
        AppSpacing.screenMargin,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('A note for ${widget.partnerName}', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Your note',
                controller: _body,
                hintText: 'Write something sweet…',
                maxLength: 2000,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Send note',
                icon: Icons.send_outlined,
                onPressed: _send,
                isLoading: _sending,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
