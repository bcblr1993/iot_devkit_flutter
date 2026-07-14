import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/models/auto_process_plan.dart';
import 'package:iot_devkit/models/group_config.dart';

void main() {
  group('AutoProcessPlan', () {
    test('plans three shards for the reported 2000-device peak', () {
      final plan = AutoProcessPlan.fromAdvancedGroups([
        GroupConfig(
          startDeviceNumber: 1,
          endDeviceNumber: 2000,
          totalKeyCount: 500,
          changeRatio: 0.3,
          changeIntervalSeconds: 1,
          fullIntervalSeconds: 300,
        ),
      ]);

      expect(plan.steadyPointsPerSecond, 300000);
      expect(plan.changeBurstPointsPerSecond, 300000);
      expect(plan.fullBurstPointsPerSecond, 500000);
      expect(plan.peakPointsPerSecond, 800000);
      expect(plan.processCount, 3);
      expect(plan.requiresMultipleProcesses, isTrue);
      expect(plan.reason, AutoProcessPlanReason.peakPointsExceedLimit);
      expect(plan.canSatisfyLimitByDeviceSharding, isTrue);
      expect(plan.warning, isNull);
      expect(
        plan.shardEstimates.map((estimate) => estimate.deviceCount),
        [667, 667, 666],
      );
      expect(
        plan.shardEstimates.map((estimate) => estimate.peakPointsPerSecond),
        [266800, 266800, 266400],
      );
      expect(
        plan.shardEstimates.every(
          (estimate) =>
              estimate.peakPointsPerSecond <= plan.pointLimitPerProcess,
        ),
        isTrue,
      );
    });

    test('keeps one process when full reporting is disabled', () {
      final plan = AutoProcessPlan.fromAdvancedGroups([
        GroupConfig(
          startDeviceNumber: 1,
          endDeviceNumber: 2000,
          totalKeyCount: 500,
          changeRatio: 0.3,
          changeIntervalSeconds: 1,
          fullIntervalSeconds: 0,
        ),
      ]);

      expect(plan.steadyPointsPerSecond, 300000);
      expect(plan.changeBurstPointsPerSecond, 300000);
      expect(plan.fullBurstPointsPerSecond, 0);
      expect(plan.peakPointsPerSecond, 300000);
      expect(plan.processCount, 1);
      expect(plan.requiresMultipleProcesses, isFalse);
      expect(plan.reason, AutoProcessPlanReason.singleProcessWithinLimit);
    });

    test('plans basic mode from the controller config map', () {
      final plan = AutoProcessPlan.fromConfig({
        'mode': 'basic',
        'device_start_number': 1,
        'device_end_number': 1001,
        'send_interval': 2,
        'data': {'data_point_count': 600},
      });

      expect(plan.mode, AutoProcessPlanMode.basic);
      expect(plan.steadyPointsPerSecond, 300300);
      expect(plan.peakPointsPerSecond, 300300);
      expect(plan.processCount, 2);
      expect(plan.requiredProcessCount, 2);
      expect(
        plan.shardEstimates.map((shard) => shard.deviceCount),
        [501, 500],
      );
      expect(
        plan.shardEstimates.map((shard) => shard.peakPointsPerSecond),
        [150300, 150000],
      );
    });

    test('uses the scheduler two-second stagger cap for basic peaks', () {
      final plan = AutoProcessPlan.fromBasicConfig(
        startDeviceNumber: 1,
        endDeviceNumber: 2000,
        dataPointCount: 500,
        sendIntervalSeconds: 10,
      );

      expect(plan.steadyPointsPerSecond, 100000);
      expect(plan.peakPointsPerSecond, 500000);
      expect(plan.processCount, 2);
      expect(
        plan.shardEstimates.map((shard) => shard.peakPointsPerSecond),
        everyElement(250000),
      );
    });

    test('plans advanced mode from serialized group maps', () {
      final group = GroupConfig(
        startDeviceNumber: 1,
        endDeviceNumber: 2000,
        totalKeyCount: 500,
        changeRatio: 0.3,
        changeIntervalSeconds: 1,
        fullIntervalSeconds: 300,
      );
      final plan = AutoProcessPlan.fromConfig({
        'mode': 'advanced',
        'groups': [group.toJson()],
      });

      expect(plan.mode, AutoProcessPlanMode.advanced);
      expect(plan.peakPointsPerSecond, 800000);
      expect(plan.processCount, 3);
    });

    test('uses the bounded change stagger window for advanced peaks', () {
      final plan = AutoProcessPlan.fromAdvancedGroups([
        GroupConfig(
          startDeviceNumber: 1,
          endDeviceNumber: 1000,
          totalKeyCount: 500,
          changeRatio: 0.2,
          changeIntervalSeconds: 10,
          fullIntervalSeconds: 0,
        ),
      ]);

      expect(plan.steadyPointsPerSecond, 10000);
      expect(plan.changeBurstPointsPerSecond, 50000);
      expect(plan.fullBurstPointsPerSecond, 0);
      expect(plan.peakPointsPerSecond, 50000);
    });

    test('models a promoted 100% change stream without double counting', () {
      final plan = AutoProcessPlan.fromAdvancedGroups([
        GroupConfig(
          startDeviceNumber: 1,
          endDeviceNumber: 1000,
          totalKeyCount: 500,
          changeRatio: 1,
          changeIntervalSeconds: 1,
          fullIntervalSeconds: 300,
        ),
      ]);

      final group = plan.groupEstimates.single;
      expect(group.usesPromotedFullStream, isTrue);
      expect(group.changeStreamEnabled, isFalse);
      expect(plan.steadyPointsPerSecond, 500000);
      expect(plan.changeBurstPointsPerSecond, 0);
      expect(plan.fullBurstPointsPerSecond, 500000);
      expect(plan.peakPointsPerSecond, 500000);
      expect(plan.processCount, 2);
    });

    test('counts every TieNiu point in change reports', () {
      final plan = AutoProcessPlan.fromAdvancedGroups([
        GroupConfig(
          startDeviceNumber: 1,
          endDeviceNumber: 2000,
          totalKeyCount: 500,
          changeRatio: 0.3,
          changeIntervalSeconds: 1,
          fullIntervalSeconds: 300,
          format: 'tn',
        ),
      ]);

      expect(plan.changeBurstPointsPerSecond, 1000000);
      expect(plan.fullBurstPointsPerSecond, 500000);
      expect(plan.peakPointsPerSecond, 1500000);
      expect(plan.processCount, 5);
    });

    test('TieNiu empty change and full reports contribute no logical points',
        () {
      final plan = AutoProcessPlan.fromAdvancedGroups([
        GroupConfig(
          startDeviceNumber: 1,
          endDeviceNumber: 2000,
          totalKeyCount: 500,
          changeRatio: 0.3,
          changeIntervalSeconds: 1,
          fullIntervalSeconds: 300,
          format: 'tn-empty',
        ),
      ]);

      expect(plan.peakPointsPerSecond, 0);
      expect(plan.processCount, 1);
    });

    test('does not count a slower change stream that scheduler disables', () {
      final plan = AutoProcessPlan.fromAdvancedGroups([
        GroupConfig(
          startDeviceNumber: 1,
          endDeviceNumber: 1000,
          totalKeyCount: 500,
          changeRatio: 0.3,
          changeIntervalSeconds: 300,
          fullIntervalSeconds: 300,
        ),
      ]);

      expect(plan.groupEstimates.single.changeStreamEnabled, isFalse);
      expect(plan.steadyPointsPerSecond, 0);
      expect(plan.changeBurstPointsPerSecond, 0);
      expect(plan.fullBurstPointsPerSecond, 250000);
      expect(plan.peakPointsPerSecond, 250000);
    });

    test('sums simultaneous peaks conservatively across groups', () {
      final plan = AutoProcessPlan.fromAdvancedGroups([
        GroupConfig(
          name: 'A',
          startDeviceNumber: 1,
          endDeviceNumber: 1000,
          totalKeyCount: 200,
          changeRatio: 0.6,
          changeIntervalSeconds: 2,
          fullIntervalSeconds: 300,
        ),
        GroupConfig(
          name: 'B',
          startDeviceNumber: 5001,
          endDeviceNumber: 6000,
          totalKeyCount: 200,
          changeRatio: 0.6,
          changeIntervalSeconds: 2,
          fullIntervalSeconds: 300,
        ),
      ]);

      expect(plan.groupEstimates.map((group) => group.peakPointsPerSecond),
          [160000, 160000]);
      expect(plan.steadyPointsPerSecond, 120000);
      expect(plan.fullBurstPointsPerSecond, 200000);
      expect(plan.peakPointsPerSecond, 320000);
      expect(plan.processCount, 2);
      expect(
        plan.shardEstimates.map((shard) => shard.peakPointsPerSecond),
        [160000, 160000],
      );
    });

    test('uses a shorter full interval as the full burst window', () {
      final plan = AutoProcessPlan.fromAdvancedGroups([
        GroupConfig(
          startDeviceNumber: 1,
          endDeviceNumber: 1000,
          totalKeyCount: 200,
          changeRatio: 0,
          changeIntervalSeconds: 1,
          fullIntervalSeconds: 1,
        ),
      ]);

      expect(plan.steadyPointsPerSecond, 0);
      expect(plan.fullBurstPointsPerSecond, 200000);
      expect(plan.peakPointsPerSecond, 200000);
      expect(plan.processCount, 1);
    });

    test('caps shards and warns when one device exceeds the process limit', () {
      final plan = AutoProcessPlan.fromBasicConfig(
        startDeviceNumber: 7,
        endDeviceNumber: 7,
        dataPointCount: 600001,
        sendIntervalSeconds: 1,
      );

      expect(plan.requiredProcessCount, 3);
      expect(plan.maxUsefulProcessCount, 1);
      expect(plan.processCount, 1);
      expect(plan.canSatisfyLimitByDeviceSharding, isFalse);
      expect(plan.hasWarning, isTrue);
      expect(
        plan.warning,
        AutoProcessPlanWarning.singleDeviceLoadExceedsLimit,
      );
      expect(
        plan.reason,
        AutoProcessPlanReason.deviceShardingCannotMeetLimit,
      );
      expect(plan.shardEstimates.single.deviceCount, 1);
      expect(plan.shardEstimates.single.peakPointsPerSecond, 600001);
    });

    test('does not create empty shards for unsplittable advanced groups', () {
      final plan = AutoProcessPlan.fromAdvancedGroups(
        [
          GroupConfig(
            startDeviceNumber: 1,
            endDeviceNumber: 1,
            totalKeyCount: 200,
            changeRatio: 1,
            changeIntervalSeconds: 1,
            fullIntervalSeconds: 0,
          ),
          GroupConfig(
            startDeviceNumber: 10,
            endDeviceNumber: 10,
            totalKeyCount: 200,
            changeRatio: 1,
            changeIntervalSeconds: 1,
            fullIntervalSeconds: 0,
          ),
        ],
        pointLimitPerProcess: 300,
      );

      expect(plan.requiredProcessCount, 2);
      expect(plan.maxUsefulProcessCount, 1);
      expect(plan.processCount, 1);
      expect(plan.canSatisfyLimitByDeviceSharding, isFalse);
      expect(
        plan.warning,
        AutoProcessPlanWarning.shardDistributionExceedsLimit,
      );
    });

    test('returns at least one empty shard and display-safe values', () {
      final plan = AutoProcessPlan.fromAdvancedGroups(const []);

      expect(plan.processCount, 1);
      expect(plan.canSatisfyLimitByDeviceSharding, isTrue);
      expect(plan.peakPointsPerSecond, 0);
      expect(plan.peakPointsPerSecondForDisplay, 0);
      expect(plan.shardEstimates.single.label, '1/1');
      expect(plan.shardEstimates.single.deviceCount, 0);
    });

    test('rounds fractional rates up only for display and process planning',
        () {
      final plan = AutoProcessPlan.fromAdvancedGroups(
        [
          GroupConfig(
            startDeviceNumber: 1,
            endDeviceNumber: 1,
            totalKeyCount: 1,
            changeRatio: 1,
            changeIntervalSeconds: 3,
            fullIntervalSeconds: 0,
          ),
        ],
        pointLimitPerProcess: 1,
      );

      expect(plan.steadyPointsPerSecond, closeTo(1 / 3, 0.000001));
      expect(plan.steadyPointsPerSecondForDisplay, 1);
      expect(plan.processCount, 1);
    });

    test('rejects non-positive planning limits', () {
      expect(
        () => AutoProcessPlan.fromAdvancedGroups(
          const [],
          pointLimitPerProcess: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => AutoProcessPlan.fromAdvancedGroups(
          const [],
          fullBurstWindowSeconds: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
