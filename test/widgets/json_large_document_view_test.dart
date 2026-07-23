import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/ui/tools/json_large_document_view.dart';

void main() {
  test('large text formatter keeps oversized content out of the text field',
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
}
