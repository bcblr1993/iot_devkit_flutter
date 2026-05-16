// lib/ui/lab/components/lab_dialog.dart
//
// Three dialog kinds per design system §06:
//   - neutral confirm  : ? icon, primary accent
//   - destructive      : ! icon, red accent + danger button
//   - form             : ✎ icon, holds extra Field/Select widgets
//
// All variants share the same shell, all are 460px wide and use a
// blurred backdrop scrim.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../tokens/lab_tokens.dart';
import 'lab_buttons.dart';

enum LabDialogKind { confirm, destructive, form }

class LabDialog extends StatelessWidget {
  final LabDialogKind kind;
  final String title;
  final String? summary;     // mono · the target id / count
  final Widget? body;        // descriptive text
  final Widget? form;        // for kind == form
  final String? footnote;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  const LabDialog({
    super.key,
    required this.title,
    required this.primaryLabel,
    required this.secondaryLabel,
    this.kind = LabDialogKind.confirm,
    this.summary,
    this.body,
    this.form,
    this.footnote,
    this.onPrimary,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;

    final accent = kind == LabDialogKind.destructive ? scheme.error : scheme.primary;
    final glyph = switch (kind) {
      LabDialogKind.destructive => '!',
      LabDialogKind.form        => '✎',
      LabDialogKind.confirm     => '?',
    };

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            padding: EdgeInsets.symmetric(horizontal: tokens.sXl, vertical: tokens.sLg),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.18),
                  border: Border.all(color: accent.withOpacity(.40)),
                  borderRadius: BorderRadius.circular(tokens.rMd),
                ),
                alignment: Alignment.center,
                child: Text(
                  glyph,
                  style: TextStyle(
                    fontFamily: tokens.monoFamily,
                    fontSize: 14, fontWeight: FontWeight.w800, color: accent,
                  ),
                ),
              ),
              SizedBox(width: tokens.sLg),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
                  if (summary != null) ...[
                    SizedBox(height: 2),
                    Text(
                      summary!,
                      style: text.labelLarge?.copyWith(fontSize: 11.5, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              )),
              IconButton(
                icon: Icon(Icons.close, size: 16, color: tokens.faint),
                onPressed: () => Navigator.of(context).pop(),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),
          // Body
          Padding(
            padding: EdgeInsets.all(tokens.sXl + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (body != null)
                  DefaultTextStyle.merge(
                    style: text.bodySmall!.copyWith(color: tokens.body, fontSize: 13, height: 1.55),
                    child: body!,
                  ),
                if (form != null) ...[
                  if (body != null) SizedBox(height: tokens.sLg),
                  form!,
                ],
                if (footnote != null) ...[
                  SizedBox(height: tokens.sLg),
                  Text(
                    footnote!,
                    style: text.labelLarge?.copyWith(color: tokens.faint, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          // Action row
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            padding: EdgeInsets.symmetric(horizontal: tokens.sXl, vertical: tokens.sLg),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              LabButton(
                label: secondaryLabel,
                onPressed: onSecondary ?? () => Navigator.of(context).pop(false),
              ),
              SizedBox(width: tokens.sMd),
              LabButton(
                label: primaryLabel,
                variant: kind == LabDialogKind.destructive
                    ? LabButtonVariant.danger
                    : LabButtonVariant.primary,
                onPressed: onPrimary ?? () => Navigator.of(context).pop(true),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Convenience shortcut: returns true if the user confirmed.
Future<bool> showLabConfirm(
  BuildContext context, {
  required String title,
  String? summary,
  String? body,
  String primaryLabel = 'Confirm',
  String secondaryLabel = 'Cancel',
  String? footnote,
  bool destructive = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: LabDialog(
        kind: destructive ? LabDialogKind.destructive : LabDialogKind.confirm,
        title: title,
        summary: summary,
        body: body == null ? null : Text(body),
        footnote: footnote,
        primaryLabel: primaryLabel,
        secondaryLabel: secondaryLabel,
      ),
    ),
  );
  return res ?? false;
}
