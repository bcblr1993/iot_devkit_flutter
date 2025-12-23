import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../../services/data_generator.dart';
import '../../utils/statistics_collector.dart';
import '../../models/group_config.dart';
import '../../models/custom_key_config.dart';
import '../../models/simulation_context.dart';

class SchedulerService {
  final StatisticsCollector statisticsCollector;
  final Function(String message, String type, {String? tag}) onLog;

  int _alignedStartTime = 0;
  final Map<String, List<Timer>> _clientTimers = {};
  final Map<String, int> _clientVersions = {};

  SchedulerService({
    required this.statisticsCollector,
    required this.onLog,
  });

  void reset() {
    _alignedStartTime = DateTime.now().millisecondsSinceEpoch + 2000;
  }

  void stopAll() {
    for (var timers in _clientTimers.values) {
      for (var t in timers) {
        t.cancel();
      }
    }
    _clientTimers.clear();
  }

  void stopPublishing(String clientId) {
    if (_clientTimers.containsKey(clientId)) {
      for (var t in _clientTimers[clientId]!) {
        t.cancel();
      }
      _clientTimers[clientId]!.clear();
      _clientTimers.remove(clientId);
    }
  }

  void startPublishing(MqttServerClient client, String clientId, SimulationContext context) {
    // CRITICAL FIX: Ensure any existing scheduling chain for this client is stopped before starting a new one.
    // This prevents "Double Timers" if onConnected is triggered multiple times or race conditions occur.
    if (_clientTimers.containsKey(clientId)) {
      onLog('Restarting scheduler for $clientId (cleaning up cleaning previous timers)', 'warning');
      stopPublishing(clientId);
    }
    
    // STRICT FIX: Initialize list BEFORE starting.
    // _addTimer now requires this list to exist.
    _clientTimers[clientId] = [];
    
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
  void _startBasicPublishing(MqttServerClient client, String clientId, BasicSimulationContext context, int version) {
    int intervalSeconds = context.intervalSeconds;
    int intervalMs = intervalSeconds * 1000;
    
    // Initial Delay
    int now = DateTime.now().millisecondsSinceEpoch;
    int initialDelay = (_alignedStartTime - now);
    if (initialDelay < 0) initialDelay = 0;

    int sendCount = 0;
    Timer timer = Timer(Duration(milliseconds: initialDelay), () {
      _scheduleNextBasicPublish(client, clientId, context, intervalMs, sendCount, version);
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
  ) {
    if (!_clientTimers.containsKey(clientId)) return; // Stopped
    if (_clientVersions[clientId] != version) return; // Wrong Session

    final String topic = context.topic;
    final String format = context.format;
    final int dataPointCount = context.dataPointCount;
    final List<CustomKeyConfig> customKeys = context.customKeys;

    // 1. Generate Payload
    int payloadTimestamp = _alignedStartTime + (sendCount * intervalMs);
    Map<String, dynamic> data;
    
    if (format == 'tn') {
      data = DataGenerator.generateTnPayload(dataPointCount, timestamp: payloadTimestamp);
    } else if (format == 'tn-empty') {
      data = DataGenerator.generateTnEmptyPayload(timestamp: payloadTimestamp);
    } else {
      data = DataGenerator.generateBatteryStatus(dataPointCount, clientId: clientId, customKeys: customKeys);
      data = DataGenerator.wrapWithTimestamp(data, payloadTimestamp);
    }
    
    String payload = jsonEncode(data);
    _publish(client, topic, payload, clientId, 'success', 'Sent message #$sendCount', clientId);
    
    // 2. Schedule Next
    sendCount++;
    _scheduleNext(clientId, intervalMs, sendCount, version, (actualCount) {
      _scheduleNextBasicPublish(client, clientId, context, intervalMs, actualCount, version);
    });
  }

  // --- Advanced Mode Logic ---
  void _startAdvancedPublishing(MqttServerClient client, String clientId, AdvancedSimulationContext context, int version) {
    final GroupConfig group = context.group;
    final String topic = context.topic;
    
    int now = DateTime.now().millisecondsSinceEpoch;
    int initialDelay = (_alignedStartTime - now);
    if (initialDelay < 0) initialDelay = 0;

    // 1. Full Report
    int fullIntervalMs = group.fullIntervalSeconds * 1000;
    int fullSendCount = 0;
    Timer fullTimer = Timer(Duration(milliseconds: initialDelay), () {
      _scheduleFullReport(client, clientId, topic, group, fullIntervalMs, fullSendCount, version);
    });
    _addTimer(clientId, fullTimer);

    // 2. Change Report
    if (group.changeRatio > 0 && group.changeIntervalSeconds < group.fullIntervalSeconds) {
      int changeIntervalMs = group.changeIntervalSeconds * 1000;
      int changeSendCount = 0;
      Timer changeTimer = Timer(Duration(milliseconds: initialDelay), () {
        _scheduleChangeReport(client, clientId, topic, group, changeIntervalMs, changeSendCount, version);
      });
      _addTimer(clientId, changeTimer);
    }
  }

  void _scheduleFullReport(
    MqttServerClient client,
    String clientId,
    String topic,
    GroupConfig group,
    int intervalMs,
    int sendCount,
    int version,
  ) {
    if (!_clientTimers.containsKey(clientId)) return;
    if (_clientVersions[clientId] != version) return; // Wrong Session

    int payloadTimestamp = _alignedStartTime + (sendCount * intervalMs);
    Map<String, dynamic> data;
    if (group.format == 'tn') {
      data = DataGenerator.generateTnPayload(group.totalKeyCount, timestamp: payloadTimestamp);
    } else if (group.format == 'tn-empty') {
      data = DataGenerator.generateTnEmptyPayload(timestamp: payloadTimestamp);
    } else {
      data = DataGenerator.generateBatteryStatus(
        group.totalKeyCount,
        clientId: clientId,
        customKeys: group.customKeys,
      );
      data = DataGenerator.wrapWithTimestamp(data, payloadTimestamp);
    }
    
    String payload = jsonEncode(data);
    _publish(client, topic, payload, group.name, 'success', '[$clientId] Full Report #$sendCount');

    sendCount++;
    _scheduleNext(clientId, intervalMs, sendCount, version, (actualCount) {
      _scheduleFullReport(client, clientId, topic, group, intervalMs, actualCount, version);
    });
  }

  void _scheduleChangeReport(
    MqttServerClient client,
    String clientId,
    String topic,
    GroupConfig group,
    int intervalMs,
    int sendCount,
    int version,
  ) {
    if (!_clientTimers.containsKey(clientId)) return;
    if (_clientVersions[clientId] != version) return; // Wrong Session

    int payloadTimestamp = _alignedStartTime + (sendCount * intervalMs);
    
    // CRITICAL FIX: Conflict Resolution
    // If the current time aligns exactly with a Full Report interval, SKIP the Change Report.
    // Full Reports (Whole Data) include the Changed Data, so sending both is duplicative.
    int fullIntervalMs = group.fullIntervalSeconds * 1000;
    int elapsedTime = sendCount * intervalMs;
    
    // Check collision (ensure fullInterval is not 0 to avoid division by zero)
    if (fullIntervalMs > 0 && elapsedTime % fullIntervalMs == 0) {
      // Just log internally or skip quietly. We still need to schedule the NEXT one.
      // onLog('[$clientId] Skipped Change Report (Coincides with Full Report)', 'info', tag: group.name);
      
      sendCount++;
      _scheduleNext(clientId, intervalMs, sendCount, version, (actualCount) {
        _scheduleChangeReport(client, clientId, topic, group, intervalMs, actualCount, version);
      });
      return; 
    }

    Map<String, dynamic> data;
    int totalChangeCount = (group.totalKeyCount * group.changeRatio).floor();
    
    if (group.format == 'tn') {
      data = DataGenerator.generateTnPayload(group.totalKeyCount, timestamp: payloadTimestamp);
    } else if (group.format == 'tn-empty') {
      data = DataGenerator.generateTnEmptyPayload(timestamp: payloadTimestamp);
    } else {
      int customCount = group.customKeys.length;
      int randomChangeCount = (totalChangeCount - customCount).clamp(0, group.totalKeyCount);
      data = DataGenerator.generateBatteryStatus(
        randomChangeCount + customCount,
        clientId: clientId,
        customKeys: group.customKeys,
      );
      data = DataGenerator.wrapWithTimestamp(data, payloadTimestamp);
    }
    
    String payload = jsonEncode(data);
    // Use info type for change reports to distinguish
    _publish(client, topic, payload, group.name, 'info', '[$clientId] Change Report #$sendCount (${data.length} keys)');

    sendCount++;
    _scheduleNext(clientId, intervalMs, sendCount, version, (actualCount) {
      _scheduleChangeReport(client, clientId, topic, group, intervalMs, actualCount, version);
    });
  }

  // --- Helper Methods ---

  void _publish(MqttServerClient client, String topic, String payload, String tag, String successType, String successMsg, [String? logTagOverride]) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    
    try {
      // OPTIMIZATION: Use QoS 0 (atMostOnce) to prevent "Retry Storms" under high load.
      // High concurrency delays PUBACKs, causing clients to retry and create duplicates.
      client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
      statisticsCollector.incrementSuccess();
      statisticsCollector.setMessageSize(payload.length);
      int bytes = utf8.encode(payload).length;
      onLog('$successMsg ($bytes bytes)', successType, tag: logTagOverride ?? tag);
    } catch (e) {
      onLog('Publish error: $e', 'error', tag: logTagOverride ?? tag);
      statisticsCollector.incrementFailure();
    }
  }

  void _scheduleNext(String clientId, int intervalMs, int sendCount, int version, Function(int) callback) {
    // Safety check BEFORE scheduling
    if (!_clientTimers.containsKey(clientId)) return;
    if (_clientVersions[clientId] != version) return;

    int nextTarget = _alignedStartTime + (sendCount * intervalMs);
    
    // OPTIMIZATION: Add random Jitter (0-500ms) to the FIRING time (not payload time).
    // This distributes the CPU/Network spike so 1000 devices don't fire at the exact same millisecond.
    int jitter = (clientId.hashCode % 500); 
    int targetWithJitter = nextTarget + jitter;

    int now = DateTime.now().millisecondsSinceEpoch;
    int delay = targetWithJitter - now;

    if (delay < -500) {
      // Skip missed cycles
      int missedCycles = ((now - nextTarget) / intervalMs).ceil();
      sendCount += missedCycles;
      
      // Calculate new target and delay
      nextTarget = _alignedStartTime + (sendCount * intervalMs);
      targetWithJitter = nextTarget + jitter;
      delay = targetWithJitter - now;
      
      // Safety: Ensure delay is non-negative and we aren't spiraling
      if (delay < 0) {
         delay = 0; 
         // Force move to next interval if we are somehow still behind
         if (now > nextTarget) {
            sendCount++;
            nextTarget = _alignedStartTime + (sendCount * intervalMs);
            targetWithJitter = nextTarget + jitter;
            delay = targetWithJitter - now;
         }
      }
    }

    if (delay < 0) delay = 0;
    
    Timer t = Timer(Duration(milliseconds: delay), () => callback(sendCount));
    _addTimer(clientId, t);
  }

  void _addTimer(String clientId, Timer t) {
    // STRICT FIX: If the client is not in the map, it means we stopped publishing.
    // Do NOT re-create the list. Instead, cancel the zombie timer immediately.
    if (!_clientTimers.containsKey(clientId)) {
      t.cancel();
      // onLog('[$clientId] Zombie timer killed', 'warning');
      return;
    }
    _clientTimers[clientId]!.add(t);
  }
}
