import 'package:flutter/material.dart';

import '../lab/lab.dart';

/// Centered empty / error placeholder: an outlined icon, a message, and an
/// optional Lab call-to-action button. Used for "no data", "no results" and
/// error states across the app.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: scheme.outline),
          SizedBox(height: tokens.sLg),
          Text(
            message,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: tokens.sLg),
            LabButton(
              label: actionLabel!,
              size: LabButtonSize.sm,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
