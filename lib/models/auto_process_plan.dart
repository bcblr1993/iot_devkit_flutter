import 'dart:math' as math;

import 'group_config.dart';
import 'payload_format.dart';
import 'process_shard.dart';

enum AutoProcessPlanMode { basic, advanced }

/// Why an automatic process plan selected its process count.
enum AutoProcessPlanReason {
  singleProcessWithinLimit,
  peakPointsExceedLimit,
  deviceShardingCannotMeetLimit,
}

/// A machine-readable warning that the UI can localize for display.
enum AutoProcessPlanWarning {
  singleDeviceLoadExceedsLimit,
  shardDistributionExceedsLimit,
}

/// Estimated point load contributed by one advanced simulation group.
class GroupPointLoadEstimate {
  final String groupId;
  final String groupName;
  final int deviceCount;
  final int keysPerDevice;
  final int changePointsPerReport;
  final bool changeStreamEnabled;
  final bool fullStreamEnabled;

  /// True when the scheduler replaces both original streams with one full
  /// report stream running at the faster change interval.
  final bool usesPromotedFullStream;
  final double steadyPointsPerSecond;
  final double changeBurstPointsPerSecond;
  final double fullBurstPointsPerSecond;

  const GroupPointLoadEstimate({
    required this.groupId,
    required this.groupName,
    required this.deviceCount,
    required this.keysPerDevice,
    required this.changePointsPerReport,
    required this.changeStreamEnabled,
    required this.fullStreamEnabled,
    required this.usesPromotedFullStream,
    required this.steadyPointsPerSecond,
    required this.changeBurstPointsPerSecond,
    required this.fullBurstPointsPerSecond,
  });

  double get peakPointsPerSecond =>
      changeBurstPointsPerSecond + fullBurstPointsPerSecond;
}

/// Estimated load assigned to one application-process shard.
class ProcessPointLoadEstimate {
  /// Zero-based shard index. Use [label] for one-based display.
  final int shardIndex;
  final int shardCount;
  final int deviceCount;
  final double steadyPointsPerSecond;
  final double changeBurstPointsPerSecond;
  final double fullBurstPointsPerSecond;

  const ProcessPointLoadEstimate({
    required this.shardIndex,
    required this.shardCount,
    required this.deviceCount,
    required this.steadyPointsPerSecond,
    required this.changeBurstPointsPerSecond,
    required this.fullBurstPointsPerSecond,
  });

  String get label => '${shardIndex + 1}/$shardCount';

  double get peakPointsPerSecond =>
      changeBurstPointsPerSecond + fullBurstPointsPerSecond;

  /// Conservative integer values suitable for UI display.
  int get steadyPointsPerSecondForDisplay => steadyPointsPerSecond.ceil();
  int get peakPointsPerSecondForDisplay => peakPointsPerSecond.ceil();
}

/// A conservative automatic multi-process plan for one simulation run.
///
/// Advanced-mode reports use the same stream-selection rules as
/// `SchedulerService`: change reports are only scheduled when they are faster
/// than full reports, and a 100% faster change stream is promoted to one full
/// stream. Scheduled device reports are spread across at most
/// [fullBurstWindowSeconds]. A normal full burst is conservatively allowed to
/// overlap the change burst.
class AutoProcessPlan {
  static const int defaultPointLimitPerProcess = 300000;
  static const int defaultFullBurstWindowSeconds = 2;

  final AutoProcessPlanMode mode;
  final int pointLimitPerProcess;
  final int fullBurstWindowSeconds;

  /// Processes that should actually be launched.
  final int processCount;

  /// Ideal count from `ceil(total peak / process limit)`, before accounting
  /// for the fact that one simulated device cannot be split across processes.
  final int requiredProcessCount;

  /// Highest useful shard count for the current range layout.
  final int maxUsefulProcessCount;
  final double steadyPointsPerSecond;
  final double changeBurstPointsPerSecond;
  final double fullBurstPointsPerSecond;
  final double peakPointsPerSecond;
  final AutoProcessPlanReason reason;
  final AutoProcessPlanWarning? warning;
  final bool canSatisfyLimitByDeviceSharding;
  final List<GroupPointLoadEstimate> groupEstimates;
  final List<ProcessPointLoadEstimate> shardEstimates;

  const AutoProcessPlan._({
    required this.mode,
    required this.pointLimitPerProcess,
    required this.fullBurstWindowSeconds,
    required this.processCount,
    required this.requiredProcessCount,
    required this.maxUsefulProcessCount,
    required this.steadyPointsPerSecond,
    required this.changeBurstPointsPerSecond,
    required this.fullBurstPointsPerSecond,
    required this.peakPointsPerSecond,
    required this.reason,
    required this.warning,
    required this.canSatisfyLimitByDeviceSharding,
    required this.groupEstimates,
    required this.shardEstimates,
  });

  /// Builds a plan directly from the map passed to `MqttController.start`.
  factory AutoProcessPlan.fromConfig(
    Map<String, dynamic> config, {
    int pointLimitPerProcess = defaultPointLimitPerProcess,
    int fullBurstWindowSeconds = defaultFullBurstWindowSeconds,
  }) {
    final mode = (config['mode'] ?? 'basic').toString();
    if (mode == 'advanced') {
      final groups = <GroupConfig>[];
      final rawGroups = config['groups'];
      if (rawGroups is Iterable) {
        for (final rawGroup in rawGroups) {
          if (rawGroup is GroupConfig) {
            groups.add(rawGroup);
          } else if (rawGroup is Map) {
            groups.add(GroupConfig.fromJson(
              Map<String, dynamic>.from(rawGroup),
            ));
          }
        }
      }
      return AutoProcessPlan.fromAdvancedGroups(
        groups,
        pointLimitPerProcess: pointLimitPerProcess,
        fullBurstWindowSeconds: fullBurstWindowSeconds,
      );
    }
    if (mode != 'basic') {
      throw FormatException('Unsupported simulation mode: $mode');
    }

    final data = config['data'] is Map
        ? Map<String, dynamic>.from(config['data'] as Map)
        : const <String, dynamic>{};
    return AutoProcessPlan.fromBasicConfig(
      startDeviceNumber: _intValue(config['device_start_number'], 1),
      endDeviceNumber: _intValue(config['device_end_number'], 10),
      dataPointCount: _intValue(data['data_point_count'], 10),
      sendIntervalSeconds: _intValue(config['send_interval'], 1),
      pointLimitPerProcess: pointLimitPerProcess,
      fullBurstWindowSeconds: fullBurstWindowSeconds,
    );
  }

  /// Basic mode has one periodic stream. The scheduler spreads one reporting
  /// round across at most [fullBurstWindowSeconds], so capacity uses the
  /// shorter of the configured interval and that bounded stagger window.
  factory AutoProcessPlan.fromBasicConfig({
    required int startDeviceNumber,
    required int endDeviceNumber,
    required int dataPointCount,
    required int sendIntervalSeconds,
    int pointLimitPerProcess = defaultPointLimitPerProcess,
    int fullBurstWindowSeconds = defaultFullBurstWindowSeconds,
  }) {
    _validateLimits(pointLimitPerProcess, fullBurstWindowSeconds);

    final deviceCount = math.max(0, endDeviceNumber - startDeviceNumber + 1);
    final safeDataPointCount = math.max(0, dataPointCount);
    final perDeviceRate = sendIntervalSeconds > 0
        ? safeDataPointCount / sendIntervalSeconds
        : 0.0;
    final steadyPointsPerSecond = deviceCount * perDeviceRate;
    final burstWindow = sendIntervalSeconds > 0
        ? math.min(sendIntervalSeconds, fullBurstWindowSeconds)
        : 1;
    final perDevicePeakRate =
        sendIntervalSeconds > 0 ? safeDataPointCount / burstWindow : 0.0;
    final peakPointsPerSecond = deviceCount * perDevicePeakRate;

    return _finishPlan(
      mode: AutoProcessPlanMode.basic,
      pointLimitPerProcess: pointLimitPerProcess,
      fullBurstWindowSeconds: fullBurstWindowSeconds,
      steadyPointsPerSecond: steadyPointsPerSecond,
      changeBurstPointsPerSecond: peakPointsPerSecond,
      fullBurstPointsPerSecond: 0,
      maxUsefulProcessCount: math.max(1, deviceCount),
      hasSingleDeviceOverLimit: perDevicePeakRate > pointLimitPerProcess,
      groupEstimates: const [],
      buildShards: (processCount) => List.generate(processCount, (index) {
        final shard = ProcessShard(index: index, count: processCount);
        final shardDeviceCount =
            shard.slice(startDeviceNumber, endDeviceNumber).count;
        final shardSteadyRate = shardDeviceCount * perDeviceRate;
        final shardPeakRate = shardDeviceCount * perDevicePeakRate;
        return ProcessPointLoadEstimate(
          shardIndex: index,
          shardCount: processCount,
          deviceCount: shardDeviceCount,
          steadyPointsPerSecond: shardSteadyRate,
          changeBurstPointsPerSecond: shardPeakRate,
          fullBurstPointsPerSecond: 0,
        );
      }),
    );
  }

  factory AutoProcessPlan.fromAdvancedGroups(
    Iterable<GroupConfig> groups, {
    int pointLimitPerProcess = defaultPointLimitPerProcess,
    int fullBurstWindowSeconds = defaultFullBurstWindowSeconds,
  }) {
    _validateLimits(pointLimitPerProcess, fullBurstWindowSeconds);

    final groupList = List<GroupConfig>.unmodifiable(groups);
    final groupEstimates = List<GroupPointLoadEstimate>.unmodifiable(
      groupList.map(
        (group) => _estimateGroup(
          group,
          deviceCount: _deviceCount(group),
          burstWindowSeconds: fullBurstWindowSeconds,
        ),
      ),
    );
    final steadyPointsPerSecond = groupEstimates.fold<double>(
      0,
      (sum, estimate) => sum + estimate.steadyPointsPerSecond,
    );
    final changeBurstPointsPerSecond = groupEstimates.fold<double>(
      0,
      (sum, estimate) => sum + estimate.changeBurstPointsPerSecond,
    );
    final fullBurstPointsPerSecond = groupEstimates.fold<double>(
      0,
      (sum, estimate) => sum + estimate.fullBurstPointsPerSecond,
    );
    final maxGroupDeviceCount = groupEstimates.fold<int>(
      0,
      (currentMax, estimate) => math.max(currentMax, estimate.deviceCount),
    );
    final hasSingleDeviceOverLimit = groupEstimates.any(
      (estimate) =>
          estimate.deviceCount > 0 &&
          estimate.peakPointsPerSecond / estimate.deviceCount >
              pointLimitPerProcess,
    );

    return _finishPlan(
      mode: AutoProcessPlanMode.advanced,
      pointLimitPerProcess: pointLimitPerProcess,
      fullBurstWindowSeconds: fullBurstWindowSeconds,
      steadyPointsPerSecond: steadyPointsPerSecond,
      changeBurstPointsPerSecond: changeBurstPointsPerSecond,
      fullBurstPointsPerSecond: fullBurstPointsPerSecond,
      maxUsefulProcessCount: math.max(1, maxGroupDeviceCount),
      hasSingleDeviceOverLimit: hasSingleDeviceOverLimit,
      groupEstimates: groupEstimates,
      buildShards: (processCount) => List.generate(processCount, (index) {
        final shard = ProcessShard(index: index, count: processCount);
        var deviceCount = 0;
        var steadyRate = 0.0;
        var changeBurstRate = 0.0;
        var fullBurstRate = 0.0;

        for (final group in groupList) {
          final range = shard.slice(
            group.startDeviceNumber,
            group.endDeviceNumber,
          );
          final estimate = _estimateGroup(
            group,
            deviceCount: range.count,
            burstWindowSeconds: fullBurstWindowSeconds,
          );
          deviceCount += range.count;
          steadyRate += estimate.steadyPointsPerSecond;
          changeBurstRate += estimate.changeBurstPointsPerSecond;
          fullBurstRate += estimate.fullBurstPointsPerSecond;
        }

        return ProcessPointLoadEstimate(
          shardIndex: index,
          shardCount: processCount,
          deviceCount: deviceCount,
          steadyPointsPerSecond: steadyRate,
          changeBurstPointsPerSecond: changeBurstRate,
          fullBurstPointsPerSecond: fullBurstRate,
        );
      }),
    );
  }

  bool get requiresMultipleProcesses => processCount > 1;
  bool get hasWarning => warning != null;

  /// Conservative integer values suitable for UI display.
  int get steadyPointsPerSecondForDisplay => steadyPointsPerSecond.ceil();
  int get changeBurstPointsPerSecondForDisplay =>
      changeBurstPointsPerSecond.ceil();
  int get fullBurstPointsPerSecondForDisplay => fullBurstPointsPerSecond.ceil();
  int get peakPointsPerSecondForDisplay => peakPointsPerSecond.ceil();

  static AutoProcessPlan _finishPlan({
    required AutoProcessPlanMode mode,
    required int pointLimitPerProcess,
    required int fullBurstWindowSeconds,
    required double steadyPointsPerSecond,
    required double changeBurstPointsPerSecond,
    required double fullBurstPointsPerSecond,
    required int maxUsefulProcessCount,
    required bool hasSingleDeviceOverLimit,
    required List<GroupPointLoadEstimate> groupEstimates,
    required List<ProcessPointLoadEstimate> Function(int processCount)
        buildShards,
  }) {
    final peakPointsPerSecond =
        changeBurstPointsPerSecond + fullBurstPointsPerSecond;
    final requiredProcessCount = math.max(
      1,
      (peakPointsPerSecond / pointLimitPerProcess).ceil(),
    );
    var processCount = math.min(requiredProcessCount, maxUsefulProcessCount);
    var shardEstimates = buildShards(processCount);

    // Remainders from several groups all go to the earliest shard. If that
    // makes the theoretical count insufficient, add useful shards until the
    // real range split meets the limit or individual devices cannot be split.
    while (!_allShardsWithinLimit(shardEstimates, pointLimitPerProcess) &&
        processCount < maxUsefulProcessCount) {
      processCount++;
      shardEstimates = buildShards(processCount);
    }

    final canSatisfyLimit =
        _allShardsWithinLimit(shardEstimates, pointLimitPerProcess);
    final warning = canSatisfyLimit
        ? null
        : hasSingleDeviceOverLimit
            ? AutoProcessPlanWarning.singleDeviceLoadExceedsLimit
            : AutoProcessPlanWarning.shardDistributionExceedsLimit;
    final reason = !canSatisfyLimit
        ? AutoProcessPlanReason.deviceShardingCannotMeetLimit
        : processCount == 1
            ? AutoProcessPlanReason.singleProcessWithinLimit
            : AutoProcessPlanReason.peakPointsExceedLimit;

    return AutoProcessPlan._(
      mode: mode,
      pointLimitPerProcess: pointLimitPerProcess,
      fullBurstWindowSeconds: fullBurstWindowSeconds,
      processCount: processCount,
      requiredProcessCount: requiredProcessCount,
      maxUsefulProcessCount: maxUsefulProcessCount,
      steadyPointsPerSecond: steadyPointsPerSecond,
      changeBurstPointsPerSecond: changeBurstPointsPerSecond,
      fullBurstPointsPerSecond: fullBurstPointsPerSecond,
      peakPointsPerSecond: peakPointsPerSecond,
      reason: reason,
      warning: warning,
      canSatisfyLimitByDeviceSharding: canSatisfyLimit,
      groupEstimates: List.unmodifiable(groupEstimates),
      shardEstimates: List.unmodifiable(shardEstimates),
    );
  }

  static bool _allShardsWithinLimit(
    Iterable<ProcessPointLoadEstimate> shards,
    int pointLimitPerProcess,
  ) =>
      shards.every(
        (shard) => shard.peakPointsPerSecond <= pointLimitPerProcess,
      );

  static GroupPointLoadEstimate _estimateGroup(
    GroupConfig group, {
    required int deviceCount,
    required int burstWindowSeconds,
  }) {
    final keysPerDevice = math.max(0, group.totalKeyCount);
    final changeRatio =
        group.changeRatio.isFinite ? group.changeRatio.clamp(0.0, 1.0) : 0.0;
    final normalizedFormat = PayloadFormat.normalize(group.format);
    final changePointsPerReport = switch (normalizedFormat) {
      PayloadFormat.tieNiu => keysPerDevice,
      PayloadFormat.tieNiuEmpty => 0,
      _ => (keysPerDevice * changeRatio).floor(),
    };
    final fullPointsPerReport =
        normalizedFormat == PayloadFormat.tieNiuEmpty ? 0 : keysPerDevice;
    final fullStreamEnabled = group.fullIntervalSeconds > 0;
    final validChangeInterval = group.changeIntervalSeconds > 0;
    final usesPromotedFullStream = fullStreamEnabled &&
        validChangeInterval &&
        changeRatio >= 1.0 &&
        group.changeIntervalSeconds < group.fullIntervalSeconds;
    final changeStreamEnabled = !usesPromotedFullStream &&
        validChangeInterval &&
        changeRatio > 0 &&
        (!fullStreamEnabled ||
            group.changeIntervalSeconds < group.fullIntervalSeconds);

    var steadyPointsPerSecond = 0.0;
    var changeBurstPointsPerSecond = 0.0;
    if (usesPromotedFullStream) {
      steadyPointsPerSecond =
          deviceCount * fullPointsPerReport / group.changeIntervalSeconds;
    } else if (changeStreamEnabled) {
      steadyPointsPerSecond =
          deviceCount * changePointsPerReport / group.changeIntervalSeconds;
      final changeWindow =
          math.min(group.changeIntervalSeconds, burstWindowSeconds);
      changeBurstPointsPerSecond =
          deviceCount * changePointsPerReport / changeWindow;
    }

    var fullBurstPointsPerSecond = 0.0;
    if (fullStreamEnabled) {
      final effectiveFullInterval = usesPromotedFullStream
          ? group.changeIntervalSeconds
          : group.fullIntervalSeconds;
      final fullWindow = math.min(effectiveFullInterval, burstWindowSeconds);
      fullBurstPointsPerSecond = deviceCount * fullPointsPerReport / fullWindow;
    }

    return GroupPointLoadEstimate(
      groupId: group.id,
      groupName: group.name,
      deviceCount: deviceCount,
      keysPerDevice: keysPerDevice,
      changePointsPerReport: changePointsPerReport,
      changeStreamEnabled: changeStreamEnabled,
      fullStreamEnabled: fullStreamEnabled,
      usesPromotedFullStream: usesPromotedFullStream,
      steadyPointsPerSecond: steadyPointsPerSecond,
      changeBurstPointsPerSecond: changeBurstPointsPerSecond,
      fullBurstPointsPerSecond: fullBurstPointsPerSecond,
    );
  }

  static void _validateLimits(
    int pointLimitPerProcess,
    int fullBurstWindowSeconds,
  ) {
    if (pointLimitPerProcess <= 0) {
      throw ArgumentError.value(
        pointLimitPerProcess,
        'pointLimitPerProcess',
        'must be greater than zero',
      );
    }
    if (fullBurstWindowSeconds <= 0) {
      throw ArgumentError.value(
        fullBurstWindowSeconds,
        'fullBurstWindowSeconds',
        'must be greater than zero',
      );
    }
  }

  static int _intValue(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _deviceCount(GroupConfig group) =>
      math.max(0, group.endDeviceNumber - group.startDeviceNumber + 1);
}
