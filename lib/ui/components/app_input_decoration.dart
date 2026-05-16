import 'package:flutter/material.dart';

@Deprecated(
    'Use LabField / LabSelect from ui/lab. Kept during the migration compat window.')
class AppInputDecoration {
  AppInputDecoration._();

  static InputDecoration filled(
    BuildContext context, {
    required String label,
    EdgeInsetsGeometry contentPadding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  }) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outlineVariant.withValues(alpha: 0.45);

    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLowest,
      contentPadding: contentPadding,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
      ),
    );
  }
}
