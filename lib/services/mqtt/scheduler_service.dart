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
    _alignedStartTime = DateTime.now().millisecondsSinceEpoch + 200;
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
    
    // STAGGER LOGIC:
    // Distribute load across the interval to prevent "Thundering Herd" (CPU spikes).
    // Use hashCode for deterministic distribution.
    int phaseOffset = 0;
    if (intervalMs > 0) {
      phaseOffset = clientId.hashCode % intervalMs;
    }
    
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
      _scheduleNextBasicPublish(client, clientId, context, intervalMs, sendCount, version, phaseOffset);
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
    int payloadTimestamp = _alignedStartTime + phaseOffset + (sendCount * intervalMs);
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
    _publish(client, topic, payload, clientId, 'success', 'Sent message #$sendCount', clientId, _intToQos(context.qos));
    
    // 2. Schedule Next
    sendCount++;
    _scheduleNext(clientId, intervalMs, sendCount, version, phaseOffset, (actualCount) {
      _scheduleNextBasicPublish(client, clientId, context, intervalMs, actualCount, version, phaseOffset);
    });
  }

  // --- Advanced Mode Logic ---
  // --- Advanced Mode Logic ---
  void _startAdvancedPublishing(MqttServerClient client, String clientId, AdvancedSimulationContext context, int version) {
    final GroupConfig group = context.group;
    final String topic = context.topic;
    
    int now = DateTime.now().millisecondsSinceEpoch;
    
    // OPTIMIZATION:
    // If ChangeRatio is 100% (or more), then "Change Report" is identical to "Full Report".
    // If the Change Frequency is higher (interval smaller) than Full Frequency,
    // we should just run the Full Report at that higher frequency and disable the redundant slower timer.
    bool runFullAtChangeSpeed = (group.changeRatio >= 1.0) && (group.changeIntervalSeconds < group.fullIntervalSeconds);
    
    // 1. Full Report Setup
    // If optimization active, use change interval. Else use full interval.
    int effectiveFullIntervalMs = runFullAtChangeSpeed 
        ? group.changeIntervalSeconds * 1000 
        : group.fullIntervalSeconds * 1000;
        
    int fullPhaseOffset = 0;
    if (effectiveFullIntervalMs > 0) fullPhaseOffset = clientId.hashCode % effectiveFullIntervalMs;

    int fullBaseTarget = _alignedStartTime + fullPhaseOffset;
    int fullDelay = fullBaseTarget - now;
    int fullSendCount = 0;
    
    if (fullDelay < 0) {
       int elapsed = now - fullBaseTarget;
       fullSendCount = (elapsed ~/ effectiveFullIntervalMs) + 1;
       fullDelay = (fullBaseTarget + (fullSendCount * effectiveFullIntervalMs)) - now;
    }

    Timer fullTimer = Timer(Duration(milliseconds: fullDelay), () {
      _scheduleFullReport(client, clientId, topic, group, effectiveFullIntervalMs, fullSendCount, version, context.qos, fullPhaseOffset);
    });
    _addTimer(clientId, fullTimer);

    // 2. Change Report Setup
    // Only schedule if NOT 100% change (mixed mode) AND valid interval.
    // If runFullAtChangeSpeed is true, we have already "promoted" the change report to be the main Full Report above, so we skip this.
    if (!runFullAtChangeSpeed && group.changeRatio > 0 && group.changeIntervalSeconds < group.fullIntervalSeconds) {
      int changeIntervalMs = group.changeIntervalSeconds * 1000;
      int changePhaseOffset = 0;
      if (changeIntervalMs > 0) {
        changePhaseOffset = (clientId.hashCode + 12345) % changeIntervalMs;
      }
      
      int changeBaseTarget = _alignedStartTime + changePhaseOffset;
      int changeDelay = changeBaseTarget - now;
      int changeSendCount = 0;
      
      if (changeDelay < 0) {
         int elapsed = now - changeBaseTarget;
         changeSendCount = (elapsed ~/ changeIntervalMs) + 1;
         changeDelay = (changeBaseTarget + (changeSendCount * changeIntervalMs)) - now;
      }

      Timer changeTimer = Timer(Duration(milliseconds: changeDelay), () {
        _scheduleChangeReport(client, clientId, topic, group, changeIntervalMs, changeSendCount, version, context.qos, changePhaseOffset);
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

    int payloadTimestamp = _alignedStartTime + phaseOffset + (sendCount * intervalMs);
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

    _publish(client, topic, payload, group.name, 'success', '[$clientId] Full Report #$sendCount', null, _intToQos(qos));

    sendCount++;
    _scheduleNext(clientId, intervalMs, sendCount, version, phaseOffset, (actualCount) {
      _scheduleFullReport(client, clientId, topic, group, intervalMs, actualCount, version, qos, phaseOffset);
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

    int payloadTimestamp = _alignedStartTime + phaseOffset + (sendCount * intervalMs);
    
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
      _scheduleNext(clientId, intervalMs, sendCount, version, phaseOffset, (actualCount) {
        _scheduleChangeReport(client, clientId, topic, group, intervalMs, actualCount, version, qos, phaseOffset);
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

    _publish(client, topic, payload, group.name, 'info', msg, null, _intToQos(qos));

    sendCount++;
    _scheduleNext(clientId, intervalMs, sendCount, version, phaseOffset, (actualCount) {
      _scheduleChangeReport(client, clientId, topic, group, intervalMs, actualCount, version, qos, phaseOffset);
    });
  }

  // --- Helper Methods ---

  void _publish(MqttServerClient client, String topic, String payload, String tag, String successType, String successMsg, [String? logTagOverride, MqttQos qos = MqttQos.atMostOnce]) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    
    try {
      client.publishMessage(topic, qos, builder.payload!);
      statisticsCollector.incrementSuccess();
      statisticsCollector.setMessageSize(payload.length);
      
      // OPTIMIZATION: Only calculate bytes and log if logging is enabled
      if (enableLogs) {
        // Use string length as approximation to avoid utf8.encode overhead (which allocates a new list)
        // For logging purposes, exact byte count isn't critical, but performance is.
        int charCount = payload.length; 
        onLog('$successMsg (~$charCount chars)', successType, tag: logTagOverride ?? tag);
      }
    } catch (e) {
      if (enableLogs) {
        onLog('Publish error: $e', 'error', tag: logTagOverride ?? tag);
      }
      statisticsCollector.incrementFailure();
    }
  }

  void _scheduleNext(String clientId, int intervalMs, int sendCount, int version, int phaseOffset, Function(int) callback) {
    // Safety check BEFORE scheduling
    if (!_clientTimers.containsKey(clientId)) return;
    if (_clientVersions[clientId] != version) return;

    int now = DateTime.now().millisecondsSinceEpoch;
    int nextTarget = _alignedStartTime + phaseOffset + (sendCount * intervalMs);
    int delay = nextTarget - now;
    
    // STRICT MODE: Drop missed packets.
    if (delay < -20) { // 20ms tolerance
       // Calculate how many we missed considering offset
       int elapsed = now - (_alignedStartTime + phaseOffset);
       int correctCount = (elapsed ~/ intervalMs) + 1;
       
       if (correctCount > sendCount) {
         int skipped = correctCount - sendCount;
         
         // Log drop
         if (enableLogs && skipped > 1) {
             onLog('[$clientId] STRICT MODE: Late by ${-delay}ms. Dropping $skipped ticks.', 'warning');
         }
         statisticsCollector.incrementFailure(count: skipped);
         
         // Fast Forward
         sendCount = correctCount;
         nextTarget = _alignedStartTime + phaseOffset + (sendCount * intervalMs);
         delay = nextTarget - now;
       }
    }
    
    if (delay < 0) delay = 0;

    Timer t = Timer(Duration(milliseconds: delay), () => callback(sendCount));
    _addTimer(clientId, t);
  }

  void _addTimer(String clientId, Timer t) {
    // For normal Timer, add to list
      if (!_clientTimers.containsKey(clientId)) {
        t.cancel();
        return;
      }
      _clientTimers[clientId]!.add(t);
  }

  MqttQos _intToQos(int v) {
    if (v == 1) return MqttQos.atLeastOnce;
    if (v == 2) return MqttQos.exactlyOnce;
    return MqttQos.atMostOnce;
  }
}
