import 'package:flutter/material.dart';

class FormGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;

  /// Vertical alignment of items within a run. Use [WrapCrossAlignment.end]
  /// when a row mixes labeled fields with an unlabeled action button, so the
  /// button bottom-aligns with the input boxes instead of the label row.
  final WrapCrossAlignment crossAxisAlignment;

  const FormGrid({
    super.key,
    required this.children,
    this.minItemWidth = 220,
    this.spacing = 8,
    this.runSpacing = 10,
    this.crossAxisAlignment = WrapCrossAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns =
            (width / minItemWidth).floor().clamp(1, children.length);
        final itemWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          crossAxisAlignment: crossAxisAlignment,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}
