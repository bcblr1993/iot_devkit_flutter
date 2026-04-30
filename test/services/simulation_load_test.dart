import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/services/mqtt/scheduler_service.dart';
import 'package:iot_devkit/utils/isolate_worker.dart';
import 'package:iot_devkit/utils/statistics_collector.dart';

void main() {
  group('Large simulation load smoke tests', () {
    test('generates large batches of telemetry payloads within budget', () {
      const deviceCount = 1000;
      const keyCountPerDevice = 200;
      const maxElapsedMs = 5000;

      final stopwatch = Stopwatch()..start();
      var totalBytes = 0;

      for (var i = 0; i < deviceCount; i++) {
        final payload = generatePayloadJson(
          WorkerInput(
            count: keyCountPerDevice,
            clientId: 'device_$i',
            timestamp: 1700000000000 + i,
            key1Value: i + 1,
            customKeyValues: const {},
          ),
        );

        final decoded = jsonDecode(payload) as Map<String, dynamic>;
        expect(decoded['ts'], 1700000000000 + i);
        expect(decoded['values'], isA<Map<String, dynamic>>());
        expect((decoded['values'] as Map<String, dynamic>).length,
            keyCountPerDevice);

        totalBytes += payload.length;
      }

      stopwatch.stop();

      expect(totalBytes, greaterThan(0));
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(maxElapsedMs),
        reason:
            'Generated $deviceCount payloads x $keyCountPerDevice keys too slowly.',
      );
    });

    test('computes low-latency schedules for many devices within budget', () {
      const deviceCount = 100000;
      const intervalMs = 1000;
      const maxElapsedMs = 2000;

      final statisticsCollector = StatisticsCollector();
      final scheduler = SchedulerService(
        statisticsCollector: statisticsCollector,
        onLog: (_, __, {tag}) {},
      );

      try {
        final stopwatch = Stopwatch()..start();
        var droppedTicks = 0;

        for (var i = 0; i < deviceCount; i++) {
          final decision = scheduler.computeNextScheduleForTest(
            nowMs: 1700000000000,
            alignedStartTime: 1699999997000,
            phaseOffset: i % intervalMs,
            intervalMs: intervalMs,
            sendCount: i.isEven ? 1 : 2,
          );

          expect(decision.delayMs, greaterThanOrEqualTo(0));
          droppedTicks += decision.skippedCount;
        }

        stopwatch.stop();

        expect(droppedTicks, greaterThan(0));
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(maxElapsedMs),
          reason: 'Computed $deviceCount schedules too slowly.',
        );
      } finally {
        scheduler.stopAll();
        statisticsCollector.dispose();
      }
    });
  });
}
