import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/work_log_entry.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/app_toast.dart';

class WorkLogCard extends StatelessWidget {
  final WorkLogEntry log;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const WorkLogCard({
    super.key, 
    required this.log,
    this.onEdit,
    this.onDelete,
  });

  Future<void> _copyContent(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: log.content));
    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      AppToast.success(context, l10n.tsCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final start = DateFormat.Hm().format(log.startTime);
    final end = DateFormat.Hm().format(log.endTime);
    final duration = log.durationHours.toStringAsFixed(1);

    Color catColor = theme.colorScheme.primary;
    // Simple color logic based on category string hash or existing logic if any
    // For now using primary. In original code it just used primary or secondary.

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onEdit,
        onLongPress: () => _copyContent(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time Column (Timeline Style)
              Column(
                children: [
                  Text(
                    start,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              
              // Content Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Tag for Category/Project
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            log.projectCode?.isNotEmpty == true 
                                ? log.projectCode! 
                                : (log.category.isNotEmpty ? log.category : "Task"),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${duration}h",
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        // Add Copy Icon Button
                        InkWell(
                          onTap: () => _copyContent(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(Icons.copy, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      log.content,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Actions
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onDelete,
                  color: theme.colorScheme.error.withValues(alpha: 0.7),
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
