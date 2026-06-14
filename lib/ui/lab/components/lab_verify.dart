// lib/ui/lab/components/lab_verify.dart
//
// Building blocks for the certificate endpoint verifier screen.
//   LabCheckRow   — one probe result (ok / warn / error) with detail
//   LabChainNode  — one node in a certificate chain (leaf → root)

import 'package:flutter/material.dart';
import '../tokens/lab_tokens.dart';
import 'lab_feedback.dart' show LabStatus;

class LabCheckRow extends StatelessWidget {
  final LabStatus status;     // ok / warn / error
  final String label;
  final String value;
  final String? detail;
  const LabCheckRow({
    super.key,
    required this.status,
    required this.label,
    required this.value,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;

    final c = switch (status) {
      LabStatus.ok    => tokens.ok,
      LabStatus.warn  => tokens.warn,
      LabStatus.error => scheme.error,
      _               => tokens.info,
    };
    final glyph = switch (status) {
      LabStatus.ok    => '✓',
      LabStatus.warn  => '!',
      LabStatus.error => '×',
      _               => 'i',
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: tokens.sLg, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: c.withValues(alpha: .16),
            border: Border.all(color: c.withValues(alpha: .40)),
            borderRadius: BorderRadius.circular(tokens.rSm),
          ),
          alignment: Alignment.center,
          child: Text(glyph, style: TextStyle(
            fontFamily: tokens.monoFamily, fontWeight: FontWeight.w800,
            fontSize: 12, color: c, height: 1)),
        ),
        SizedBox(width: tokens.sLg),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text(label, style: text.bodySmall?.copyWith(
                fontWeight: FontWeight.w600, color: scheme.onSurface)),
              SizedBox(width: tokens.sMd),
              Expanded(child: Text(value, style: text.labelLarge?.copyWith(color: c))),
            ]),
            if (detail != null) ...[
              const SizedBox(height: 3),
              Text(detail!, style: text.labelLarge?.copyWith(
                fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ],
        )),
      ]),
    );
  }
}

enum LabCertRole { leaf, intermediate, root }

class LabChainNode extends StatelessWidget {
  final int depth;
  final LabCertRole role;
  final String commonName;
  final String issuer;
  final bool isLast;
  const LabChainNode({
    super.key,
    required this.depth,
    required this.role,
    required this.commonName,
    required this.issuer,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);
    final text = Theme.of(context).textTheme;

    final c = switch (role) {
      LabCertRole.leaf         => scheme.primary,
      LabCertRole.intermediate => tokens.info,
      LabCertRole.root         => tokens.ok,
    };
    final roleLabel = switch (role) {
      LabCertRole.leaf         => 'LEAF',
      LabCertRole.intermediate => 'INTER',
      LabCertRole.root         => 'ROOT',
    };

    return Padding(
      padding: EdgeInsets.only(left: depth * 22.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(role == LabCertRole.leaf ? 2 : 5),
            ),
          ),
          if (!isLast)
            Container(width: 1, height: 24, color: scheme.outlineVariant, margin: const EdgeInsets.only(top: 2)),
        ]),
        SizedBox(width: tokens.sLg),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  border: Border.all(color: c.withValues(alpha: .30)),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(roleLabel, style: TextStyle(
                  fontFamily: tokens.monoFamily, fontSize: 9, fontWeight: FontWeight.w700,
                  color: c, letterSpacing: 0.4)),
              ),
              SizedBox(width: tokens.sMd),
              Text(commonName, style: text.labelLarge?.copyWith(color: scheme.onSurface)),
            ]),
            const SizedBox(height: 2),
            Text('issuer · $issuer', style: text.labelLarge?.copyWith(
              fontSize: 10.5, color: tokens.faint)),
          ]),
        ),
      ]),
    );
  }
}
