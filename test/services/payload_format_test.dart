import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/models/payload_format.dart';
import 'package:iot_devkit/utils/isolate_worker.dart';

void main() {
  group('PayloadFormat.buildStandard', () {
    final values = {'temperature': 22.5, 'humidity': 61};
    const ts = 1451649600512;

    test('simpleKv returns the flat values map (no ts)', () {
      final out =
          PayloadFormat.buildStandard(values, ts, PayloadFormat.simpleKv);
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
      final decoded =
          jsonDecode(generatePayloadJson(input(PayloadFormat.simpleKv)));
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
      final decoded =
          jsonDecode(generatePayloadJson(input(PayloadFormat.array)));
      expect(decoded, isA<List>());
      expect(decoded.first['ts'], 1000);
      expect(decoded.first['values']['key_1'], 7);
    });

    test('TieNiu full report keeps the dedicated payload shape', () {
      final decoded =
          jsonDecode(generatePayloadJson(input(PayloadFormat.tieNiu)));

      expect(decoded['type'], 'real');
      expect(decoded['time'], 1000);
      expect(decoded['data']['C24_D1'], hasLength(3));
      expect(decoded.containsKey('values'), isFalse);
    });

    test('TieNiu empty full report emits no logical data points', () {
      final decoded =
          jsonDecode(generatePayloadJson(input(PayloadFormat.tieNiuEmpty)));

      expect(decoded['type'], 'real');
      expect(decoded['time'], 1000);
      expect(decoded['data'], isEmpty);
      expect(decoded.containsKey('values'), isFalse);
    });

    test('UTF-8 byte generation matches JSON text and preserves non-ASCII', () {
      final workerInput = WorkerInput(
        count: 2,
        timestamp: 1000,
        key1Value: 7,
        customKeyValues: const {'设备名称': '温度计一号'},
        format: PayloadFormat.timestamped,
      );

      final text = generatePayloadJson(workerInput, random: Random(42));
      final bytes = generatePayloadUtf8(workerInput, random: Random(42));

      expect(utf8.decode(bytes), text);
      expect(utf8.decode(bytes), contains('温度计一号'));
    });

    test('zero requested points emits an empty values map', () {
      final decoded = jsonDecode(generatePayloadJson(WorkerInput(
        count: 0,
        timestamp: 1000,
        key1Value: 7,
        customKeyValues: const {'extra': 1},
      )));

      expect(decoded['values'], isEmpty);
    });

    test('custom keys never exceed the requested point count', () {
      final decoded = jsonDecode(generatePayloadJson(WorkerInput(
        count: 2,
        timestamp: 1000,
        key1Value: 7,
        customKeyValues: const {
          'custom_1': 1,
          'custom_2': 2,
          'custom_3': 3,
        },
      )));

      expect(decoded['values'], {'key_1': 7, 'custom_1': 1});
    });

    test('isolate pool returns a transferable UTF-8 payload', () async {
      final manager = PersistentIsolateManager.instance;
      await manager.init();
      try {
        final bytes = await manager.computeBytesTask(WorkerInput(
          count: 2,
          timestamp: 1000,
          key1Value: 7,
          customKeyValues: const {'设备名称': '温度计一号'},
          format: PayloadFormat.timestamped,
        ));
        final decoded = jsonDecode(utf8.decode(bytes));

        expect(decoded['values']['设备名称'], '温度计一号');
      } finally {
        manager.dispose();
      }
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
