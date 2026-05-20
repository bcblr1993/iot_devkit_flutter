// tooling/lab_lints/lib/rules/prefer_lab_tokens.dart
//
// 提示：BorderRadius.circular(N) 用字面量时建议改用 LabTokens 圆角刻度。
//   ✗ BorderRadius.circular(8)
//   ✓ BorderRadius.circular(LabTokens.of(context).rLg)
//
// 这是 INFO 级，不会让 CI 挂；只作为推动迁移的"导航箭头"。
// 设计系统、测试与工具目录豁免。

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class PreferLabTokens extends DartLintRule {
  const PreferLabTokens() : super(code: _code);

  static const _code = LintCode(
    name: 'prefer_lab_tokens',
    problemMessage:
        'BorderRadius.circular uses a literal number. Prefer LabTokens.of(context).rXxx.',
    correctionMessage:
        'Use one of LabTokens.of(context).rXs/rSm/rMd/rLg/rXl to stay on the token scale.',
    errorSeverity: ErrorSeverity.INFO,
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
    if (_isExempt(resolver.path)) return;

    // BorderRadius.circular(...) 实际是命名工厂构造，AST 节点为 InstanceCreationExpression
    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name2.lexeme;
      if (typeName != 'BorderRadius') return;
      final ctor = node.constructorName.name?.name;
      if (ctor != 'circular') return;
      final args = node.argumentList.arguments;
      if (args.length != 1) return;
      final a = args.first;
      if (a is IntegerLiteral || a is DoubleLiteral) {
        reporter.reportErrorForNode(_code, node);
      }
    });
  }
}
