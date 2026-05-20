// tooling/lab_lints/lib/lab_lints.dart
//
// custom_lint plugin entry point — exposes 3 rules:
//   · avoid_hardcoded_color   (ERROR)   禁止 Color(0xRRGGBB) / Colors.xxx
//   · avoid_raw_edge_insets   (WARNING) 禁止 EdgeInsets.* 用字面量
//   · prefer_lab_tokens       (INFO)    建议改用 LabTokens.of(context).sXxx / rXxx
//
// 入口约定：custom_lint 调用 createPlugin()。

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'rules/avoid_hardcoded_color.dart';
import 'rules/avoid_raw_edge_insets.dart';
import 'rules/prefer_lab_tokens.dart';

PluginBase createPlugin() => _LabLintsPlugin();

class _LabLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const AvoidHardcodedColor(),
        const AvoidRawEdgeInsets(),
        const PreferLabTokens(),
      ];
}
