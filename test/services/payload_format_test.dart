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

  group('random change report', () {
    Map<String, dynamic> valuesOf(WorkerInput i) =>
        (jsonDecode(generatePayloadJson(i)) as Map)['values']
            as Map<String, dynamic>;

    test('emits exactly `count` keys drawn from the full namespace', () {
      final out = valuesOf(WorkerInput(
        count: 150,
        timestamp: 1,
        key1Value: 1,
        customKeyValues: const {},
        totalKeyCount: 500,
        randomKeys: true,
      ));
      expect(out.length, 150);
      // Every emitted key must belong to the 500-key namespace (key_1..key_500).
      for (final k in out.keys) {
        final n = int.parse(k.substring('key_'.length));
        expect(n >= 1 && n <= 500, isTrue, reason: '$k out of range');
      }
    });

    test('selection varies between ticks (not the fixed first N)', () {
      WorkerInput mk() => WorkerInput(
            count: 150,
            timestamp: 1,
            key1Value: 1,
            customKeyValues: const {},
            totalKeyCount: 500,
            randomKeys: true,
          );
      final a = valuesOf(mk()).keys.toSet();
      final b = valuesOf(mk()).keys.toSet();
      // Two independent random draws of 150/500 are practically never identical.
      expect(a.difference(b).isNotEmpty, isTrue);
      // And it is NOT just the deterministic first-150 prefix.
      final firstN =
          List.generate(150, (i) => i == 0 ? 'key_1' : 'key_${i + 1}').toSet();
      expect(a == firstN, isFalse);
    });

    test('disabled → deterministic first-N prefix', () {
      final out = valuesOf(WorkerInput(
        count: 3,
        timestamp: 1,
        key1Value: 9,
        customKeyValues: const {},
        totalKeyCount: 500,
        randomKeys: false,
      ));
      expect(out.keys.toList(), ['key_1', 'key_2', 'key_3']);
    });
  });
}
