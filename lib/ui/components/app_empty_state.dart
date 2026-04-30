import 'package:flutter/material.dart';

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
