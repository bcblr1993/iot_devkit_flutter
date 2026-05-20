// tooling/lab_lints/lib/rules/avoid_raw_edge_insets.dart
//
// 禁止 EdgeInsets / EdgeInsetsDirectional 用字面量：
//   ✗ EdgeInsets.all(8)
//   ✗ EdgeInsets.symmetric(horizontal: 12, vertical: 6)
//   ✗ const EdgeInsets.fromLTRB(8, 4, 8, 4)
//   ✓ EdgeInsets.all(LabTokens.of(context).sMd)
//   ✓ EdgeInsets.symmetric(horizontal: tokens.sLg)
//
// 至少一个参数是字面量数字才告警；全部来自 token / 变量则放行。
// 设计系统、测试与工具目录豁免。

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidRawEdgeInsets extends DartLintRule {
  const AvoidRawEdgeInsets() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_raw_edge_insets',
    problemMessage:
        'EdgeInsets uses a literal number. Prefer LabTokens.of(context).sXxx '
        'so spacing stays consistent across the design system.',
    correctionMessage:
        'Replace literal padding values with LabTokens.of(context).sXxs/sXs/sSm/sMd/sLg/sXl/...',
    errorSeverity: ErrorSeverity.WARNING,
  );

  static const _edgeTypes = {'EdgeInsets', 'EdgeInsetsDirectional'};

  static bool _isExempt(String path) {
    return path.contains('/lib/ui/lab/') ||
        path.contains('/test/') ||
        path.contains('/tooling/') ||
        path.contains('/integration_test/');
  }

  static bool _hasLiteralArg(InstanceCreationExpression node) {
    for (final arg in node.argumentList.arguments) {
      final expr = arg is NamedExpression ? arg.expression : arg;
      if (expr is IntegerLiteral || expr is DoubleLiteral) return true;
    }
    return false;
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (_isExempt(resolver.path)) return;

    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name2.lexeme;
      if (!_edgeTypes.contains(typeName)) return;
      // 仅在含字面量数字时告警，避免误伤 tokens 化的写法
      if (_hasLiteralArg(node)) reporter.reportErrorForNode(_code, node);
    });
  }
}
