// lib/ui/lab/components/lab_form.dart
//
// Form control suite — visual wrapper around standard widgets so all
// inputs share the same height, padding, border colour & focus ring.
//
// Includes: LabField, LabSelect<T>, LabSegmented<T>, LabCheckbox,
// LabRadio<T>, LabToggle.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import '../tokens/lab_tokens.dart';

// ── LabField ───────────────────────────────────────────────────────
class LabField extends StatelessWidget {
  final String? label;
  final TextEditingController? controller;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? suffix; // unit label e.g. "ms", "Hz"
  final Widget? suffixWidget; // icon button etc.
  final bool obscure;
  final bool mono;
  final bool readOnly;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final FocusNode? focusNode;
  final int minLines, maxLines;
  // Optional form integration — when supplied the field participates in the
  // enclosing Form (validation, error display) just like TextFormField.
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  // Uncontrolled seed value (use instead of [controller]) and enable flag,
  // so LabField can stand in for any TextFormField call site.
  final String? initialValue;
  final bool enabled;

  const LabField({
    super.key,
    this.label,
    this.controller,
    this.hintText,
    this.helperText,
    this.errorText,
    this.suffix,
    this.suffixWidget,
    this.obscure = false,
    this.mono = true,
    this.readOnly = false,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.minLines = 1,
    this.maxLines = 1,
    this.validator,
    this.autovalidateMode,
    this.initialValue,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;

    final inputStyle = (mono ? text.labelLarge : text.bodySmall)?.copyWith(
      color: scheme.onSurface,
      fontSize: 12.5,
    );

    Widget? trailing;
    if (suffixWidget != null) {
      trailing = suffixWidget;
    } else if (suffix != null) {
      trailing = Padding(
        padding: EdgeInsets.only(right: tokens.sMd),
        child: Text(suffix!,
            style: text.labelLarge?.copyWith(color: tokens.faint)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!.toUpperCase(),
            style: text.labelSmall?.copyWith(color: tokens.faint),
          ),
          SizedBox(height: tokens.sXs),
        ],
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          enabled: enabled,
          focusNode: focusNode,
          obscureText: obscure,
          readOnly: readOnly,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
          validator: validator,
          autovalidateMode: autovalidateMode,
          minLines: minLines,
          maxLines: maxLines,
          style: inputStyle,
          decoration: InputDecoration(
            hintText: hintText,
            errorText: errorText,
            helperText: helperText,
            suffixIcon: trailing,
            suffixIconConstraints:
                const BoxConstraints(minHeight: 24, minWidth: 0),
          ),
        ),
      ],
    );
  }
}

// ── LabSelect ──────────────────────────────────────────────────────
class LabSelect<T> extends StatelessWidget {
  final String? label;
  final T value;
  final List<LabSelectItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const LabSelect({
    super.key,
    required this.value,
    required this.items,
    this.label,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!.toUpperCase(),
            style: text.labelSmall?.copyWith(color: tokens.faint),
          ),
          SizedBox(height: tokens.sXs),
        ],
        DropdownButtonFormField<T>(
          isExpanded: true,
          initialValue: value,
          icon: Icon(Icons.expand_more, size: 16, color: tokens.faint),
          dropdownColor: scheme.surfaceContainerLowest,
          style: text.bodySmall?.copyWith(color: scheme.onSurface),
          onChanged: onChanged,
          items: items
              .map((i) =>
                  DropdownMenuItem<T>(value: i.value, child: Text(i.label)))
              .toList(),
        ),
      ],
    );
  }
}

class LabSelectItem<T> {
  final T value;
  final String label;
  const LabSelectItem(this.value, this.label);
}

// ── LabSegmented ───────────────────────────────────────────────────
class LabSegmented<T> extends StatelessWidget {
  final List<LabSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool fullWidth;

  const LabSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;

    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final selected = seg.value == value;
      final child = Material(
        color:
            selected ? scheme.primary.withValues(alpha: .18) : scheme.surface,
        child: InkWell(
          onTap: () => onChanged(seg.value),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.sLg, vertical: 6),
            child: Center(
              child: Text(
                seg.label,
                style: text.labelMedium?.copyWith(
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  fontFamily: tokens.monoFamily,
                ),
              ),
            ),
          ),
        ),
      );
      children.add(fullWidth ? Expanded(child: child) : child);
      if (i < segments.length - 1) {
        children.add(Container(width: 1, color: scheme.outline));
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.rSm + 1),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(tokens.rSm + 1),
        ),
        child: IntrinsicHeight(child: Row(children: children)),
      ),
    );
  }
}

class LabSegment<T> {
  final T value;
  final String label;
  const LabSegment(this.value, this.label);
}

class LabCheckbox extends StatelessWidget {
  final bool value;
  final bool indeterminate;
  final String? label;
  final ValueChanged<bool?>? onChanged;
  const LabCheckbox(
      {super.key,
      required this.value,
      this.indeterminate = false,
      this.label,
      this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: value ? scheme.primary : scheme.surface,
              border:
                  Border.all(color: value ? scheme.primary : scheme.outline),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.center,
            child: value
                ? Text(indeterminate ? '–' : '✓',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      fontFamily: tokens.monoFamily,
                    ))
                : null,
          ),
          if (label != null) ...[
            SizedBox(width: tokens.sMd),
            Text(label!, style: text.bodySmall?.copyWith(color: tokens.body)),
          ],
        ]),
      ),
    );
  }
}

class LabRadio<T> extends StatelessWidget {
  final T groupValue;
  final T value;
  final String? label;
  final ValueChanged<T?>? onChanged;
  const LabRadio(
      {super.key,
      required this.groupValue,
      required this.value,
      this.label,
      this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;
    final selected = value == groupValue;

    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: scheme.surface,
              border:
                  Border.all(color: selected ? scheme.primary : scheme.outline),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: selected
                ? Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: scheme.primary, shape: BoxShape.circle))
                : null,
          ),
          if (label != null) ...[
            SizedBox(width: tokens.sMd),
            Text(label!, style: text.bodySmall?.copyWith(color: tokens.body)),
          ],
        ]),
      ),
    );
  }
}

class LabToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const LabToggle({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);

    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: tokens.dFast,
        width: 30,
        height: 16,
        decoration: BoxDecoration(
          color: value
              ? scheme.primary
              : scheme.onSurfaceVariant.withValues(alpha: .30),
          border: Border.all(color: value ? scheme.primary : scheme.outline),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Stack(children: [
          AnimatedPositioned(
            duration: tokens.dFast,
            left: value ? 13 : 1,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: value ? scheme.onPrimary : scheme.onSurface,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
