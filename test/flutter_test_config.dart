// test/flutter_test_config.dart
//
// `flutter test` 会自动识别同目录下此文件并在所有 test 入口前执行。
// 此处目标：在跑 golden / widget 测试前加载真实字体（Inter / JetBrainsMono），
// 否则 Flutter 测试环境默认使用 Ahem 字体，导致 golden PNG 与开发机渲染严重不一致。

import 'dart:async';

import 'package:golden_toolkit/golden_toolkit.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return GoldenToolkit.runWithConfiguration(
    () async {
      await loadAppFonts();
      await testMain();
    },
    config: GoldenToolkitConfiguration(
      // 允许 0.5% 像素容差：跨平台亚像素抗锯齿差异在该量级内
      defaultDevices: const [Device.phone],
      enableRealShadows: true,
    ),
  );
}
