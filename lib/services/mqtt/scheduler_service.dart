import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:typed_data/typed_buffers.dart';
import '../../services/data_generator.dart';
import '../../utils/statistics_collector.dart';
import '../../models/group_config.dart';
import '../../models/custom_key_config.dart';
import '../../models/payload_format.dart';
import '../../utils/isolate_worker.dart';
import '../../models/simulation_context.dart';

class ScheduleDecision {
  final int sendCount;
  final int delayMs;
  final int skippedCount;

  const ScheduleDecision({
    required this.sendCount,
    required this.delayMs,
    this.skippedCount = 0,
  });

  bool get droppedLateTicks => skippedCount > 0;
}

/// Returns whether one change-report tick is the closest change target to a
/// full-report target for the same device.
///
/// Each full target maps to exactly one non-negative change tick. Ties choose
/// the earlier change tick. This works even when the full and change grids have
/// different phase offsets or non-divisible intervals.
@visibleForTesting
bool shouldSkipChangeTickCoveredByFull({
  required int alignedStartTime,
  required int changePhaseOffset,
  required int changeIntervalMs,
  required int changeSendCount,
  required int fullPhaseOffset,
  required int fullIntervalMs,
}) {
  return fullTargetCoveredByChangeTick(
        alignedStartTime: alignedStartTime,
        changePhaseOffset: changePhaseOffset,
        changeIntervalMs: changeIntervalMs,
        changeSendCount: changeSendCount,
        fullPhaseOffset: fullPhaseOffset,
        fullIntervalMs: fullIntervalMs,
      ) !=
      null;
}

/// Returns the full-report target covered by this change tick, if any.
/// Callers can use the target to verify that the full report actually
/// published before suppressing a redundant change report.
@visibleForTesting
int? fullTargetCoveredByChangeTick({
  required int alignedStartTime,
  required int changePhaseOffset,
  required int changeIntervalMs,
  required int changeSendCount,
  required int fullPhaseOffset,
  required int fullIntervalMs,
}) {
  if (changeIntervalMs <= 0 || fullIntervalMs <= 0 || changeSendCount < 0) {
    return null;
  }

  final changeBaseTarget = alignedStartTime + changePhaseOffset;
  final fullBaseTarget = alignedStartTime + fullPhaseOffset;
  final changeTarget = changeBaseTarget + (changeSendCount * changeIntervalMs);
  final relativeToFullBase = changeTarget - fullBaseTarget;
  final lowerFullIndex = _floorDivide(relativeToFullBase, fullIntervalMs);

  int? coveredTargetForIndex(int fullIndex) {
    final fullTarget = fullBaseTarget + (fullIndex * fullIntervalMs);
    final nearestChangeIndex = _nearestNonNegativeTick(
        fullTarget - changeBaseTarget, changeIntervalMs);
    return nearestChangeIndex == changeSendCount ? fullTarget : null;
  }

  // Avoid allocating a Set for every device on every change tick. Usually the
  // two adjacent non-negative full ticks are the only candidates; before the
  // first full tick, the original behavior falls back to index 0.
  if (lowerFullIndex >= 0) {
    final target = coveredTargetForIndex(lowerFullIndex);
    if (target != null) return target;
  }
  final upperFullIndex = lowerFullIndex + 1;
  if (upperFullIndex >= 0) {
    final target = coveredTargetForIndex(upperFullIndex);
    if (target != null) return target;
  }
  if (upperFullIndex < 0) return coveredTargetForIndex(0);
  return null;
}

@visibleForTesting
bool shouldSuppressChangeAfterFull({
  required int? coveredFullTarget,
  required int changeTarget,
  required int? lastSuccessfulFullTarget,
}) {
  return coveredFullTarget != null &&
      coveredFullTarget <= changeTarget &&
      lastSuccessfulFullTarget == coveredFullTarget;
}

int _floorDivide(int value, int positiveDivisor) {
  final quotient = value ~/ positiveDivisor;
  if (value < 0 && value % positiveDivisor != 0) {
    return quotient - 1;
  }
  return quotient;
}

int _nearestNonNegativeTick(int distanceFromBase, int intervalMs) {
  if (distanceFromBase <= 0) return 0;
  final lower = distanceFromBase ~/ intervalMs;
  final remainder = distanceFromBase % intervalMs;
  // Strictly closer chooses the later tick; an exact tie stays on [lower].
  return remainder > intervalMs - remainder ? lower + 1 : lower;
}

class SchedulerService {
  final StatisticsCollector statisticsCollector;
  final Function(String message, String type, {String? tag}) onLog;

  int _alignedStartTime = 0;
  final Map<String, List<Timer>> _clientTimers = {};
  final Map<String, int> _clientVersions = {};
  final Map<String, int> _lastSuccessfulFullTarget = {};

  // Performance Mode: Disable logs to save CPU
  bool enableLogs = true;

  SchedulerService({
    required this.statisticsCollector,
    required this.onLog,
  });

  @visibleForTesting
  ScheduleDecision computeNextScheduleForTest({
    required int nowMs,
    required int alignedStartTime,
    required int phaseOffset,
    required int intervalMs,
    required int sendCount,
  }) {
    return _computeNextSchedule(
      nowMs: nowMs,
      alignedStartTime: alignedStartTime,
      phaseOffset: phaseOffset,
      intervalMs: intervalMs,
      sendCount: sendCount,
    );
  }

  @visibleForTesting
  void registerTimerBucketForTest(String clientId) {
    _clientTimers[clientId] = [];
  }

  @visibleForTesting
  void addTimerForTest(String clientId, Timer timer) {
    _addTimer(clientId, timer);
  }

  @visibleForTesting
  int timerCountForTest(String clientId) {
    return _clientTimers[clientId]?.length ?? 0;
  }

  void reset() {
    _alignedStartTime = DateTime.now().millisecondsSinceEpoch + 200;
  }

  void stopAll() {
    for (var timers in _clientTimers.values) {
      _cancelTimers(timers);
    }
    _clientTimers.clear();
    _lastSuccessfulFullTarget.clear();
  }

  void stopPublishing(String clientId) {
    final timers = _clientTimers.remove(clientId);
    if (timers != null) {
      _cancelTimers(timers);
    }
    _lastSuccessfulFullTarget.remove(clientId);
  }

  void startPublishing(
      MqttServerClient client, String clientId, SimulationContext context) {
    // CRITICAL FIX: Ensure any existing scheduling chain for this client is stopped before starting a new one.
    // This prevents "Double Timers" if onConnected is triggered multiple times or race conditions occur.
    if (_clientTimers.containsKey(clientId)) {
      onLog(
          'Restarting scheduler for $clientId (cleaning up cleaning previous timers)',
          'warning');
      stopPublishing(clientId);
    }

    // STRICT FIX: Initialize list BEFORE starting.
    // _addTimer now requires this list to exist.
    _clientTimers[clientId] = [];
    _lastSuccessfulFullTarget.remove(clientId);

    // VERSIONING: Increment session version. Zombies from old sessions will fail the version check.
    int currentVersion = (_clientVersions[clientId] ?? 0) + 1;
    _clientVersions[clientId] = currentVersion;

    if (context is BasicSimulationContext) {
      _startBasicPublishing(client, clientId, context, currentVersion);
    } else if (context is AdvancedSimulationContext) {
      _startAdvancedPublishing(client, clientId, context, currentVersion);
    }
  }

  // --- Basic Mode Logic ---
  void _startBasicPublishing(MqttServerClient client, String clientId,
      BasicSimulationContext context, int version) {
    int intervalMs = _intervalMsFromSeconds(context.intervalSeconds);

    // STAGGER LOGIC:
    // Distribute load across a bounded window to prevent "Thundering Herd"
    // (CPU spikes) while keeping devices reporting near-simultaneously.
    int phaseOffset = _staggerOffset(clientId, intervalMs);

    // Initial Delay
    int now = DateTime.now().millisecondsSinceEpoch;

    // Target = GridStart + Stagger + (Count * Interval)
    // We want the FIRST target where (Target > Now) or just (Target corresponding to Count=0)
    int baseTarget = _alignedStartTime + phaseOffset;
    int initialDelay = baseTarget - now;

    // STRICT FIX: Resume logic
    int sendCount = 0;
    if (initialDelay < 0) {
      // We are past base target.
      // Calculate how many intervals have passed.
      int elapsed = now - baseTarget;
      sendCount = (elapsed ~/ intervalMs) + 1; // Aim for NEXT slot

      // Recalculate delay for the next slot
      int nextTarget = baseTarget + (sendCount * intervalMs);
      initialDelay = nextTarget - now;
    }

    Timer timer = Timer(Duration(milliseconds: initialDelay), () {
      _scheduleNextBasicPublish(client, clientId, context, intervalMs,
          sendCount, version, phaseOffset);
    });
    _addTimer(clientId, timer);
  }

  void _scheduleNextBasicPublish(
    MqttServerClient client,
    String clientId,
    BasicSimulationContext context,
    int intervalMs,
    int sendCount,
    int version,
    int phaseOffset,
  ) {
    if (!_clientTimers.containsKey(clientId)) return; // Stopped
    if (_clientVersions[clientId] != version) return; // Wrong Session

    final String topic = context.topic;
    final String format = context.format;
    final int dataPointCount = context.dataPointCount;
    final List<CustomKeyConfig> customKeys = context.customKeys;

    // 1. Generate Payload
    // Timestamp aligned with the staggered time
    int payloadTimestamp =
        _alignedStartTime + phaseOffset + (sendCount * intervalMs);
    Object payloadObj;

    if (format == PayloadFormat.tieNiu) {
      payloadObj = DataGenerator.generateTnPayload(dataPointCount,
          timestamp: payloadTimestamp);
    } else if (format == PayloadFormat.tieNiuEmpty) {
      payloadObj =
          DataGenerator.generateTnEmptyPayload(timestamp: payloadTimestamp);
    } else {
      final values = DataGenerator.generateBatteryStatus(dataPointCount,
          clientId: clientId, customKeys: customKeys);
      payloadObj =
          PayloadFormat.buildStandard(values, payloadTimestamp, format);
    }

    String payload = jsonEncode(payloadObj);
    _publish(
      client,
      topic,
      payload,
      clientId,
      'success',
      'Sent message #$sendCount',
      pointCount: format == PayloadFormat.tieNiuEmpty ? 0 : dataPointCount,
      logTagOverride: clientId,
      qos: _intToQos(context.qos),
    );

    // 2. Schedule Next
    sendCount++;
    _scheduleNext(clientId, intervalMs, sendCount, version, phaseOffset,
        (actualCount) {
      _scheduleNextBasicPublish(client, clientId, context, intervalMs,
          actualCount, version, phaseOffset);
    });
  }

  // --- Advanced Mode Logic ---
  // --- Advanced Mode Logic ---
  void _startAdvancedPublishing(MqttServerClient client, String clientId,
      AdvancedSimulationContext context, int version) {
    final GroupConfig group = context.group;
    final String topic = context.topic;

    int now = DateTime.now().millisecondsSinceEpoch;

    // A full interval of 0 disables the full report entirely; only change
    // reports are emitted (if a change ratio is configured).
    final bool fullEnabled = group.fullIntervalSeconds > 0;

    // OPTIMIZATION:
    // If ChangeRatio is 100% (or more), then "Change Report" is identical to "Full Report".
    // If the Change Frequency is higher (interval smaller) than Full Frequency,
    // we should just run the Full Report at that higher frequency and disable the redundant slower timer.
    // Only meaningful when full reporting is enabled.
    bool runFullAtChangeSpeed = fullEnabled &&
        (group.changeRatio >= 1.0) &&
        (group.changeIntervalSeconds < group.fullIntervalSeconds);

    // 1. Full Report Setup (skipped when full reporting is disabled).
    if (fullEnabled) {
      // If optimization active, use change interval. Else use full interval.
      int effectiveFullIntervalMs = runFullAtChangeSpeed
          ? _intervalMsFromSeconds(group.changeIntervalSeconds)
          : _intervalMsFromSeconds(group.fullIntervalSeconds);

      int fullPhaseOffset = _staggerOffset(clientId, effectiveFullIntervalMs);

      int fullBaseTarget = _alignedStartTime + fullPhaseOffset;
      int fullDelay = fullBaseTarget - now;
      int fullSendCount = 0;

      if (fullDelay < 0) {
        int elapsed = now - fullBaseTarget;
        fullSendCount = (elapsed ~/ effectiveFullIntervalMs) + 1;
        fullDelay =
            (fullBaseTarget + (fullSendCount * effectiveFullIntervalMs)) - now;
      }

      Timer fullTimer = Timer(Duration(milliseconds: fullDelay), () {
        _scheduleFullReport(
            client,
            clientId,
            topic,
            group,
            effectiveFullIntervalMs,
            fullSendCount,
            version,
            context.qos,
            fullPhaseOffset);
      });
      _addTimer(clientId, fullTimer);
    }

    // 2. Change Report Setup
    // Emit change reports when a change ratio is configured and we haven't
    // already promoted them to the full report above. When full reporting is
    // enabled, only run change reports if they are FASTER than the full cadence
    // (otherwise the full report already covers them). When full is disabled,
    // change reports run on their own cadence, unaffected by the full setting.
    final bool changeEnabled = !runFullAtChangeSpeed &&
        group.changeRatio > 0 &&
        (!fullEnabled ||
            group.changeIntervalSeconds < group.fullIntervalSeconds);

    if (changeEnabled) {
      int changeIntervalMs =
          _intervalMsFromSeconds(group.changeIntervalSeconds);
      int changePhaseOffset =
          _staggerOffset(clientId, changeIntervalMs, salt: 12345);

      int changeBaseTarget = _alignedStartTime + changePhaseOffset;
      int changeDelay = changeBaseTarget - now;
      int changeSendCount = 0;

      if (changeDelay < 0) {
        int elapsed = now - changeBaseTarget;
        changeSendCount = (elapsed ~/ changeIntervalMs) + 1;
        changeDelay =
            (changeBaseTarget + (changeSendCount * changeIntervalMs)) - now;
      }

      Timer changeTimer = Timer(Duration(milliseconds: changeDelay), () {
        _scheduleChangeReport(client, clientId, topic, group, changeIntervalMs,
            changeSendCount, version, context.qos, changePhaseOffset);
      });
      _addTimer(clientId, changeTimer);
    }
  }

  Future<void> _scheduleFullReport(
    MqttServerClient client,
    String clientId,
    String topic,
    GroupConfig group,
    int intervalMs,
    int sendCount,
    int version,
    int qos,
    int phaseOffset,
  ) async {
    if (!_clientTimers.containsKey(clientId)) return;
    if (_clientVersions[clientId] != version) return; // Wrong Session

    int payloadTimestamp =
        _alignedStartTime + phaseOffset + (sendCount * intervalMs);
    Uint8Buffer payload;

    // Standard Format
    // OPTIMIZATION: Always use Persistent Isolate Worker to offload serialization.
    // This is crucial for high concurrency (e.g. 200 devices * 100 points) where
    // the aggregate main-thread cost of 200 JSON encodes causes lag.

    // 1. Prepare State (Main Thread)
    int key1 = DataGenerator.getKey1Value(clientId);
    Map<String, dynamic> customValues =
        DataGenerator.generateCustomKeys(group.customKeys);

    // 2. Offload work to Persistent Isolate
    try {
      payload =
          await PersistentIsolateManager.instance.computeBytesTask(WorkerInput(
        count: group.totalKeyCount,
        clientId: clientId,
        timestamp: payloadTimestamp,
        key1Value: key1,
        customKeyValues: customValues,
        format: PayloadFormat.normalize(group.format),
      ));
    } catch (e) {
      statisticsCollector.incrementGenerationError();
      onLog('Isolate Error: $e', 'error', tag: clientId);
      final nextSendCount = sendCount + 1;
      _scheduleNext(clientId, intervalMs, nextSendCount, version, phaseOffset,
          (actualCount) {
        _scheduleFullReport(client, clientId, topic, group, intervalMs,
            actualCount, version, qos, phaseOffset);
      });
      return;
    }

    // Check cancellation again after await
    if (!_clientTimers.containsKey(clientId)) return;
    if (_clientVersions[clientId] != version) return;

    final published = _publishBytes(
      client,
      topic,
      payload,
      group.name,
      'success',
      enableLogs ? '[$clientId] Full Report #$sendCount' : '',
      pointCount:
          PayloadFormat.normalize(group.format) == PayloadFormat.tieNiuEmpty
              ? 0
              : group.totalKeyCount,
      qos: _intToQos(qos),
    );
    if (published) {
      _lastSuccessfulFullTarget[clientId] = payloadTimestamp;
    }

    sendCount++;
    _scheduleNext(clientId, intervalMs, sendCount, version, phaseOffset,
        (actualCount) {
      _scheduleFullReport(client, clientId, topic, group, intervalMs,
          actualCount, version, qos, phaseOffset);
    });
  }

  Future<void> _scheduleChangeReport(
    MqttServerClient client,
    String clientId,
    String topic,
    GroupConfig group,
    int intervalMs,
    int sendCount,
    int version,
    int qos,
    int phaseOffset,
  ) async {
    if (!_clientTimers.containsKey(clientId)) return;
    if (_clientVersions[clientId] != version) return; // Wrong Session

    int payloadTimestamp =
        _alignedStartTime + phaseOffset + (sendCount * intervalMs);

    // A full report covers one nearby change tick. The full and change streams
    // intentionally use different stagger grids, so exact timestamp equality
    // cannot be used here. Map each full target to its nearest change target
    // instead. Suppression happens only when that full report has already
    // published successfully; otherwise the change report remains a fallback.
    if (group.fullIntervalSeconds > 0) {
      final fullIntervalMs = _intervalMsFromSeconds(group.fullIntervalSeconds);
      final fullPhaseOffset = _staggerOffset(clientId, fullIntervalMs);
      final coveredFullTarget = fullTargetCoveredByChangeTick(
        alignedStartTime: _alignedStartTime,
        changePhaseOffset: phaseOffset,
        changeIntervalMs: intervalMs,
        changeSendCount: sendCount,
        fullPhaseOffset: fullPhaseOffset,
        fullIntervalMs: fullIntervalMs,
      );
      if (shouldSuppressChangeAfterFull(
        coveredFullTarget: coveredFullTarget,
        changeTarget: payloadTimestamp,
        lastSuccessfulFullTarget: _lastSuccessfulFullTarget[clientId],
      )) {
        // Suppress only after the corresponding full report really published.
        // If it is still in flight or failed, send this change report instead.
        sendCount++;
        _scheduleNext(clientId, intervalMs, sendCount, version, phaseOffset,
            (actualCount) {
          _scheduleChangeReport(client, clientId, topic, group, intervalMs,
              actualCount, version, qos, phaseOffset);
        });
        return;
      }
    }

    // OPTIMIZATION: Use Persistent Isolate
    int totalChangeCount = (group.totalKeyCount * group.changeRatio).floor();

    String? payload;
    Uint8Buffer? payloadBytes;
    int publishedPointCount;

    // TN Formats (Usually tiny, keep main thread for now, or TODO migrate)
    if (group.format == 'tn') {
      Map<String, dynamic> data = DataGenerator.generateTnPayload(
          group.totalKeyCount,
          timestamp: payloadTimestamp);
      payload = jsonEncode(data);
      publishedPointCount = group.totalKeyCount;
    } else if (group.format == 'tn-empty') {
      Map<String, dynamic> data =
          DataGenerator.generateTnEmptyPayload(timestamp: payloadTimestamp);
      payload = jsonEncode(data);
      publishedPointCount = 0;
    } else {
      publishedPointCount = totalChangeCount;
      // Standard Format
      // Standard Format
      // OPTIMIZATION: Always use Persistent Isolate Worker
      if (true) {
        // 1. Prepare State (Main Thread)
        int key1 = DataGenerator.getKey1Value(clientId);
        Map<String, dynamic> customValues =
            DataGenerator.generateCustomKeys(group.customKeys);

        try {
          payloadBytes = await PersistentIsolateManager.instance
              .computeBytesTask(WorkerInput(
            count: totalChangeCount,
            clientId: clientId,
            timestamp: payloadTimestamp,
            key1Value: key1,
            customKeyValues: customValues,
            format: PayloadFormat.normalize(group.format),
            totalKeyCount: group.totalKeyCount,
            randomKeys: group.randomChange,
          ));
        } catch (e) {
          statisticsCollector.incrementGenerationError();
          onLog('Isolate Error (Change): $e', 'error', tag: clientId);
          final nextSendCount = sendCount + 1;
          _scheduleNext(
              clientId, intervalMs, nextSendCount, version, phaseOffset,
              (actualCount) {
            _scheduleChangeReport(client, clientId, topic, group, intervalMs,
                actualCount, version, qos, phaseOffset);
          });
          return;
        }
      }
    }

    // Check cancellation again
    if (!_clientTimers.containsKey(clientId)) return;
    if (_clientVersions[clientId] != version) return;

    // Use info type for change reports
    // Calculate length logic: if using isolate, payload is string.
    // We can't easy get keys count without parsing, so we just say "Change Report"
    final msg = enableLogs
        ? '[$clientId] Change Report #$sendCount (~$totalChangeCount keys)'
        : '';

    if (payloadBytes != null) {
      _publishBytes(
        client,
        topic,
        payloadBytes,
        group.name,
        'info',
        msg,
        pointCount: publishedPointCount,
        qos: _intToQos(qos),
      );
    } else {
      _publish(
        client,
        topic,
        payload!,
        group.name,
        'info',
        msg,
        pointCount: publishedPointCount,
        qos: _intToQos(qos),
      );
    }

    sendCount++;
    _scheduleNext(clientId, intervalMs, sendCount, version, phaseOffset,
        (actualCount) {
      _scheduleChangeReport(client, clientId, topic, group, intervalMs,
          actualCount, version, qos, phaseOffset);
    });
  }

  // --- UNIFIED REPORTING (v1.2.25) ---
  // Runs at Change Speed. Decides on every tick whether to send FULL or CHANGE.
  // ignore: unused_element
  Future<void> _scheduleUnifiedReport(
    MqttServerClient client,
    String clientId,
    String topic,
    GroupConfig group,
    int intervalMs, // This is the Change Interval (Fast)
    int fullIntervalMs, // This is the Full Interval (Slow)
    int sendCount,
    int version,
    int qos,
    int phaseOffset,
  ) async {
    if (!_clientTimers.containsKey(clientId)) return;
    if (_clientVersions[clientId] != version) return;

    int payloadTimestamp =
        _alignedStartTime + phaseOffset + (sendCount * intervalMs);

    // Decision Logic:
    // We are on tick #sendCount of the Fast Interval.
    // Elapsed Time = sendCount * FastInterval
    // Is this a multiple of SlowInterval?
    // Note: We need to check relative to proper alignment.
    // Since we aligned 'phaseOffset' based on FastInterval, and SlowInterval % FastInterval == 0,
    // The timestamp strictly aligns.
    // Collision Check:
    int elapsedTime = sendCount * intervalMs;
    bool isFullReportTime = (elapsedTime % fullIntervalMs == 0);

    // NOTE: 'sendCount' counts 0, 1, 2...
    // At count 0 (t=0), elapsed=0 => isFullReportTime = true. Correct.

    Uint8Buffer payload;
    String typeTag = isFullReportTime ? 'success' : 'info';
    String logMsg;
    int pointCount;

    if (isFullReportTime) {
      // --- GENERATE FULL REPORT ---
      int key1 = DataGenerator.getKey1Value(clientId);
      Map<String, dynamic> customValues =
          DataGenerator.generateCustomKeys(group.customKeys);

      try {
        payload = await PersistentIsolateManager.instance
            .computeBytesTask(WorkerInput(
          count: group.totalKeyCount,
          clientId: clientId,
          timestamp: payloadTimestamp,
          key1Value: key1,
          customKeyValues: customValues,
        ));
      } catch (e) {
        statisticsCollector.incrementGenerationError();
        onLog('Isolate Error (Unified Full): $e', 'error', tag: clientId);
        final nextSendCount = sendCount + 1;
        _scheduleNext(clientId, intervalMs, nextSendCount, version, phaseOffset,
            (actualCount) {
          _scheduleUnifiedReport(client, clientId, topic, group, intervalMs,
              fullIntervalMs, actualCount, version, qos, phaseOffset);
        });
        return;
      }
      logMsg = '[$clientId] Full Report #$sendCount';
      pointCount = group.totalKeyCount;
    } else {
      // --- GENERATE CHANGE REPORT ---
      int totalChangeCount = (group.totalKeyCount * group.changeRatio).floor();

      // Use Isolate
      int key1 = DataGenerator.getKey1Value(clientId);
      Map<String, dynamic> customValues =
          DataGenerator.generateCustomKeys(group.customKeys);

      try {
        payload = await PersistentIsolateManager.instance
            .computeBytesTask(WorkerInput(
          count: totalChangeCount,
          clientId: clientId,
          timestamp: payloadTimestamp,
          key1Value: key1,
          customKeyValues: customValues,
        ));
      } catch (e) {
        statisticsCollector.incrementGenerationError();
        onLog('Isolate Error (Unified Change): $e', 'error', tag: clientId);
        final nextSendCount = sendCount + 1;
        _scheduleNext(clientId, intervalMs, nextSendCount, version, phaseOffset,
            (actualCount) {
          _scheduleUnifiedReport(client, clientId, topic, group, intervalMs,
              fullIntervalMs, actualCount, version, qos, phaseOffset);
        });
        return;
      }
      logMsg =
          '[$clientId] Change Report #$sendCount (~$totalChangeCount keys)';
      pointCount = totalChangeCount;
    }

    if (!_clientTimers.containsKey(clientId)) return;
    if (_clientVersions[clientId] != version) return;

    _publishBytes(
      client,
      topic,
      payload,
      group.name,
      typeTag,
      logMsg,
      pointCount: pointCount,
      qos: _intToQos(qos),
    );

    sendCount++;
    _scheduleNext(clientId, intervalMs, sendCount, version, phaseOffset,
        (actualCount) {
      _scheduleUnifiedReport(client, clientId, topic, group, intervalMs,
          fullIntervalMs, actualCount, version, qos, phaseOffset);
    });
  }

  // --- Helper Methods ---

  bool _publish(
    MqttServerClient client,
    String topic,
    String payload,
    String tag,
    String successType,
    String successMsg, {
    required int pointCount,
    String? logTagOverride,
    MqttQos qos = MqttQos.atMostOnce,
  }) {
    final builder = MqttClientPayloadBuilder();
    // MQTT payloads are bytes. addString uses the package's UTF-16-oriented
    // legacy behavior and corrupts non-ASCII JSON; use explicit UTF-8 here.
    builder.addUTF8String(payload);

    return _publishBuffer(
      client,
      topic,
      builder.payload!,
      tag,
      successType,
      successMsg,
      pointCount: pointCount,
      logTagOverride: logTagOverride,
      qos: qos,
    );
  }

  bool _publishBytes(
    MqttServerClient client,
    String topic,
    Uint8Buffer payload,
    String tag,
    String successType,
    String successMsg, {
    required int pointCount,
    String? logTagOverride,
    MqttQos qos = MqttQos.atMostOnce,
  }) {
    return _publishBuffer(
      client,
      topic,
      payload,
      tag,
      successType,
      successMsg,
      pointCount: pointCount,
      logTagOverride: logTagOverride,
      qos: qos,
    );
  }

  bool _publishBuffer(
    MqttServerClient client,
    String topic,
    Uint8Buffer payload,
    String tag,
    String successType,
    String successMsg, {
    required int pointCount,
    String? logTagOverride,
    required MqttQos qos,
  }) {
    try {
      client.publishMessage(topic, qos, payload);
      statisticsCollector.incrementSuccess(points: pointCount);
      statisticsCollector.setMessageSize(payload.length);

      // Per-message log formatting is skipped entirely in performance mode.
      if (enableLogs) {
        onLog('$successMsg (~${payload.length} bytes)', successType,
            tag: logTagOverride ?? tag);
      }
      return true;
    } catch (e) {
      if (enableLogs) {
        onLog('Publish error: $e', 'error', tag: logTagOverride ?? tag);
      }
      statisticsCollector.incrementFailure();
      return false;
    }
  }

  void _scheduleNext(String clientId, int intervalMs, int sendCount,
      int version, int phaseOffset, Function(int) callback) {
    // Safety check BEFORE scheduling
    if (!_clientTimers.containsKey(clientId)) return;
    if (_clientVersions[clientId] != version) return;

    final decision = _computeNextSchedule(
      nowMs: DateTime.now().millisecondsSinceEpoch,
      alignedStartTime: _alignedStartTime,
      phaseOffset: phaseOffset,
      intervalMs: intervalMs,
      sendCount: sendCount,
    );

    if (decision.droppedLateTicks) {
      if (enableLogs) {
        onLog(
            '[$clientId] Late by real-time schedule. Dropping ${decision.skippedCount} stale ticks to keep latency low.',
            'warning');
      }
      statisticsCollector.incrementLateDropped(count: decision.skippedCount);
    }

    Timer t = Timer(
      Duration(milliseconds: decision.delayMs),
      () => callback(decision.sendCount),
    );
    _addTimer(clientId, t);
  }

  ScheduleDecision _computeNextSchedule({
    required int nowMs,
    required int alignedStartTime,
    required int phaseOffset,
    required int intervalMs,
    required int sendCount,
  }) {
    intervalMs = intervalMs < 1 ? 1000 : intervalMs;
    final int nextTarget =
        alignedStartTime + phaseOffset + (sendCount * intervalMs);
    final int delay = nextTarget - nowMs;

    if (delay < -20) {
      final int elapsed = nowMs - (alignedStartTime + phaseOffset);
      final int currentSendCount = (elapsed ~/ intervalMs) + 1;

      if (currentSendCount > sendCount) {
        final int adjustedTarget =
            alignedStartTime + phaseOffset + (currentSendCount * intervalMs);
        final int adjustedDelay = adjustedTarget - nowMs;

        return ScheduleDecision(
          sendCount: currentSendCount,
          delayMs: adjustedDelay < 0 ? 0 : adjustedDelay,
          skippedCount: currentSendCount - sendCount,
        );
      }
    }

    return ScheduleDecision(
      sendCount: sendCount,
      delayMs: delay < 0 ? 0 : delay,
    );
  }

  void _addTimer(String clientId, Timer t) {
    // For normal Timer, add to list
    final timers = _clientTimers[clientId];
    if (timers == null) {
      t.cancel();
      return;
    }
    timers.removeWhere((timer) => !timer.isActive);
    timers.add(t);
  }

  void _cancelTimers(List<Timer> timers) {
    for (final timer in timers) {
      if (timer.isActive) {
        timer.cancel();
      }
    }
    timers.clear();
  }

  int _intervalMsFromSeconds(int seconds) {
    return seconds < 1 ? 1000 : seconds * 1000;
  }

  /// Upper bound (ms) of the stagger window. Sends are spread deterministically
  /// across at most this window so that, even for very large intervals (e.g. a
  /// 300s full report), devices report near-simultaneously instead of
  /// trickling across the whole interval — while still avoiding a single-instant
  /// thundering-herd CPU spike.
  static const int _maxStaggerMs = 2000;

  /// Deterministic per-client stagger offset within a bounded window.
  /// Returns a value in `[0, min(intervalMs, _maxStaggerMs))`, or 0 when the
  /// interval is non-positive. [salt] lets independent streams (e.g. change vs.
  /// full) use distinct offsets while staying stable per client.
  int _staggerOffset(String clientId, int intervalMs, {int salt = 0}) {
    if (intervalMs <= 0) return 0;
    final int window = intervalMs < _maxStaggerMs ? intervalMs : _maxStaggerMs;
    return (clientId.hashCode + salt) % window;
  }

  MqttQos _intToQos(int v) {
    if (v == 1) return MqttQos.atLeastOnce;
    if (v == 2) return MqttQos.exactlyOnce;
    return MqttQos.atMostOnce;
  }
}
