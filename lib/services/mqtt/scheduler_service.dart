import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../../services/data_generator.dart';
import '../../utils/statistics_collector.dart';
import '../../models/group_config.dart';
import '../../models/custom_key_config.dart';
import '../../utils/isolate_worker.dart';
import '../../models/simulation_context.dart';

class SchedulerService {
  final StatisticsCollector statisticsCollector;
  final Function(String message, String type, {String? tag}) onLog;

  int _alignedStartTime = 0;
  final Map<String, List<Timer>> _clientTimers = {};
  final Map<String, int> _clientVersions = {};
  
  // Performance Mode: Disable logs to save CPU
  bool enableLogs = true;

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

    // FIX: Calculate sendCount based on elapsed time to support seamless resumption
    int elapsedMs = now - _alignedStartTime;
    int sendCount = 0;
    if (elapsedMs > 0) {
      sendCount = (elapsedMs / intervalMs).ceil();
    }
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
    // FIX: Calculate sendCount for resumption
    int elapsedMs = now - _alignedStartTime;
    int fullSendCount = 0;
    if (elapsedMs > 0) {
      fullSendCount = (elapsedMs / fullIntervalMs).ceil();
    }
    Timer fullTimer = Timer(Duration(milliseconds: initialDelay), () {
      _scheduleFullReport(client, clientId, topic, group, fullIntervalMs, fullSendCount, version);
    });
    _addTimer(clientId, fullTimer);

    // 2. Change Report
    if (group.changeRatio > 0 && group.changeIntervalSeconds < group.fullIntervalSeconds) {
      int changeIntervalMs = group.changeIntervalSeconds * 1000;
      int changeSendCount = 0;
      if (elapsedMs > 0) {
        changeSendCount = (elapsedMs / changeIntervalMs).ceil();
      }
      Timer changeTimer = Timer(Duration(milliseconds: initialDelay), () {
        _scheduleChangeReport(client, clientId, topic, group, changeIntervalMs, changeSendCount, version);
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
  ) async {
    if (!_clientTimers.containsKey(clientId)) return;
    if (_clientVersions[clientId] != version) return; // Wrong Session

    int payloadTimestamp = _alignedStartTime + (sendCount * intervalMs);
    String payload;

      // Standard Format
      // OPTIMIZATION: Always use Persistent Isolate Worker to offload serialization.
      // This is crucial for high concurrency (e.g. 200 devices * 100 points) where
      // the aggregate main-thread cost of 200 JSON encodes causes lag.
      
      // 1. Prepare State (Main Thread)
      int key1 = DataGenerator.getKey1Value(clientId);
      Map<String, dynamic> customValues = DataGenerator.generateCustomKeys(group.customKeys);
      
      // 2. Offload work to Persistent Isolate
      try {
        payload = await PersistentIsolateManager.instance.computeTask(WorkerInput(
          count: group.totalKeyCount,
          clientId: clientId,
          timestamp: payloadTimestamp,
          key1Value: key1,
          customKeyValues: customValues,
        ));
      } catch (e) {
        onLog('Isolate Error: $e', 'error', tag: clientId);
        return; // Skip on error
      }
    
    // Check cancellation again after await
    if (!_clientTimers.containsKey(clientId)) return;
    if (_clientVersions[clientId] != version) return;

    _publish(client, topic, payload, group.name, 'success', '[$clientId] Full Report #$sendCount');

    sendCount++;
    _scheduleNext(clientId, intervalMs, sendCount, version, (actualCount) {
      _scheduleFullReport(client, clientId, topic, group, intervalMs, actualCount, version);
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
  ) async {
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

    // OPTIMIZATION: Use Persistent Isolate
    int totalChangeCount = (group.totalKeyCount * group.changeRatio).floor();
    
    String payload;

    // TN Formats (Usually tiny, keep main thread for now, or TODO migrate)
    if (group.format == 'tn') {
      Map<String, dynamic> data = DataGenerator.generateTnPayload(group.totalKeyCount, timestamp: payloadTimestamp);
      payload = jsonEncode(data);
    } else if (group.format == 'tn-empty') {
      Map<String, dynamic> data = DataGenerator.generateTnEmptyPayload(timestamp: payloadTimestamp);
      payload = jsonEncode(data);
    } else {
      // Standard Format
    // Standard Format
    // OPTIMIZATION: Always use Persistent Isolate Worker
      if (true) {
         // 1. Prepare State (Main Thread)
         int key1 = DataGenerator.getKey1Value(clientId);
         Map<String, dynamic> customValues = DataGenerator.generateCustomKeys(group.customKeys);

         try {
           payload = await PersistentIsolateManager.instance.computeTask(WorkerInput(
             count: totalChangeCount, 
             clientId: clientId,
             timestamp: payloadTimestamp,
             key1Value: key1,
             customKeyValues: customValues,
           ));
         } catch (e) {
            onLog('Isolate Error (Change): $e', 'error', tag: clientId);
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
    String msg = '[$clientId] Change Report #$sendCount (~$totalChangeCount keys)';

    _publish(client, topic, payload, group.name, 'info', msg);

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
      // FIX: Use QoS 1 (atLeastOnce) to ensure delivery.
      // QoS 0 (atMostOnce) causes data loss under high load as packets are dropped.
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      statisticsCollector.incrementSuccess();
      statisticsCollector.setMessageSize(payload.length);
      
      // OPTIMIZATION: Only calculate bytes and log if logging is enabled
      if (enableLogs) {
        int bytes = utf8.encode(payload).length;
        onLog('$successMsg ($bytes bytes)', successType, tag: logTagOverride ?? tag);
      }
    } catch (e) {
      if (enableLogs) {
        onLog('Publish error: $e', 'error', tag: logTagOverride ?? tag);
      }
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

    // RELAXED FIX: The previous threshold (-500ms) was too aggressive.
    // However, for "No Data Loss", we must NEVER skip.
    // We just run as fast as possible (delay=0) until we catch up.
    /* 
    if (delay < -3000) {
      // ... Skip logic removed to ensure data integrity ...
    }
    */

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
