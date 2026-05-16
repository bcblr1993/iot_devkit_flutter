// lib/ui/lab/components/lab_panels.dart
//
// LabSection — the bordered card that wraps every logical group on a
// page. Header strip with an accent rail, title, optional mono hint,
// optional trailing widgets, then the body.
//
// LabStatTile — a single number-with-label tile for dashboards.

import 'package:flutter/material.dart';
import '../tokens/lab_tokens.dart';

class LabSection extends StatelessWidget {
  final String title;
  final String? hint;
  final Widget? trailing;
  final Widget child;
  final bool padded;
  final Color? accent;

  const LabSection({
    super.key,
    required this.title,
    required this.child,
    this.hint,
    this.trailing,
    this.padded = true,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(tokens.rLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header strip
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.rLg)),
            ),
            padding: EdgeInsets.symmetric(horizontal: tokens.sLg, vertical: tokens.sMd),
            child: Row(
              children: [
                Container(
                  width: 4, height: 12,
                  decoration: BoxDecoration(
                    color: accent ?? scheme.primary,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                SizedBox(width: tokens.sLg),
                Text(
                  title.toUpperCase(),
                  style: text.titleMedium?.copyWith(
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6,
                  ),
                ),
                if (hint != null) ...[
                  SizedBox(width: tokens.sLg),
                  Text(
                    hint!,
                    style: text.labelLarge?.copyWith(
                      fontSize: 11, color: tokens.faint,
                    ),
                  ),
                ],
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          // Body
          if (padded)
            Padding(padding: EdgeInsets.all(tokens.sLg), child: child)
          else
            child,
        ],
      ),
    );
  }
}

class LabStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? trend;     // e.g. "▲ 4.2% / min"
  final Color? valueColor;

  const LabStatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.trend,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: tokens.sLg, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(tokens.rMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: text.labelSmall?.copyWith(color: tokens.faint),
          ),
          SizedBox(height: tokens.sXxs),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              value,
              style: text.displaySmall?.copyWith(
                fontSize: 22, color: valueColor ?? scheme.onSurface, height: 1,
              ),
            ),
            if (unit != null) ...[
              SizedBox(width: tokens.sXs),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(unit!, style: text.labelLarge?.copyWith(color: tokens.faint)),
              ),
            ],
          ]),
          if (trend != null) ...[
            SizedBox(height: tokens.sXs),
            Text(trend!, style: text.labelLarge?.copyWith(
              color: tokens.accentDim, fontSize: 10,
            )),
          ],
        ],
      ),
    );
  }
}
