// lib/ui/lab/components/lab_buttons.dart
//
// LabButton — variant × size × state matrix per design system §03.
// Sits on top of Material's button widgets so all the focus / ripple /
// keyboard semantics come for free.

import 'package:flutter/material.dart';
import '../tokens/lab_tokens.dart';

enum LabButtonVariant { primary, secondary, ghost, danger, success }
enum LabButtonSize    { sm, md, lg }

class LabButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? suffix;          // e.g. "⌘S"
  final LabButtonVariant variant;
  final LabButtonSize size;
  final bool loading;
  final bool fullWidth;
  final VoidCallback? onPressed;

  const LabButton({
    super.key,
    required this.label,
    this.icon,
    this.suffix,
    this.variant = LabButtonVariant.secondary,
    this.size = LabButtonSize.md,
    this.loading = false,
    this.fullWidth = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;

    final double height = switch (size) {
      LabButtonSize.sm => 24,
      LabButtonSize.md => 30,
      LabButtonSize.lg => 36,
    };
    final double hPad = switch (size) {
      LabButtonSize.sm => 8,
      LabButtonSize.md => 12,
      LabButtonSize.lg => 14,
    };
    final double fs = switch (size) {
      LabButtonSize.sm => 11,
      LabButtonSize.md => 12,
      LabButtonSize.lg => 13,
    };

    Color bg, fg, border;
    switch (variant) {
      case LabButtonVariant.primary:
        bg = scheme.primary; fg = scheme.onPrimary; border = scheme.primary;
      case LabButtonVariant.danger:
        bg = scheme.error.withOpacity(.18); fg = scheme.error; border = scheme.error.withOpacity(.40);
      case LabButtonVariant.success:
        bg = tokens.ok.withOpacity(.18); fg = tokens.ok; border = tokens.ok.withOpacity(.40);
      case LabButtonVariant.ghost:
        bg = Colors.transparent; fg = tokens.body; border = Colors.transparent;
      case LabButtonVariant.secondary:
        bg = Colors.transparent; fg = scheme.onSurface; border = scheme.outline;
    }

    Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: fs - 1, height: fs - 1,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: fs + 1, color: fg),
        if (loading || icon != null) SizedBox(width: tokens.sSm),
        Text(
          label,
          style: text.bodySmall?.copyWith(
            fontSize: fs, color: fg, fontWeight: FontWeight.w700, letterSpacing: 0.2,
          ),
        ),
        if (suffix != null) ...[
          SizedBox(width: tokens.sXs),
          Text(
            suffix!,
            style: text.labelLarge?.copyWith(
              fontSize: fs - 1, color: fg.withOpacity(.60),
            ),
          ),
        ],
      ],
    );

    return Opacity(
      opacity: onPressed == null && !loading ? .45 : 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: height, minWidth: fullWidth ? double.infinity : 0,
        ),
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: border),
            borderRadius: BorderRadius.circular(tokens.rSm + 1),
          ),
          child: InkWell(
            onTap: loading ? null : onPressed,
            borderRadius: BorderRadius.circular(tokens.rSm + 1),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: SizedBox(height: height, child: Center(child: content)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon-only square button — toolbar, dock controls, settings entries.
class LabIconButton extends StatelessWidget {
  final IconData icon;
  final LabButtonSize size;
  final bool active;
  final bool badge;
  final String? tooltip;
  final VoidCallback? onPressed;

  const LabIconButton({
    super.key,
    required this.icon,
    this.size = LabButtonSize.md,
    this.active = false,
    this.badge = false,
    this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);

    final double s = switch (size) {
      LabButtonSize.sm => 24,
      LabButtonSize.md => 30,
      LabButtonSize.lg => 36,
    };
    final Color bg = active ? scheme.primary.withOpacity(.14) : Colors.transparent;
    final Color fg = active ? scheme.primary : scheme.onSurfaceVariant;
    final Color border = active ? scheme.primary.withOpacity(.30) : scheme.outline;

    final btn = Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: s, height: s,
          child: Material(
            color: bg,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: border),
              borderRadius: BorderRadius.circular(tokens.rSm + 1),
            ),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(tokens.rSm + 1),
              child: Icon(icon, size: s * 0.45, color: fg),
            ),
          ),
        ),
        if (badge)
          Positioned(
            right: 3, top: 3,
            child: Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: scheme.primary, shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );

    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
