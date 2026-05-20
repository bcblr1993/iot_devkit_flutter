// test/golden/lab_panels_golden_test.dart
//
// 锁定 LabSection（分组面板）与 LabStatTile（统计卡）的视觉外观。

// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/ui/lab/lab.dart';

import '_lab_harness.dart';

class _PanelMatrix extends StatelessWidget {
  const _PanelMatrix();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabSection(
          title: 'TELEMETRY',
          hint: 'last 60s rolling window',
          child: Row(
            children: const [
              Expanded(
                child: LabStatTile(
                  label: 'MSG / s',
                  value: '1 248',
                  unit: 'msg',
                  trend: '▲ 4.2% / min',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: LabStatTile(
                  label: 'LATENCY',
                  value: '17',
                  unit: 'ms',
                  trend: '▼ 1.1 ms',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: LabStatTile(
                  label: 'ERRORS',
                  value: '0',
                  unit: '',
                  trend: '—',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LabSection(
          title: 'SCHEDULER',
          trailing: LabPill(
              label: 'RUNNING', color: Theme.of(context).colorScheme.primary),
          child: const Text(
            'tick=100ms · next frame in 17ms · backlog=0',
          ),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('Lab panels — section + stat tile', (tester) async {
    await pumpGoldenPair(
      tester,
      base: 'lab_panels',
      child: const _PanelMatrix(),
      size: const Size(720, 420),
    );
  });
}
