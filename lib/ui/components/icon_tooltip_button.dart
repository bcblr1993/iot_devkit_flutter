import 'package:flutter/material.dart';

class IconTooltipButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  const IconTooltipButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return IconButton.filledTonal(
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        onPressed: onPressed,
      );
    }

    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
