import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/services/json_formatter_service.dart';

void main() {
  group('JsonFormatterService', () {
    test('formats and minifies JSON in a background isolate', () async {
      const source = '{"device":"dev-1","temperature":23}';

      final pretty = await JsonFormatterService.transform(
        source,
        JsonOutputStyle.pretty,
      );
      final compact = await JsonFormatterService.transform(
        pretty.output,
        JsonOutputStyle.compact,
      );

      expect(pretty.output, contains('\n'));
      expect(pretty.output, contains('    "temperature": 23'));
      expect(compact.output, source);
      expect(compact.data, jsonDecode(source));
    });

    test('preserves CRLF for an already formatted document', () async {
      const source = '{\r\n    "value": 1\r\n}';

      final result = await JsonFormatterService.transform(
        source,
        JsonOutputStyle.pretty,
      );

      expect(result.output, source);
    });

    test('handles a large JSON document without changing its data', () async {
      const itemCount = 122985;
      final source = jsonEncode({
        'values': [
          for (var index = 0; index < itemCount; index++)
            {'ts': index, 'value': '$index'},
        ],
      });

      final result = await JsonFormatterService.transform(
        source,
        JsonOutputStyle.pretty,
      );

      expect(
        (result.data as Map<String, dynamic>)['values'],
        hasLength(itemCount),
      );
      expect(result.output, contains('"value": "122984"'));
    });

    test('searches large JSON off the UI isolate and caps common matches',
        () async {
      final source = jsonEncode({
        'values': [
          for (var index = 0; index < 5000; index++)
            {'ts': index, 'value': 'reading-$index'},
        ],
      });

      final result = await JsonFormatterService.search(
        source,
        'value',
        maxMatches: 100,
      );

      expect(result.paths, hasLength(100));
      expect(result.paths, contains(equals(['values', 0, 'value'])));
      expect(result.isTruncated, isTrue);
    });
  });
}
