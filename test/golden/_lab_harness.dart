// test/golden/_lab_harness.dart
//
// 共享 golden 测试脚手架：把任意 child 包到指定 LabTheme + 固定画布尺寸里渲染，
// 保证多文件 golden 截图视口一致、字体已加载（由 test/flutter_test_config.dart 完成）。
//
// ⚠️ 字体覆盖：本项目仅打包 Inter（西文）+ JetBrainsMono，
// golden 测试环境无 CJK fallback，会渲染成 □ 豆腐块。
// 故 golden 测试 widget 内**只能使用 ASCII 文本**。运行时真实 app 有 OS 字体兜底，
// CJK 显示正常，与本约束无关。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/ui/lab/lab.dart';

/// 固定画布把 child 在指定 LabTheme 下渲染一张静态帧。
class LabHarness extends StatelessWidget {
  final LabTheme theme;
  final Widget child;
  final EdgeInsets padding;

  const LabHarness({
    super.key,
    required this.theme,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.themeData,
      home: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 把一个 widget 在两个代表性主题（signal 暗 / paper 亮）下各打一张 golden。
/// 用法：在 test() 里调用，base 是文件名前缀，会生成
///   goldens/{base}_signal.png  +  goldens/{base}_paper.png
Future<void> pumpGoldenPair(
  WidgetTester tester, {
  required String base,
  required Widget child,
  Size size = const Size(720, 480),
}) async {
  for (final theme in <LabTheme>[labThemeSignal, labThemePaper]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(LabHarness(theme: theme, child: child));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LabHarness),
      matchesGoldenFile('goldens/${base}_${theme.id}.png'),
    );
  }
}
