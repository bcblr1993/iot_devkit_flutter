import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../lab/lab.dart';

class TimesheetHeader extends StatelessWidget {
  final DateTime selectedDate;
  final String dateLabel;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onCopyWeeklyReport;
  final VoidCallback onAddLog;

  const TimesheetHeader({
    super.key,
    required this.selectedDate,
    required this.dateLabel,
    required this.onDateSelected,
    required this.onCopyWeeklyReport,
    required this.onAddLog,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          LabIconButton(
            icon: Icons.calendar_month,
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                onDateSelected(picked);
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dateLabel,
              style: theme.textTheme.headlineSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LabButton(
                      icon: Icons.copy,
                      label: l10n.tsWeeklyReport,
                      variant: LabButtonVariant.primary,
                      onPressed: onCopyWeeklyReport,
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      heroTag: 'add_task',
                      onPressed: onAddLog,
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
