import 'dart:isolate';

enum TextDiffKind {
  unchanged,
  added,
  removed,
  changed,
}

class TextDiffRow {
  const TextDiffRow({
    this.leftLineNumber,
    this.leftText,
    this.rightLineNumber,
    this.rightText,
    required this.leftKind,
    required this.rightKind,
  });

  final int? leftLineNumber;
  final String? leftText;
  final int? rightLineNumber;
  final String? rightText;
  final TextDiffKind leftKind;
  final TextDiffKind rightKind;
}

class TextDiffResult {
  const TextDiffResult({
    required this.rows,
    required this.addedLines,
    required this.removedLines,
    required this.changedLines,
    required this.unchangedLines,
  });

  final List<TextDiffRow> rows;
  final int addedLines;
  final int removedLines;
  final int changedLines;
  final int unchangedLines;

  bool get isIdentical =>
      addedLines == 0 && removedLines == 0 && changedLines == 0;
}

enum _LineEditKind { equal, insert, delete }

class _LineEdit {
  const _LineEdit(this.kind, this.text);

  final _LineEditKind kind;
  final String text;
}

class TextDiffService {
  const TextDiffService._();

  static const int _smallMatrixCellLimit = 40000;

  static Future<TextDiffResult> compare(String original, String modified) {
    return Isolate.run(() => compareSync(original, modified));
  }

  static TextDiffResult compareSync(String original, String modified) {
    final leftLines = _splitLines(original);
    final rightLines = _splitLines(modified);
    final edits = <_LineEdit>[];

    _diffRange(
      leftLines,
      0,
      leftLines.length,
      rightLines,
      0,
      rightLines.length,
      edits,
    );

    return _alignRows(edits);
  }

  static String createUnifiedDiff(
    String original,
    String modified, {
    String originalLabel = 'original',
    String modifiedLabel = 'modified',
  }) {
    final edits = <_LineEdit>[];
    final leftLines = _splitLines(original);
    final rightLines = _splitLines(modified);
    _diffRange(
      leftLines,
      0,
      leftLines.length,
      rightLines,
      0,
      rightLines.length,
      edits,
    );

    if (edits.every((edit) => edit.kind == _LineEditKind.equal)) {
      return '';
    }

    final buffer = StringBuffer()
      ..writeln('--- $originalLabel')
      ..writeln('+++ $modifiedLabel');
    for (final edit in edits) {
      final marker = switch (edit.kind) {
        _LineEditKind.equal => ' ',
        _LineEditKind.insert => '+',
        _LineEditKind.delete => '-',
      };
      buffer.writeln('$marker${edit.text}');
    }
    return buffer.toString();
  }

  static List<String> _splitLines(String source) {
    if (source.isEmpty) return const <String>[];
    return source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  }

  /// Patience diff keeps large developer-oriented documents responsive while
  /// still producing intuitive hunks around unique lines. Small ambiguous
  /// hunks fall back to an exact LCS comparison.
  static void _diffRange(
    List<String> left,
    int leftStart,
    int leftEnd,
    List<String> right,
    int rightStart,
    int rightEnd,
    List<_LineEdit> output,
  ) {
    var aStart = leftStart;
    var bStart = rightStart;

    while (aStart < leftEnd &&
        bStart < rightEnd &&
        left[aStart] == right[bStart]) {
      output.add(_LineEdit(_LineEditKind.equal, left[aStart]));
      aStart++;
      bStart++;
    }

    var aEnd = leftEnd;
    var bEnd = rightEnd;
    final suffix = <String>[];
    while (
        aStart < aEnd && bStart < bEnd && left[aEnd - 1] == right[bEnd - 1]) {
      suffix.add(left[aEnd - 1]);
      aEnd--;
      bEnd--;
    }

    if (aStart == aEnd) {
      for (var index = bStart; index < bEnd; index++) {
        output.add(_LineEdit(_LineEditKind.insert, right[index]));
      }
      _appendSuffix(output, suffix);
      return;
    }
    if (bStart == bEnd) {
      for (var index = aStart; index < aEnd; index++) {
        output.add(_LineEdit(_LineEditKind.delete, left[index]));
      }
      _appendSuffix(output, suffix);
      return;
    }

    final anchors = _patienceAnchors(
      left,
      aStart,
      aEnd,
      right,
      bStart,
      bEnd,
    );

    if (anchors.isEmpty) {
      final leftLength = aEnd - aStart;
      final rightLength = bEnd - bStart;
      if (leftLength * rightLength <= _smallMatrixCellLimit) {
        _appendLcsDiff(
          left,
          aStart,
          aEnd,
          right,
          bStart,
          bEnd,
          output,
        );
      } else {
        for (var index = aStart; index < aEnd; index++) {
          output.add(_LineEdit(_LineEditKind.delete, left[index]));
        }
        for (var index = bStart; index < bEnd; index++) {
          output.add(_LineEdit(_LineEditKind.insert, right[index]));
        }
      }
      _appendSuffix(output, suffix);
      return;
    }

    var previousLeft = aStart;
    var previousRight = bStart;
    for (final anchor in anchors) {
      _diffRange(
        left,
        previousLeft,
        anchor.$1,
        right,
        previousRight,
        anchor.$2,
        output,
      );
      output.add(_LineEdit(_LineEditKind.equal, left[anchor.$1]));
      previousLeft = anchor.$1 + 1;
      previousRight = anchor.$2 + 1;
    }
    _diffRange(
      left,
      previousLeft,
      aEnd,
      right,
      previousRight,
      bEnd,
      output,
    );
    _appendSuffix(output, suffix);
  }

  static void _appendSuffix(List<_LineEdit> output, List<String> suffix) {
    for (final line in suffix.reversed) {
      output.add(_LineEdit(_LineEditKind.equal, line));
    }
  }

  static List<(int, int)> _patienceAnchors(
    List<String> left,
    int leftStart,
    int leftEnd,
    List<String> right,
    int rightStart,
    int rightEnd,
  ) {
    final leftOccurrences = <String, List<int>>{};
    final rightOccurrences = <String, List<int>>{};

    for (var index = leftStart; index < leftEnd; index++) {
      leftOccurrences.putIfAbsent(left[index], () => <int>[]).add(index);
    }
    for (var index = rightStart; index < rightEnd; index++) {
      rightOccurrences.putIfAbsent(right[index], () => <int>[]).add(index);
    }

    final candidates = <(int, int)>[];
    for (final entry in leftOccurrences.entries) {
      final rightPositions = rightOccurrences[entry.key];
      if (entry.value.length == 1 && rightPositions?.length == 1) {
        candidates.add((entry.value.single, rightPositions!.single));
      }
    }
    candidates.sort((a, b) => a.$1.compareTo(b.$1));
    if (candidates.isEmpty) return const <(int, int)>[];

    final pileTops = <int>[];
    final predecessors = List<int>.filled(candidates.length, -1);
    final pileIndexes = <int>[];

    for (var index = 0; index < candidates.length; index++) {
      final rightIndex = candidates[index].$2;
      var low = 0;
      var high = pileTops.length;
      while (low < high) {
        final middle = (low + high) >> 1;
        if (pileTops[middle] < rightIndex) {
          low = middle + 1;
        } else {
          high = middle;
        }
      }

      if (low == pileTops.length) {
        pileTops.add(rightIndex);
        pileIndexes.add(index);
      } else {
        pileTops[low] = rightIndex;
        pileIndexes[low] = index;
      }
      if (low > 0) {
        predecessors[index] = pileIndexes[low - 1];
      }
    }

    final result = <(int, int)>[];
    var current = pileIndexes.last;
    while (current >= 0) {
      result.add(candidates[current]);
      current = predecessors[current];
    }
    return result.reversed.toList(growable: false);
  }

  static void _appendLcsDiff(
    List<String> left,
    int leftStart,
    int leftEnd,
    List<String> right,
    int rightStart,
    int rightEnd,
    List<_LineEdit> output,
  ) {
    final leftLength = leftEnd - leftStart;
    final rightLength = rightEnd - rightStart;
    final matrix = List<List<int>>.generate(
      leftLength + 1,
      (_) => List<int>.filled(rightLength + 1, 0),
      growable: false,
    );

    for (var leftOffset = leftLength - 1; leftOffset >= 0; leftOffset--) {
      for (var rightOffset = rightLength - 1; rightOffset >= 0; rightOffset--) {
        if (left[leftStart + leftOffset] == right[rightStart + rightOffset]) {
          matrix[leftOffset][rightOffset] =
              matrix[leftOffset + 1][rightOffset + 1] + 1;
        } else {
          matrix[leftOffset][rightOffset] = matrix[leftOffset + 1]
                      [rightOffset] >=
                  matrix[leftOffset][rightOffset + 1]
              ? matrix[leftOffset + 1][rightOffset]
              : matrix[leftOffset][rightOffset + 1];
        }
      }
    }

    var leftOffset = 0;
    var rightOffset = 0;
    while (leftOffset < leftLength && rightOffset < rightLength) {
      final leftLine = left[leftStart + leftOffset];
      final rightLine = right[rightStart + rightOffset];
      if (leftLine == rightLine) {
        output.add(_LineEdit(_LineEditKind.equal, leftLine));
        leftOffset++;
        rightOffset++;
      } else if (matrix[leftOffset + 1][rightOffset] >=
          matrix[leftOffset][rightOffset + 1]) {
        output.add(_LineEdit(_LineEditKind.delete, leftLine));
        leftOffset++;
      } else {
        output.add(_LineEdit(_LineEditKind.insert, rightLine));
        rightOffset++;
      }
    }
    while (leftOffset < leftLength) {
      output.add(
        _LineEdit(_LineEditKind.delete, left[leftStart + leftOffset]),
      );
      leftOffset++;
    }
    while (rightOffset < rightLength) {
      output.add(
        _LineEdit(_LineEditKind.insert, right[rightStart + rightOffset]),
      );
      rightOffset++;
    }
  }

  static TextDiffResult _alignRows(List<_LineEdit> edits) {
    final rows = <TextDiffRow>[];
    var leftLineNumber = 1;
    var rightLineNumber = 1;
    var addedLines = 0;
    var removedLines = 0;
    var changedLines = 0;
    var unchangedLines = 0;
    var index = 0;

    while (index < edits.length) {
      final edit = edits[index];
      if (edit.kind == _LineEditKind.equal) {
        rows.add(
          TextDiffRow(
            leftLineNumber: leftLineNumber++,
            leftText: edit.text,
            rightLineNumber: rightLineNumber++,
            rightText: edit.text,
            leftKind: TextDiffKind.unchanged,
            rightKind: TextDiffKind.unchanged,
          ),
        );
        unchangedLines++;
        index++;
        continue;
      }

      final deleted = <String>[];
      final inserted = <String>[];
      while (index < edits.length && edits[index].kind != _LineEditKind.equal) {
        final hunkEdit = edits[index];
        if (hunkEdit.kind == _LineEditKind.delete) {
          deleted.add(hunkEdit.text);
        } else {
          inserted.add(hunkEdit.text);
        }
        index++;
      }

      final pairedCount =
          deleted.length < inserted.length ? deleted.length : inserted.length;
      for (var hunkIndex = 0; hunkIndex < pairedCount; hunkIndex++) {
        rows.add(
          TextDiffRow(
            leftLineNumber: leftLineNumber++,
            leftText: deleted[hunkIndex],
            rightLineNumber: rightLineNumber++,
            rightText: inserted[hunkIndex],
            leftKind: TextDiffKind.changed,
            rightKind: TextDiffKind.changed,
          ),
        );
        changedLines++;
      }
      for (var hunkIndex = pairedCount;
          hunkIndex < deleted.length;
          hunkIndex++) {
        rows.add(
          TextDiffRow(
            leftLineNumber: leftLineNumber++,
            leftText: deleted[hunkIndex],
            leftKind: TextDiffKind.removed,
            rightKind: TextDiffKind.removed,
          ),
        );
        removedLines++;
      }
      for (var hunkIndex = pairedCount;
          hunkIndex < inserted.length;
          hunkIndex++) {
        rows.add(
          TextDiffRow(
            rightLineNumber: rightLineNumber++,
            rightText: inserted[hunkIndex],
            leftKind: TextDiffKind.added,
            rightKind: TextDiffKind.added,
          ),
        );
        addedLines++;
      }
    }

    return TextDiffResult(
      rows: rows,
      addedLines: addedLines,
      removedLines: removedLines,
      changedLines: changedLines,
      unchangedLines: unchangedLines,
    );
  }
}
