// test/golden/lab_form_golden_test.dart
//
// 锁定 LabField / LabSegmented / LabCheckbox / LabToggle 的视觉外观。
// LabSelect 关闭态结构与 LabField 一致，不重复打 golden（展开态依赖 Overlay）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/ui/lab/lab.dart';

import '_lab_harness.dart';

class _FormMatrix extends StatelessWidget {
  const _FormMatrix();

  @override
  Widget build(BuildContext context) {
    final ctrl1 = TextEditingController(text: 'tcp://broker.local:1883');
    final ctrl2 = TextEditingController(text: 'sensor/+/temperature');
    final ctrl3 = TextEditingController(text: 'bad-value');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabField(
          label: 'BROKER URL',
          controller: ctrl1,
          mono: true,
        ),
        const SizedBox(height: 16),
        LabField(
          label: 'TOPIC PATTERN',
          controller: ctrl2,
          helperText: 'wildcards + and # supported',
          suffix: 'qos1',
        ),
        const SizedBox(height: 16),
        LabField(
          label: 'CLIENT ID',
          controller: ctrl3,
          errorText: 'must start with a letter',
        ),
        const SizedBox(height: 24),
        LabSegmented<String>(
          value: 'json',
          segments: const [
            LabSegment('json', 'JSON'),
            LabSegment('cbor', 'CBOR'),
            LabSegment('raw', 'RAW'),
          ],
          onChanged: (_) {},
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            LabCheckbox(value: true, label: 'retain message', onChanged: (_) {}),
            const SizedBox(width: 24),
            LabCheckbox(
                value: false,
                indeterminate: true,
                label: 'clean session',
                onChanged: (_) {}),
            const SizedBox(width: 24),
            LabToggle(value: true, onChanged: (_) {}),
            const SizedBox(width: 8),
            LabToggle(value: false, onChanged: (_) {}),
          ],
        ),
      ],
    );
  }
}

void main() {
  testWidgets('Lab form components — field / segmented / checkbox / toggle',
      (tester) async {
    await pumpGoldenPair(
      tester,
      base: 'lab_form',
      child: const _FormMatrix(),
      size: const Size(640, 520),
    );
  });
}
