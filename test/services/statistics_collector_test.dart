import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/utils/statistics_collector.dart';

void main() {
  late StatisticsCollector collector;

  setUp(() {
    collector = StatisticsCollector();
  });

  tearDown(() {
    collector.dispose();
  });

  test('separates publish failures, late drops, and generation errors', () {
    collector.incrementSuccess(points: 150);
    collector.incrementSuccess(points: 500);
    collector.incrementFailure();
    collector.incrementLateDropped(count: 3);
    collector.incrementGenerationError(count: 2);

    expect(collector.totalMessages, 3);
    expect(collector.successCount, 2);
    expect(collector.failureCount, 1);
    expect(collector.lateDroppedCount, 3);
    expect(collector.generationErrorCount, 2);
    expect(collector.totalPoints, 650);
  });

  test('normalizes message, point, and bandwidth rates by real elapsed time',
      () {
    collector.incrementSuccess(points: 150);
    collector.incrementFailure();
    collector.setMessageSize(2048);

    collector.calculateRatesForTest(const Duration(milliseconds: 500));

    expect(collector.currentTps, closeTo(4.0, 0.001));
    expect(collector.currentPointsPerSecond, closeTo(300.0, 0.001));
    expect(collector.currentBandwidth, closeTo(4.0, 0.001));

    collector.incrementSuccess(points: 100);
    collector.setMessageSize(1024);
    collector.calculateRatesForTest(const Duration(seconds: 2));

    expect(collector.currentTps, closeTo(0.5, 0.001));
    expect(collector.currentPointsPerSecond, closeTo(50.0, 0.001));
    expect(collector.currentBandwidth, closeTo(0.5, 0.001));
  });

  test('reset clears the new counters and rate baselines', () {
    collector.incrementSuccess(points: 150);
    collector.incrementFailure();
    collector.incrementLateDropped();
    collector.incrementGenerationError();
    collector.calculateRatesForTest(const Duration(seconds: 1));

    collector.reset();

    expect(collector.totalMessages, 0);
    expect(collector.totalPoints, 0);
    expect(collector.failureCount, 0);
    expect(collector.lateDroppedCount, 0);
    expect(collector.generationErrorCount, 0);
    expect(collector.currentTps, 0);
    expect(collector.currentPointsPerSecond, 0);
  });

  test('applies worker-process aggregates without recalculating local rates',
      () {
    collector.beginExternalAggregation();
    collector.applyExternalAggregate({
      'totalDevices': 2000,
      'onlineDevices': 1998,
      'totalMessages': 32000,
      'successCount': 31998,
      'failureCount': 2,
      'lateDroppedCount': 0,
      'generationErrorCount': 0,
      'totalPoints': 6200000,
      'totalBytes': 1024,
      'totalLatency': 90,
      'latencySamples': 3,
      'currentTps': 3000.0,
      'currentPointsPerSecond': 800000.0,
      'currentBandwidth': 2048.0,
      'currentLatency': 30.0,
      'memoryUsage': 300 * 1024 * 1024,
      'messageSize': 8192,
    });

    expect(collector.totalDevices, 2000);
    expect(collector.onlineDevices, 1998);
    expect(collector.successCount, 31998);
    expect(collector.failureCount, 2);
    expect(collector.currentTps, 3000);
    expect(collector.currentPointsPerSecond, 800000);
    expect(collector.memoryUsage, 300 * 1024 * 1024);

    collector.calculateRatesForTest(const Duration(seconds: 1));
    expect(collector.currentTps, 3000);
    expect(collector.currentPointsPerSecond, 800000);

    collector.endExternalAggregation();
    collector.reset();
    expect(collector.totalDevices, 0);
    expect(collector.currentPointsPerSecond, 0);
  });
}
