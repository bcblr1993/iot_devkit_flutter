// test/golden/lab_feedback_golden_test.dart
//
// 锁定 LabPill / LabStatusDot / LabInlineAlert 的视觉外观（5 种状态色）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/ui/lab/lab.dart';

import '_lab_harness.dart';

class _FeedbackMatrix extends StatelessWidget {
  const _FeedbackMatrix();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = LabTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            LabPill(label: 'OK', color: tokens.ok),
            const SizedBox(width: 8),
            LabPill(label: 'WARN', color: tokens.warn),
            const SizedBox(width: 8),
            LabPill(label: 'ERROR', color: scheme.error),
            const SizedBox(width: 8),
            LabPill(label: 'INFO', color: tokens.info),
            const SizedBox(width: 8),
            LabPill(label: 'FAINT', color: tokens.faint, small: true),
          ],
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            LabStatusDot(kind: LabStatus.ok, glow: true),
            SizedBox(width: 8),
            LabStatusDot(kind: LabStatus.warn),
            SizedBox(width: 8),
            LabStatusDot(kind: LabStatus.error),
            SizedBox(width: 8),
            LabStatusDot(kind: LabStatus.info),
            SizedBox(width: 8),
            LabStatusDot(kind: LabStatus.idle),
          ],
        ),
        const SizedBox(height: 16),
        const LabInlineAlert(
          kind: LabStatus.info,
          child: Text('Broker connected. Syncing session state.'),
        ),
        const SizedBox(height: 8),
        const LabInlineAlert(
          kind: LabStatus.warn,
          child: Text('Queue backlog exceeds 1k. Slow down publish rate.'),
        ),
        const SizedBox(height: 8),
        const LabInlineAlert(
          kind: LabStatus.error,
          child: Text('Cert validation failed: subject CN != host.'),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('Lab feedback — pill / status dot / inline alert',
      (tester) async {
    await pumpGoldenPair(
      tester,
      base: 'lab_feedback',
      child: const _FeedbackMatrix(),
      size: const Size(720, 400),
    );
  });
}
