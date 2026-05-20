// test/golden/lab_dialog_golden_test.dart
//
// 锁定 LabDialog 在 confirm / destructive 两种 kind 下的视觉外观。

// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/ui/lab/lab.dart';

import '_lab_harness.dart';

class _DialogMatrix extends StatelessWidget {
  const _DialogMatrix();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Expanded(
          child: LabDialog(
            title: 'Save profile',
            summary: 'thingsboard-edge-01',
            primaryLabel: 'Save',
            secondaryLabel: 'Cancel',
            footnote: 'Cmd+S submit · Esc cancel',
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: LabDialog(
            kind: LabDialogKind.destructive,
            title: 'Delete cert bundle',
            summary: 'cert-bundle-2026q2',
            primaryLabel: 'Delete forever',
            secondaryLabel: 'Keep',
            footnote: 'This action is irreversible.',
          ),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('Lab dialog — confirm + destructive', (tester) async {
    await pumpGoldenPair(
      tester,
      base: 'lab_dialog',
      child: const _DialogMatrix(),
      size: const Size(900, 480),
    );
  });
}
