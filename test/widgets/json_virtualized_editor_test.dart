import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/ui/lab/lab.dart';
import 'package:iot_devkit/ui/tools/json_virtualized_editor.dart';

void main() {
  test('large text formatter redirects oversized content to virtual editor',
      () async {
    String? capturedText;
    final formatter = LargeJsonTextInputFormatter(
      maxEditableCharacters: 10,
      onLargeText: (text) => capturedText = text,
    );
    const oldValue = TextEditingValue(text: '{"a":1}');
    const newValue = TextEditingValue(text: '{"oversized":true}');

    final result = formatter.formatEditUpdate(oldValue, newValue);
    await Future<void>.delayed(Duration.zero);

    expect(result, oldValue);
    expect(capturedText, newValue.text);
  });

  test('virtual controller preserves every character across blocks', () {
    final source = List.generate(
      1000,
      (index) => '{"index":$index,"value":"value-$index"}\r\n',
    ).join();
    final controller = VirtualizedTextController(
      text: source,
      targetBlockCharacters: 256,
      maxLinesPerBlock: 10,
    );

    expect(controller.blocks.length, greaterThan(10));
    expect(controller.length, source.length);
    expect(controller.text, source);
  });

  test('virtual controller splits a ten megabyte document promptly', () {
    const line =
        '    {"ts": 1784612220859, "value": "long-json-value-12345"},\r\n';
    final source = List.filled(180000, line).join();
    expect(source.length, greaterThan(10 * 1024 * 1024));

    final stopwatch = Stopwatch()..start();
    final controller = VirtualizedTextController(text: source);
    stopwatch.stop();

    expect(controller.blocks.length, greaterThan(1000));
    expect(controller.length, source.length);
    expect(controller.text, source);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  testWidgets('virtual editor only builds visible editable blocks',
      (tester) async {
    final source = List.generate(
      10000,
      (index) => '{"index":$index,"value":"value-$index"}\n',
    ).join();
    final controller = VirtualizedTextController(
      text: source,
      targetBlockCharacters: 512,
      maxLinesPerBlock: 12,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: labThemeSignal.themeData,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: VirtualizedJsonEditor(
              controller: controller,
              onChanged: () {},
            ),
          ),
        ),
      ),
    );

    expect(controller.blocks.length, greaterThan(500));
    expect(find.byType(TextField), findsWidgets);
    expect(
      tester.widgetList<TextField>(find.byType(TextField)).length,
      lessThan(20),
    );

    final firstFieldFinder = find.byType(TextField).first;
    final firstField = tester.widget<TextField>(firstFieldFinder);
    final originalLength = controller.length;
    await tester.enterText(
      firstFieldFinder,
      '${firstField.controller!.text} edited',
    );
    await tester.pump();

    expect(controller.text, startsWith('{"index":0'));
    expect(controller.text, contains('edited'));
    expect(controller.length, originalLength + 7);
    expect(controller.text, endsWith('{"index":9999,"value":"value-9999"}\n'));

    final listView = tester.widget<ListView>(
      find.descendant(
        of: find.byType(VirtualizedJsonEditor),
        matching: find.byType(ListView),
      ),
    );
    for (var attempt = 0; attempt < 4; attempt++) {
      listView.controller!
          .jumpTo(listView.controller!.position.maxScrollExtent);
      await tester.pump();
    }

    final lastFieldFinder = find.byType(TextField).hitTestable().last;
    final lastField = tester.widget<TextField>(lastFieldFinder);
    expect(lastField.controller!.text, contains('"index":9999'));
    await tester.enterText(
      lastFieldFinder,
      lastField.controller!.text.replaceFirst('value-9999', 'edited-at-end'),
    );
    await tester.pump();

    expect(controller.text, contains('"value":"edited-at-end"'));
    expect(controller.text, endsWith('\n'));
  });
}
