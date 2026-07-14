import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/services/mqtt/scheduler_service.dart';
import 'package:iot_devkit/utils/statistics_collector.dart';

void main() {
  late StatisticsCollector statisticsCollector;
  late SchedulerService scheduler;

  setUp(() {
    statisticsCollector = StatisticsCollector();
    scheduler = SchedulerService(
      statisticsCollector: statisticsCollector,
      onLog: (_, __, {tag}) {},
    );
  });

  tearDown(() {
    scheduler.stopAll();
    statisticsCollector.dispose();
  });

  group('SchedulerService low-latency scheduling', () {
    test('keeps the original send count for small timing jitter', () {
      final decision = scheduler.computeNextScheduleForTest(
        nowMs: 1010,
        alignedStartTime: 0,
        phaseOffset: 0,
        intervalMs: 1000,
        sendCount: 1,
      );

      expect(decision.sendCount, 1);
      expect(decision.delayMs, 0);
      expect(decision.skippedCount, 0);
      expect(decision.droppedLateTicks, isFalse);
      expect(statisticsCollector.failureCount, 0);
    });

    test('drops stale ticks instead of catching up when far behind', () {
      final decision = scheduler.computeNextScheduleForTest(
        nowMs: 3500,
        alignedStartTime: 0,
        phaseOffset: 0,
        intervalMs: 1000,
        sendCount: 1,
      );

      expect(decision.sendCount, 4);
      expect(decision.delayMs, 500);
      expect(decision.skippedCount, 3);
      expect(decision.droppedLateTicks, isTrue);
    });

    test('preserves normal timing when the next tick is still in the future',
        () {
      final decision = scheduler.computeNextScheduleForTest(
        nowMs: 1200,
        alignedStartTime: 0,
        phaseOffset: 200,
        intervalMs: 1000,
        sendCount: 2,
      );

      expect(decision.sendCount, 2);
      expect(decision.delayMs, 1000);
      expect(decision.skippedCount, 0);
      expect(decision.droppedLateTicks, isFalse);
    });

    test('clamps invalid intervals to avoid zero-delay scheduler crashes', () {
      final decision = scheduler.computeNextScheduleForTest(
        nowMs: 3500,
        alignedStartTime: 0,
        phaseOffset: 0,
        intervalMs: 0,
        sendCount: 1,
      );

      expect(decision.delayMs, greaterThanOrEqualTo(0));
      expect(decision.sendCount, greaterThan(1));
    });
  });

  group('Advanced full/change coverage', () {
    test('skips one nearest change tick for every staggered full period', () {
      final skipped = <int>[];

      for (var changeCount = 0; changeCount <= 900; changeCount++) {
        if (shouldSkipChangeTickCoveredByFull(
          alignedStartTime: 1700000000000,
          changePhaseOffset: 468,
          changeIntervalMs: 1000,
          changeSendCount: changeCount,
          fullPhaseOffset: 123,
          fullIntervalMs: 300000,
        )) {
          skipped.add(changeCount);
        }
      }

      // The old exact-equality check never matched these grids because their
      // phase difference is 345 ms. Each full target now covers one tick.
      expect(skipped, [0, 300, 600, 900]);
      expect(statisticsCollector.failureCount, 0);
      expect(statisticsCollector.lateDroppedCount, 0);
    });

    test('handles non-divisible intervals and resolves exact ties earlier', () {
      final skipped = <int>[];

      for (var changeCount = 0; changeCount <= 8; changeCount++) {
        if (shouldSkipChangeTickCoveredByFull(
          alignedStartTime: 0,
          changePhaseOffset: 0,
          changeIntervalMs: 1000,
          changeSendCount: changeCount,
          fullPhaseOffset: 500,
          fullIntervalMs: 2500,
        )) {
          skipped.add(changeCount);
        }
      }

      expect(skipped, [0, 3, 5, 8]);
    });

    test('suppresses only after the covered full target really succeeded', () {
      final earlierFullTarget = fullTargetCoveredByChangeTick(
        alignedStartTime: 0,
        changePhaseOffset: 468,
        changeIntervalMs: 1000,
        changeSendCount: 0,
        fullPhaseOffset: 123,
        fullIntervalMs: 300000,
      );
      expect(earlierFullTarget, 123);
      expect(
        shouldSuppressChangeAfterFull(
          coveredFullTarget: earlierFullTarget,
          changeTarget: 468,
          lastSuccessfulFullTarget: 123,
        ),
        isTrue,
      );
      expect(
        shouldSuppressChangeAfterFull(
          coveredFullTarget: earlierFullTarget,
          changeTarget: 468,
          lastSuccessfulFullTarget: null,
        ),
        isFalse,
        reason: 'failed or in-flight full report must keep the change fallback',
      );

      final futureFullTarget = fullTargetCoveredByChangeTick(
        alignedStartTime: 0,
        changePhaseOffset: 0,
        changeIntervalMs: 1000,
        changeSendCount: 0,
        fullPhaseOffset: 500,
        fullIntervalMs: 2500,
      );
      expect(futureFullTarget, 500);
      expect(
        shouldSuppressChangeAfterFull(
          coveredFullTarget: futureFullTarget,
          changeTarget: 0,
          lastSuccessfulFullTarget: 500,
        ),
        isFalse,
        reason: 'a future full target cannot cover an earlier change publish',
      );
    });

    test('does not cover change ticks when full reporting is disabled', () {
      expect(
        shouldSkipChangeTickCoveredByFull(
          alignedStartTime: 0,
          changePhaseOffset: 0,
          changeIntervalMs: 1000,
          changeSendCount: 0,
          fullPhaseOffset: 0,
          fullIntervalMs: 0,
        ),
        isFalse,
      );
    });
  });

  group('SchedulerService lifecycle', () {
    test('prunes fired timers so long-running sessions stop quickly', () async {
      const clientId = 'device_timer_prune';
      scheduler.registerTimerBucketForTest(clientId);

      for (var i = 0; i < 1000; i++) {
        scheduler.addTimerForTest(clientId, Timer(Duration.zero, () {}));
      }

      await Future<void>.delayed(Duration.zero);

      scheduler.addTimerForTest(
        clientId,
        Timer(const Duration(minutes: 1), () {}),
      );

      expect(scheduler.timerCountForTest(clientId), 1);

      scheduler.stopAll();

      expect(scheduler.timerCountForTest(clientId), 0);
    });
  });
}
