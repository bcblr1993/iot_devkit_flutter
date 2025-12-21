import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter/foundation.dart';

import '../services/data_generator.dart';
import '../utils/statistics_collector.dart';
import '../models/group_config.dart';
import '../models/custom_key_config.dart';


class MqttController extends ChangeNotifier {
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  set isRunning(bool value) {
    _isRunning = value;
    notifyListeners();
  }

  final StatisticsCollector statisticsCollector = StatisticsCollector();
  
  // List of connected clients
  final List<MqttServerClient> _clients = [];
  final Map<String, List<Timer>> _clientTimers = {};
  
  // Reconnection tracking
  final Map<String, Map<String, dynamic>> _clientConfigs = {}; // Store client config for reconnection
  final Map<String, int> _reconnectAttempts = {};
  final Map<String, Timer?> _reconnectTimers = {};
  static const int _baseReconnectDelayMs = 2000; // 2 seconds base delay
  static const int _maxReconnectDelayMs = 30000; // Max 30 seconds
  
  // Callback for logs
  Function(String message, String type)? onLog;
  
  int _alignedStartTime = 0;

  void log(String message, {String type = 'info'}) {
    if (onLog != null) {
      onLog!(message, type);
    } else {
      debugPrint('[$type] $message');
    }
  }

  Future<void> stop() async {
    if (!isRunning) return;
    
    isRunning = false;
    log('Stopping simulation...', type: 'info');

    // 1. Cancel all timers
    for (var timers in _clientTimers.values) {
      for (var t in timers) {
        t.cancel();
      }
    }
    _clientTimers.clear();
    
    // 1.5. Cancel all reconnect timers
    for (var timer in _reconnectTimers.values) {
      timer?.cancel();
    }
    _reconnectTimers.clear();
    _reconnectAttempts.clear();
    _clientConfigs.clear();

    // 2. Disconnect clients
    for (var client in _clients) {
      try {
        client.disconnect();
      } catch (e) {
        debugPrint('Error disconnecting client: $e');
      }
    }
    _clients.clear();
    
    // 3. Reset stats
    // statisticsCollector.reset(); // Optional: Keep stats visible after stop? JS version doesn't reset on stop, only on start.

    log('Simulation stopped.', type: 'info');
  }

  Future<void> start(Map<String, dynamic> config) async {
    if (isRunning) {
      log('Simulation already running.', type: 'error');
      return;
    }

    isRunning = true;
    
    // Set global aligned time
    _alignedStartTime = DateTime.now().millisecondsSinceEpoch + 2000;
    
    statisticsCollector.reset();
    
    // Determine Mode
    String mode = config['mode'] ?? 'basic';
    
    if (mode == 'basic') {
      await _startBasicMode(config);
    } else if (mode == 'advanced') {
      await _startAdvancedMode(config);
    } else {
      log('Unknown mode: $mode', type: 'error');
      isRunning = false;
    }
  }

  Future<void> _startAdvancedMode(Map<String, dynamic> config) async {
    List<dynamic> groupsRaw = config['groups'] ?? [];
    List<GroupConfig> groups = [];
    
    // Cast or parse groups
    for (var g in groupsRaw) {
      if (g is GroupConfig) {
        groups.add(g);
      }
    }
    
    if (groups.isEmpty) {
      log('No groups configured for Advanced Mode.', type: 'warning');
      isRunning = false;
      return;
    }
    
    int total = groups.fold(0, (sum, g) => sum + (g.endDeviceNumber - g.startDeviceNumber + 1));
    statisticsCollector.setTotalDevices(total);
    log('Starting Advanced Mode: ${groups.length} Groups, $total Devices total.', type: 'info');
    
    DataGenerator.resetKey1Counter();
    DataGenerator.resetCustomKeyCounters();
    
    String host = config['mqtt']['host'] ?? 'localhost';
    int port = config['mqtt']['port'] ?? 1883;
    String topic = config['mqtt']['topic'] ?? 'v1/devices/me/telemetry';

    // Iterate through groups
    for (var group in groups) {
      if (!isRunning) break;
      
      log('Starting Group: ${group.name} (Full: ${group.fullIntervalSeconds}s, Change: ${group.changeIntervalSeconds}s, Ratio: ${group.changeRatio})', type: 'info');
      
      for (int i = group.startDeviceNumber; i <= group.endDeviceNumber; i++) {
        if (!isRunning) break;

        String idxStr = i.toString(); 
        String clientId = '${group.clientIdPrefix}$idxStr';
        String username = '${group.usernamePrefix}$idxStr';
        String password = '${group.passwordPrefix}$idxStr';

        _createAdvancedClient(
          host: host,
          port: port,
          clientId: clientId,
          username: username,
          password: password,
          topic: topic,
          group: group,
        );
        
        // Stagger connection
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }
  }

  /// Advanced Mode Client with dual-timer scheduling
  Future<void> _createAdvancedClient({
    required String host,
    required int port,
    required String clientId,
    required String username,
    required String password,
    required String topic,
    required GroupConfig group,
  }) async {
    // Store config for reconnection
    _clientConfigs[clientId] = {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'topic': topic,
      'group': group,
      'mode': 'advanced',
    };
    
    final client = MqttServerClient(host, clientId);
    client.port = port;
    client.keepAlivePeriod = 60;
    client.logging(on: false);
    client.autoReconnect = false; // We handle reconnection manually
    
    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(username, password)
        .startClean();
    client.connectionMessage = connMess;
    
    // Set up disconnect callback for auto-reconnect
    client.onDisconnected = () {
      if (!isRunning) return;
      _clients.remove(client);
      // Cancel all timers for this client to prevent publish errors with old client
      if (_clientTimers.containsKey(clientId)) {
        for (var t in _clientTimers[clientId]!) {
          t.cancel();
        }
        _clientTimers[clientId]!.clear();
      }
      statisticsCollector.setOnlineDevices(_clients.length);
      log('[$clientId] Disconnected, will retry...', type: 'warning');
      _scheduleReconnect(clientId);
    };

    try {
      await client.connect();
    } catch (e) {
      log('[$clientId] Connection failed: $e', type: 'error');
      statisticsCollector.incrementFailure();
      _scheduleReconnect(clientId);
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      log('[$clientId] Connected', type: 'success');
      _clients.add(client);
      _reconnectAttempts[clientId] = 0; // Reset retry counter on success
      statisticsCollector.setOnlineDevices(_clients.length);
      
      int now = DateTime.now().millisecondsSinceEpoch;
      int initialDelay = (_alignedStartTime - now);
      if (initialDelay < 0) initialDelay = 0;

      // 1. Schedule Full Report Timer
      int fullIntervalMs = group.fullIntervalSeconds * 1000;
      int fullSendCount = 0;
      Timer fullTimer = Timer(Duration(milliseconds: initialDelay), () {
        _scheduleFullReport(client, clientId, topic, group, fullIntervalMs, fullSendCount);
      });
      _addTimer(clientId, fullTimer);

      // 2. Schedule Change Report Timer (only if changeRatio > 0)
      if (group.changeRatio > 0 && group.changeIntervalSeconds < group.fullIntervalSeconds) {
        int changeIntervalMs = group.changeIntervalSeconds * 1000;
        int changeSendCount = 0;
        Timer changeTimer = Timer(Duration(milliseconds: initialDelay), () {
          _scheduleChangeReport(client, clientId, topic, group, changeIntervalMs, changeSendCount);
        });
        _addTimer(clientId, changeTimer);
      }
      
    } else {
      log('[$clientId] Connection failed status: ${client.connectionStatus!.state}', type: 'error');
      statisticsCollector.incrementFailure();
      _scheduleReconnect(clientId);
    }
  }

  /// Full Report: Send all keys
  void _scheduleFullReport(
    MqttServerClient client,
    String clientId,
    String topic,
    GroupConfig group,
    int intervalMs,
    int sendCount,
  ) {
    if (!isRunning) return;

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
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    
    try {
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      statisticsCollector.incrementSuccess();
      statisticsCollector.setMessageSize(payload.length);
      if (sendCount % 10 == 0) {
        log('[$clientId] Full Report #$sendCount', type: 'success');
      }
    } catch (e) {
      log('[$clientId] Full Report error: $e', type: 'error');
      statisticsCollector.incrementFailure();
    }

    sendCount++;
    int nextTarget = _alignedStartTime + (sendCount * intervalMs);
    int delay = nextTarget - DateTime.now().millisecondsSinceEpoch;
    if (delay < 0) delay = 0;
    
    Timer t = Timer(Duration(milliseconds: delay), () {
      _scheduleFullReport(client, clientId, topic, group, intervalMs, sendCount);
    });
    _addTimer(clientId, t);
  }

  /// Change Report: Send partial keys based on changeRatio
  void _scheduleChangeReport(
    MqttServerClient client,
    String clientId,
    String topic,
    GroupConfig group,
    int intervalMs,
    int sendCount,
  ) {
    if (!isRunning) return;

    // 1. Generate Payload
    int payloadTimestamp = _alignedStartTime + (sendCount * intervalMs);
    Map<String, dynamic> data;
    
    // Calculate change key count for standard format
    int totalChangeCount = (group.totalKeyCount * group.changeRatio).floor();
    
    if (group.format == 'tn') {
      data = DataGenerator.generateTnPayload(group.totalKeyCount, timestamp: payloadTimestamp);
    } else if (group.format == 'tn-empty') {
      data = DataGenerator.generateTnEmptyPayload(timestamp: payloadTimestamp);
    } else {
      // For standard format, we only change a subset of keys except for custom keys which always send
      int totalKeys = group.totalKeyCount;
      int customCount = group.customKeys.length;
      int randomChangeCount = (totalChangeCount - customCount).clamp(0, totalKeys);
      
      data = DataGenerator.generateBatteryStatus(
        randomChangeCount + customCount,
        clientId: clientId,
        customKeys: group.customKeys,
      );
    }
    
    String payload = jsonEncode(data);
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    
    try {
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      statisticsCollector.incrementSuccess();
      if (sendCount % 10 == 0) {
        log('[$clientId] Change Report #$sendCount (${data.length} keys)', type: 'info');
      }
    } catch (e) {
      log('[$clientId] Change Report error: $e', type: 'error');
      statisticsCollector.incrementFailure();
    }

    sendCount++;
    int nextTarget = _alignedStartTime + (sendCount * intervalMs);
    int delay = nextTarget - DateTime.now().millisecondsSinceEpoch;
    if (delay < 0) delay = 0;
    
    Timer t = Timer(Duration(milliseconds: delay), () {
      _scheduleChangeReport(client, clientId, topic, group, intervalMs, sendCount);
    });
    _addTimer(clientId, t);
  }

  Future<void> _startBasicMode(Map<String, dynamic> config) async {
    int startIdx = config['device_start_number'] ?? 1;
    int endIdx = config['device_end_number'] ?? 10;
    int total = endIdx - startIdx + 1;
    
    statisticsCollector.setTotalDevices(total);
    log('Starting Basic Mode: Devices $startIdx - $endIdx ($total total)', type: 'info');
    
    DataGenerator.resetKey1Counter();
    DataGenerator.resetCustomKeyCounters();
    
    String host = config['mqtt']['host'] ?? 'localhost';
    int port = config['mqtt']['port'] ?? 1883;
    String topic = config['mqtt']['topic'] ?? 'v1/devices/me/telemetry';
    
    String clientIdPrefix = config['client_id_prefix'] ?? 'device';
    String devicePrefix = config['device_prefix'] ?? 'device';
    String userPrefix = config['username_prefix'] ?? 'user';
    String passPrefix = config['password_prefix'] ?? 'pass';
    
    int sendInterval = config['send_interval'] ?? 1;
    String format = config['data']['format'] ?? 'default';
    int dataPointCount = config['data']['data_point_count'] ?? 10;
    
    // Parse Custom Keys
    List<CustomKeyConfig> customKeys = [];
    if (config['custom_keys'] != null && config['custom_keys'] is List) {
       customKeys = List<CustomKeyConfig>.from(config['custom_keys']);
    }

    for (int i = startIdx; i <= endIdx; i++) {
      if (!isRunning) break;

      String idxStr = i.toString().padLeft(1, '0'); // JS logic used padLength 1 (no padding basically)
      String clientId = '$clientIdPrefix$idxStr';
      String username = '$userPrefix$idxStr';
      String password = '$passPrefix$idxStr';

      _createClient(
        host: host,
        port: port,
        clientId: clientId,
        username: username,
        password: password,
        topic: topic,
        intervalSeconds: sendInterval,
        format: format,
        dataPointCount: dataPointCount,
        customKeys: customKeys,
      );
      
      // Stagger connection slightly to avoid burst
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> _createClient({
    required String host,
    required int port,
    required String clientId,
    required String username,
    required String password,
    required String topic,
    required int intervalSeconds,
    required String format,
    required int dataPointCount,
    List<CustomKeyConfig> customKeys = const [],
  }) async {
    // Store config for reconnection
    _clientConfigs[clientId] = {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'topic': topic,
      'intervalSeconds': intervalSeconds,
      'format': format,
      'dataPointCount': dataPointCount,
      'customKeys': customKeys,
      'mode': 'basic',
    };
    
    final client = MqttServerClient(host, clientId);
    client.port = port;
    client.keepAlivePeriod = 60;
    client.logging(on: false);
    client.autoReconnect = false; // We handle reconnection manually
    
    // Set connection message
    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(username, password)
        .startClean();
    client.connectionMessage = connMess;
    
    // Set up disconnect callback for auto-reconnect
    client.onDisconnected = () {
      if (!isRunning) return;
      _clients.remove(client);
      // Cancel all timers for this client to prevent publish errors with old client
      if (_clientTimers.containsKey(clientId)) {
        for (var t in _clientTimers[clientId]!) {
          t.cancel();
        }
        _clientTimers[clientId]!.clear();
      }
      statisticsCollector.setOnlineDevices(_clients.length);
      log('[$clientId] Disconnected, will retry...', type: 'warning');
      _scheduleReconnect(clientId);
    };

    try {
      await client.connect();
    } catch (e) {
      log('[$clientId] Connection failed: $e', type: 'error');
      statisticsCollector.incrementFailure();
      _scheduleReconnect(clientId);
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      log('[$clientId] Connected', type: 'success');
      _clients.add(client);
      _reconnectAttempts[clientId] = 0; // Reset retry counter on success
      statisticsCollector.setOnlineDevices(_clients.length);
      
      // Start Publishing Loop
      int intervalMs = intervalSeconds * 1000;
      int sendCount = 0;
      
      // Calculate initial delay to align
      int now = DateTime.now().millisecondsSinceEpoch;
      int initialDelay = (_alignedStartTime - now);
      if (initialDelay < 0) initialDelay = 0;
      
      Timer timer = Timer(Duration(milliseconds: initialDelay), () {
        _scheduleNextPublish(
          client, clientId, topic, format, dataPointCount, intervalMs, sendCount, customKeys
        );
      });
      
      _addTimer(clientId, timer);
      
    } else {
      log('[$clientId] Connection failed status: ${client.connectionStatus!.state}', type: 'error');
      statisticsCollector.incrementFailure();
      _scheduleReconnect(clientId);
    }
  }
  
  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect(String clientId) {
    if (!isRunning) return;
    if (!_clientConfigs.containsKey(clientId)) return;
    
    // Cancel existing reconnect timer if any
    _reconnectTimers[clientId]?.cancel();
    
    // Calculate delay with exponential backoff
    int attempts = _reconnectAttempts[clientId] ?? 0;
    int delayMs = (_baseReconnectDelayMs * (1 << attempts.clamp(0, 5))).clamp(0, _maxReconnectDelayMs);
    _reconnectAttempts[clientId] = attempts + 1;
    
    log('[$clientId] Reconnecting in ${delayMs ~/ 1000}s (attempt ${attempts + 1})...', type: 'info');
    
    _reconnectTimers[clientId] = Timer(Duration(milliseconds: delayMs), () {
      if (!isRunning) return;
      
      final config = _clientConfigs[clientId]!;
      if (config['mode'] == 'basic') {
        _createClient(
          host: config['host'],
          port: config['port'],
          clientId: clientId,
          username: config['username'],
          password: config['password'],
          topic: config['topic'],
          intervalSeconds: config['intervalSeconds'],
          format: config['format'],
          dataPointCount: config['dataPointCount'],
          customKeys: config['customKeys'],
        );
      } else {
        // Advanced mode reconnection
        _createAdvancedClient(
          host: config['host'],
          port: config['port'],
          clientId: clientId,
          username: config['username'],
          password: config['password'],
          topic: config['topic'],
          group: config['group'],
        );
      }
    });
  }

  void _scheduleNextPublish(
    MqttServerClient client,
    String clientId,
    String topic,
    String format,
    int count,
    int intervalMs,
    int sendCount,
    List<CustomKeyConfig> customKeys
  ) {
    if (!isRunning) return;

    // 1. Generate Payload
    int payloadTimestamp = _alignedStartTime + (sendCount * intervalMs);
    Map<String, dynamic> data;
    
    if (format == 'tn') {
      data = DataGenerator.generateTnPayload(count, timestamp: payloadTimestamp);
    } else if (format == 'tn-empty') {
      data = DataGenerator.generateTnEmptyPayload(timestamp: payloadTimestamp);
    } else {
      // Pass customKeys directly; they are integrated within the total count
      data = DataGenerator.generateBatteryStatus(count, clientId: clientId, customKeys: customKeys);
    }
    
    String payload = jsonEncode(data);
    
    // 2. Publish
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    
    try {
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      statisticsCollector.incrementSuccess();
      statisticsCollector.setMessageSize(payload.length); // Approximate
      
      if (sendCount % 10 == 0) {
        log('[$clientId] Sent message #$sendCount', type: 'success');
      }
    } catch (e) {
      log('[$clientId] Publish error: $e', type: 'error');
      statisticsCollector.incrementFailure();
    }

    // 3. Schedule next
    sendCount++;
    int nextTarget = _alignedStartTime + (sendCount * intervalMs);
    int delay = nextTarget - DateTime.now().millisecondsSinceEpoch;
    if (delay < 0) delay = 0;
    
    Timer t = Timer(Duration(milliseconds: delay), () {
      _scheduleNextPublish(client, clientId, topic, format, count, intervalMs, sendCount, customKeys);
    });
    
    _addTimer(clientId, t);
  }

  void _addTimer(String clientId, Timer t) {
    if (!_clientTimers.containsKey(clientId)) {
      _clientTimers[clientId] = [];
    }
    _clientTimers[clientId]!.add(t);
  }
}
