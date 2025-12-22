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
    if (context is BasicSimulationContext) {
      _startBasicPublishing(client, clientId, context);
    } else if (context is AdvancedSimulationContext) {
      _startAdvancedPublishing(client, clientId, context);
    }
  }

  // --- Basic Mode Logic ---
  void _startBasicPublishing(MqttServerClient client, String clientId, BasicSimulationContext context) {
    int intervalSeconds = context.intervalSeconds;
    int intervalMs = intervalSeconds * 1000;
    
    // Initial Delay
    int now = DateTime.now().millisecondsSinceEpoch;
    int initialDelay = (_alignedStartTime - now);
    if (initialDelay < 0) initialDelay = 0;

    int sendCount = 0;
    Timer timer = Timer(Duration(milliseconds: initialDelay), () {
      _scheduleNextBasicPublish(client, clientId, context, intervalMs, sendCount);
    });
    _addTimer(clientId, timer);
  }

  void _scheduleNextBasicPublish(
    MqttServerClient client, 
    String clientId, 
    BasicSimulationContext context,
    int intervalMs, 
    int sendCount
  ) {
    if (!_clientTimers.containsKey(clientId)) return; // Stopped

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
    }
    
    String payload = jsonEncode(data);
    _publish(client, topic, payload, clientId, 'success', 'Sent message #$sendCount', clientId);
    
    // 2. Schedule Next
    sendCount++;
    _scheduleNext(clientId, intervalMs, sendCount, () {
      _scheduleNextBasicPublish(client, clientId, context, intervalMs, sendCount);
    });
  }

  // --- Advanced Mode Logic ---
  void _startAdvancedPublishing(MqttServerClient client, String clientId, AdvancedSimulationContext context) {
    final GroupConfig group = context.group;
    final String topic = context.topic;
    
    int now = DateTime.now().millisecondsSinceEpoch;
    int initialDelay = (_alignedStartTime - now);
    if (initialDelay < 0) initialDelay = 0;

    // 1. Full Report
    int fullIntervalMs = group.fullIntervalSeconds * 1000;
    int fullSendCount = 0;
    Timer fullTimer = Timer(Duration(milliseconds: initialDelay), () {
      _scheduleFullReport(client, clientId, topic, group, fullIntervalMs, fullSendCount);
    });
    _addTimer(clientId, fullTimer);

    // 2. Change Report
    if (group.changeRatio > 0 && group.changeIntervalSeconds < group.fullIntervalSeconds) {
      int changeIntervalMs = group.changeIntervalSeconds * 1000;
      int changeSendCount = 0;
      Timer changeTimer = Timer(Duration(milliseconds: initialDelay), () {
        _scheduleChangeReport(client, clientId, topic, group, changeIntervalMs, changeSendCount);
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
  ) {
    if (!_clientTimers.containsKey(clientId)) return;

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
    }
    
    String payload = jsonEncode(data);
    _publish(client, topic, payload, group.name, 'success', '[$clientId] Full Report #$sendCount');

    sendCount++;
    _scheduleNext(clientId, intervalMs, sendCount, () {
      _scheduleFullReport(client, clientId, topic, group, intervalMs, sendCount);
    });
  }

  void _scheduleChangeReport(
    MqttServerClient client,
    String clientId,
    String topic,
    GroupConfig group,
    int intervalMs,
    int sendCount,
  ) {
    if (!_clientTimers.containsKey(clientId)) return;

    int payloadTimestamp = _alignedStartTime + (sendCount * intervalMs);
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
    }
    
    String payload = jsonEncode(data);
    // Use info type for change reports to distinguish
    _publish(client, topic, payload, group.name, 'info', '[$clientId] Change Report #$sendCount (${data.length} keys)');

    sendCount++;
    _scheduleNext(clientId, intervalMs, sendCount, () {
      _scheduleChangeReport(client, clientId, topic, group, intervalMs, sendCount);
    });
  }

  // --- Helper Methods ---

  void _publish(MqttServerClient client, String topic, String payload, String tag, String successType, String successMsg, [String? logTagOverride]) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    
    try {
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      statisticsCollector.incrementSuccess();
      statisticsCollector.setMessageSize(payload.length);
      int bytes = utf8.encode(payload).length;
      onLog('$successMsg ($bytes bytes)', successType, tag: logTagOverride ?? tag);
    } catch (e) {
      onLog('Publish error: $e', 'error', tag: logTagOverride ?? tag);
      statisticsCollector.incrementFailure();
    }
  }

  void _scheduleNext(String clientId, int intervalMs, int sendCount, VoidCallback callback) {
     int nextTarget = _alignedStartTime + (sendCount * intervalMs);
     int delay = nextTarget - DateTime.now().millisecondsSinceEpoch;
     if (delay < 0) delay = 0;
     
     Timer t = Timer(Duration(milliseconds: delay), callback);
     _addTimer(clientId, t);
  }

  void _addTimer(String clientId, Timer t) {
    if (!_clientTimers.containsKey(clientId)) {
      _clientTimers[clientId] = [];
    }
    _clientTimers[clientId]!.add(t);
  }
}
