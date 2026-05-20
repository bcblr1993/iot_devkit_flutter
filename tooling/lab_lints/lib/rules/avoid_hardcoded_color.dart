// tooling/lab_lints/lib/rules/avoid_hardcoded_color.dart
//
// 禁止在业务代码里写死颜色：
//   ✗ Color(0xff112233)
//   ✗ Colors.red / Colors.blue.shade300
//   ✓ Theme.of(context).colorScheme.primary
//   ✓ LabTokens.of(context).ok
//
// 设计系统目录（lib/ui/lab/）允许写死颜色，因为 token 定义本身在这里。
// 测试与工具目录也豁免。

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidHardcodedColor extends DartLintRule {
  const AvoidHardcodedColor() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_hardcoded_color',
    problemMessage:
        'Hardcoded color detected. Use Theme.of(context).colorScheme.* '
        'or LabTokens.of(context).* instead.',
    correctionMessage:
        'Replace this literal Color/Colors reference with a theme/token lookup.',
    errorSeverity: ErrorSeverity.ERROR,
  );

  static bool _isExempt(String path) {
    return path.contains('/lib/ui/lab/') ||
        path.contains('/test/') ||
        path.contains('/tooling/') ||
        path.contains('/integration_test/');
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.path;
    if (_isExempt(path)) return;

    // Color(0x...) 构造调用
    context.registry.addInstanceCreationExpression((node) {
      final name = node.constructorName.type.name2.lexeme;
      if (name == 'Color') {
        reporter.reportErrorForNode(_code, node);
      }
    });

    // Colors.xxx / Colors.xxx.shadeNNN
    context.registry.addPrefixedIdentifier((node) {
      if (node.prefix.name == 'Colors') {
        reporter.reportErrorForNode(_code, node);
      }
    });

    // Colors.xxx.shadeNNN — outer is PropertyAccess(Colors.xxx.shade...)
    context.registry.addPropertyAccess((node) {
      final target = node.realTarget;
      if (target is PrefixedIdentifier && target.prefix.name == 'Colors') {
        reporter.reportErrorForNode(_code, node);
      }
    });
  }
}
