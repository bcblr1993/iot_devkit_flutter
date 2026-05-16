// lib/ui/lab/components/lab_data.dart
//
// Data display atoms. Currently: LabLogRow.

import 'package:flutter/material.dart';
import '../tokens/lab_tokens.dart';

enum LabLogLevel { ok, info, warn, error, debug }

class LabLogRow extends StatelessWidget {
  final String timestamp;
  final LabLogLevel level;
  final String tag;
  final String message;
  final bool dim;

  const LabLogRow({
    super.key,
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;

    Color lc;
    String lbl;
    switch (level) {
      case LabLogLevel.ok:    lc = tokens.ok;     lbl = 'OK';
      case LabLogLevel.info:  lc = tokens.info;   lbl = 'INF';
      case LabLogLevel.warn:  lc = tokens.warn;   lbl = 'WRN';
      case LabLogLevel.error: lc = scheme.error;  lbl = 'ERR';
      case LabLogLevel.debug: lc = tokens.faint;  lbl = 'DBG';
    }

    final monoStyle = text.labelLarge?.copyWith(fontSize: 11.5);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.sLg, vertical: tokens.sXs),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
          width: 160,
          child: Text(timestamp, style: monoStyle?.copyWith(color: tokens.faint)),
        ),
        SizedBox(width: tokens.sLg),
        SizedBox(
          width: 44,
          child: Text(lbl, style: monoStyle?.copyWith(color: lc, fontWeight: FontWeight.w700)),
        ),
        SizedBox(width: tokens.sLg),
        SizedBox(
          width: 80,
          child: Text(tag, style: monoStyle?.copyWith(color: scheme.onSurfaceVariant)),
        ),
        SizedBox(width: tokens.sLg),
        Expanded(
          child: Text(
            message,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: monoStyle?.copyWith(color: dim ? scheme.onSurfaceVariant : scheme.onSurface),
          ),
        ),
      ]),
    );
  }
}
