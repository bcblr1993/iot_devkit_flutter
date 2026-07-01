import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/models/payload_format.dart';
import 'package:iot_devkit/utils/isolate_worker.dart';

void main() {
  group('PayloadFormat.buildStandard', () {
    final values = {'temperature': 22.5, 'humidity': 61};
    const ts = 1451649600512;

    test('simpleKv returns the flat values map (no ts)', () {
      final out = PayloadFormat.buildStandard(values, ts, PayloadFormat.simpleKv);
      expect(out, isA<Map>());
      expect(out, equals(values));
    });

    test('timestamped wraps into {ts, values}', () {
      final out =
          PayloadFormat.buildStandard(values, ts, PayloadFormat.timestamped);
      expect(out, {'ts': ts, 'values': values});
    });

    test('array wraps into [{ts, values}]', () {
      final out = PayloadFormat.buildStandard(values, ts, PayloadFormat.array);
      expect(out, isA<List>());
      expect((out as List).single, {'ts': ts, 'values': values});
    });

    test('legacy "default" normalizes to timestamped', () {
      expect(PayloadFormat.normalize('default'), PayloadFormat.timestamped);
      expect(PayloadFormat.normalize(null), PayloadFormat.timestamped);
      final out = PayloadFormat.buildStandard(values, ts, 'default');
      expect(out, {'ts': ts, 'values': values});
    });
  });

  group('generatePayloadJson honors the requested format', () {
    WorkerInput input(String format) => WorkerInput(
          count: 3,
          timestamp: 1000,
          key1Value: 7,
          customKeyValues: const {},
          format: format,
        );

    test('simpleKv → flat object with key_1, no ts', () {
      final decoded = jsonDecode(generatePayloadJson(input(PayloadFormat.simpleKv)));
      expect(decoded, isA<Map>());
      expect(decoded['key_1'], 7);
      expect(decoded.containsKey('ts'), false);
    });

    test('timestamped → {ts, values}', () {
      final decoded =
          jsonDecode(generatePayloadJson(input(PayloadFormat.timestamped)));
      expect(decoded['ts'], 1000);
      expect(decoded['values']['key_1'], 7);
    });

    test('array → [{ts, values}]', () {
      final decoded = jsonDecode(generatePayloadJson(input(PayloadFormat.array)));
      expect(decoded, isA<List>());
      expect(decoded.first['ts'], 1000);
      expect(decoded.first['values']['key_1'], 7);
    });
  });
}
