import 'package:flutter/material.dart';

class FormGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;

  const FormGrid({
    super.key,
    required this.children,
    this.minItemWidth = 220,
    this.spacing = 8,
    this.runSpacing = 10,
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
