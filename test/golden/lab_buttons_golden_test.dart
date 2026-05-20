// test/golden/lab_buttons_golden_test.dart
//
// 锁定 LabButton 5 个 variant × 3 个 size 的视觉外观，以及 LabIconButton
// 默认 / 激活 / 带 badge 三态。任一像素差异需要人工 review --update-goldens。

// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
// 测试 fixture 中 onPressed 用 tear-off，无法 const 化；统一豁免以保持代码清爽。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/ui/lab/lab.dart';

import '_lab_harness.dart';

class _ButtonMatrix extends StatelessWidget {
  const _ButtonMatrix();

  @override
  Widget build(BuildContext context) {
    Widget row(LabButtonSize size) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final v in LabButtonVariant.values)
              LabButton(
                label: v.name,
                variant: v,
                size: size,
                onPressed: () {},
              ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(LabButtonSize.sm),
        const SizedBox(height: 12),
        row(LabButtonSize.md),
        const SizedBox(height: 12),
        row(LabButtonSize.lg),
        const SizedBox(height: 24),
        Row(
          children: [
            LabIconButton(icon: Icons.play_arrow, onPressed: _noop),
            const SizedBox(width: 12),
            LabIconButton(
                icon: Icons.refresh, active: true, onPressed: _noop),
            const SizedBox(width: 12),
            LabIconButton(
                icon: Icons.notifications, badge: true, onPressed: _noop),
            const SizedBox(width: 12),
            const LabIconButton(icon: Icons.delete), // disabled (no onPressed)
          ],
        ),
      ],
    );
  }
}

void _noop() {}

void main() {
  testWidgets('Lab buttons matrix — variants × sizes + icon buttons',
      (tester) async {
    await pumpGoldenPair(
      tester,
      base: 'lab_buttons',
      child: const _ButtonMatrix(),
      size: const Size(720, 380),
    );
  });
}
