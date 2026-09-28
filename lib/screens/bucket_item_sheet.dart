import 'package:flutter/material.dart';

import '../models/bucket_item.dart';
import '../services/auth_service.dart';
import '../services/bucket_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../utils/money.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/app_text_field.dart';
import '../widgets/atoms/section_label.dart';

/// Add a bucket-list item, or edit one when [item] is given.
/// Only the title is required. Closes with `true` once saved.
class BucketItemSheet extends StatefulWidget {
  const BucketItemSheet({super.key, required this.coupleId, this.item});

  final String coupleId;
  final BucketItem? item;

  @override
  State<BucketItemSheet> createState() => _BucketItemSheetState();
}

class _BucketItemSheetState extends State<BucketItemSheet> {
  late final _title = TextEditingController(text: widget.item?.title);
  late final _area = TextEditingController(text: widget.item?.locationArea);
  late final _spot = TextEditingController(text: widget.item?.locationSpot);
  late final _budget = TextEditingController(
    text: widget.item?.budget == null
        ? ''
        : formatPeso(widget.item!.budget!).replaceAll('\u20B1', ''),
  );
  late DateTime? _targetDate = widget.item?.targetDate;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.item != null;

  @override
  void dispose() {
    _title.dispose();
    _area.dispose();
    _spot.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = _targetDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && current.isAfter(now) ? current : now,
      firstDate: now,
      lastDate: DateTime(2100),
      helpText: 'When do you want to do it?',
    );
    if (!mounted || picked == null) return;
    setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Write what you want to do together.');
      return;
    }

    double? budget;
    if (_budget.text.trim().isNotEmpty) {
      budget = parsePeso(_budget.text);
      if (budget == null) {
        setState(() => _error =
            'Enter the budget as a number, e.g. 60000 or 60,000.50.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_editing) {
        await BucketService.update(
          widget.item!.id,
          title: title,
          targetDate: _targetDate,
          locationArea: _area.text,
          locationSpot: _spot.text,
          budget: budget,
        );
      } else {
        await BucketService.add(
          coupleId: widget.coupleId,
          title: title,
          targetDate: _targetDate,
          locationArea: _area.text,
          locationSpot: _spot.text,
          budget: budget,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        0,
        AppSpacing.screenMargin,
        keyboard + AppSpacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.formMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_editing ? 'Edit item' : 'Add to bucket list',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'What do you want to do together?',
                controller: _title,
                hintText: 'e.g. See the bamboo forest',
                prefixIcon: Icons.favorite_border,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.xl),

              const SectionLabel(text: 'Where (optional)'),
              AppTextField(
                label: 'Country / State',
                controller: _area,
                hintText: 'e.g. Kyoto, Japan',
                prefixIcon: Icons.public,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Specific spot',
                controller: _spot,
                hintText: 'e.g. Arashiyama Bamboo Grove',
                prefixIcon: Icons.place_outlined,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.xl),

              const SectionLabel(text: 'Budget and date (optional)'),
              AppTextField(
                label: 'Budget (sinking fund goal, \u20B1)',
                controller: _budget,
                hintText: 'e.g. 60,000',
                prefixIcon: Icons.savings_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: _targetDate == null
                    ? 'Target date (optional)'
                    : 'Target date: ${longDate(_targetDate!)}',
                icon: Icons.event_outlined,
                variant: AppButtonVariant.outlined,
                onPressed: _saving ? null : _pickDate,
                fullWidth: true,
              ),
              if (_targetDate != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _targetDate = null),
                    child: const Text('Remove date'),
                  ),
                ),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: _editing ? 'Save changes' : 'Add to list',
                onPressed: _save,
                isLoading: _saving,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
