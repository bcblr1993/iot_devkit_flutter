import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/services/text_diff_service.dart';

void main() {
  group('TextDiffService', () {
    test('reports identical text without changes', () {
      final result = TextDiffService.compareSync('alpha\nbeta', 'alpha\nbeta');

      expect(result.isIdentical, isTrue);
      expect(result.rows, hasLength(2));
      expect(result.unchangedLines, 2);
    });

    test('aligns changed, removed, and added lines', () {
      final result = TextDiffService.compareSync(
        'alpha\nold\nremove\nomega',
        'alpha\nnew\nomega\nadded',
      );

      expect(result.changedLines, 1);
      expect(result.removedLines, 1);
      expect(result.addedLines, 1);
      expect(
        result.rows.map((row) => row.leftText),
        ['alpha', 'old', 'remove', 'omega', null],
      );
      expect(
        result.rows.map((row) => row.rightText),
        ['alpha', 'new', null, 'omega', 'added'],
      );
    });

    test('normalizes line endings', () {
      final result = TextDiffService.compareSync(
        'alpha\r\nbeta\r\n',
        'alpha\nbeta\n',
      );

      expect(result.isIdentical, isTrue);
      expect(result.rows, hasLength(3));
    });

    test('creates a copyable unified patch', () {
      final patch = TextDiffService.createUnifiedDiff(
        'alpha\nold',
        'alpha\nnew',
      );

      expect(patch, contains('--- original'));
      expect(patch, contains('+++ modified'));
      expect(patch, contains('-old'));
      expect(patch, contains('+new'));
    });

    test('handles a large document without a quadratic matrix', () {
      final original = List.generate(5000, (index) => 'left-$index').join('\n');
      final modified =
          List.generate(5000, (index) => 'right-$index').join('\n');

      final result = TextDiffService.compareSync(original, modified);

      expect(result.changedLines, 5000);
      expect(result.rows, hasLength(5000));
    });
  });
}
