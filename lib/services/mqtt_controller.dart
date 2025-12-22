import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../utils/statistics_collector.dart';
import '../models/group_config.dart';
import '../models/custom_key_config.dart';
import '../models/simulation_context.dart';
import 'data_generator.dart';
import 'mqtt/mqtt_client_manager.dart';
import 'mqtt/scheduler_service.dart';

class MqttController extends ChangeNotifier {
  final _logger = Logger('MqttController');
  
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  final StatisticsCollector statisticsCollector = StatisticsCollector();
  late final MqttClientManager _clientManager;
  late final SchedulerService _schedulerService;

  // Callback for logs (UI)
  Function(String message, String type, {String? tag})? onLog;

  MqttController() {
    _clientManager = MqttClientManager(
      onConnected: _onClientConnected,
      onDisconnected: _onClientDisconnected,
      onLog: log,
    );
    _schedulerService = SchedulerService(
      statisticsCollector: statisticsCollector,
      onLog: log,
    );
  }

  void log(String message, String type, {String? tag}) {
    // 1. Log to system logger
    Level level;
    switch (type) {
      case 'error':
        level = Level.SEVERE;
        break;
      case 'warning':
        level = Level.WARNING;
        break;
      case 'success':
        level = Level.INFO; 
        break;
      default:
        level = Level.INFO;
    }
    
    final String msg = tag != null ? '[$tag] $message' : message;
    _logger.log(level, msg);

    // 2. Notify UI
    if (onLog != null) {
      onLog!(message, type, tag: tag);
    }
  }

  // --- Public API ---

  Future<void> stop() async {
    if (!isRunning) return;
    
    _isRunning = false;
    notifyListeners();
    log('Stopping simulation...', 'info');

    _schedulerService.stopAll();
    await _clientManager.stopAll();

    log('Simulation stopped.', 'info');
  }

  Future<void> start(Map<String, dynamic> config) async {
    if (isRunning) {
      log('Simulation already running.', 'error');
      return;
    }

    _isRunning = true;
    notifyListeners();
    
    _schedulerService.reset();
    statisticsCollector.reset();
    
    // Determine Mode
    String mode = config['mode'] ?? 'basic';
    
    if (mode == 'basic') {
      await _startBasicMode(config);
    } else if (mode == 'advanced') {
      await _startAdvancedMode(config);
    } else {
      log('Unknown mode: $mode', 'error');
      stop();
    }
  }

  // --- Internal Start Logic ---

  Future<void> _startBasicMode(Map<String, dynamic> config) async {
    int startIdx = config['device_start_number'] ?? 1;
    int endIdx = config['device_end_number'] ?? 10;
    int total = endIdx - startIdx + 1;
    
    statisticsCollector.setTotalDevices(total);
    log('Starting Basic Mode: Devices $startIdx - $endIdx ($total total)', 'info');
    
    DataGenerator.resetKey1Counter();
    DataGenerator.resetCustomKeyCounters();
    
    String host = config['mqtt']['host'] ?? 'localhost';
    int port = config['mqtt']['port'] ?? 1883;
    String topic = config['mqtt']['topic'] ?? 'v1/devices/me/telemetry';
    
    // SSL Config
    bool enableSsl = config['mqtt']['enable_ssl'] ?? false;
    String? caPath = config['mqtt']['ca_path'];
    String? certPath = config['mqtt']['cert_path'];
    String? keyPath = config['mqtt']['key_path'];
    
    String clientIdPrefix = config['client_id_prefix'] ?? 'device';
    String userPrefix = config['username_prefix'] ?? 'user';
    String passPrefix = config['password_prefix'] ?? 'pass';
    
    // Prepare common config context
    // We need to pass protocol-specific config so Scheduler can use it.
    // In Basic Mode, each client shares the same interval/format/customKeys except for identity.
    // We'll store this in the context map.
    
    int sendInterval = config['send_interval'] ?? 1;
    String format = config['data']['format'] ?? 'default';
    int dataPointCount = config['data']['data_point_count'] ?? 10;
    List<CustomKeyConfig> customKeys = [];
    if (config['custom_keys'] != null && config['custom_keys'] is List) {
       customKeys = List<CustomKeyConfig>.from(config['custom_keys']);
    }

    for (int i = startIdx; i <= endIdx; i++) {
      if (!isRunning) break;

      String idxStr = i.toString().padLeft(1, '0');
      String clientId = '$clientIdPrefix$idxStr';
      String username = '$userPrefix$idxStr';
      String password = '$passPrefix$idxStr';

      final context = BasicSimulationContext(
        topic: topic,
        intervalSeconds: sendInterval,
        format: format,
        dataPointCount: dataPointCount,
        customKeys: customKeys
      );

      await _clientManager.createClient(
        host: host,
        port: port,
        clientId: clientId,
        username: username,
        password: password,
        topic: topic,
        context: context,
        enableSsl: enableSsl,
        caPath: caPath,
        certPath: certPath,
        keyPath: keyPath,
      );
      
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> _startAdvancedMode(Map<String, dynamic> config) async {
    List<dynamic> groupsRaw = config['groups'] ?? [];
    List<GroupConfig> groups = [];
    for (var g in groupsRaw) {
      if (g is GroupConfig) groups.add(g);
    }
    
    if (groups.isEmpty) {
      log('No groups configured for Advanced Mode.', 'warning');
      stop();
      return;
    }
    
    int total = groups.fold(0, (sum, g) => sum + (g.endDeviceNumber - g.startDeviceNumber + 1));
    statisticsCollector.setTotalDevices(total);
    log('Starting Advanced Mode: ${groups.length} Groups, $total Devices total.', 'info');
    
    DataGenerator.resetKey1Counter();
    DataGenerator.resetCustomKeyCounters();
    
    String host = config['mqtt']['host'] ?? 'localhost';
    int port = config['mqtt']['port'] ?? 1883;
    String topic = config['mqtt']['topic'] ?? 'v1/devices/me/telemetry';

    // SSL Config
    bool enableSsl = config['mqtt']['enable_ssl'] ?? false;
    String? caPath = config['mqtt']['ca_path'];
    String? certPath = config['mqtt']['cert_path'];
    String? keyPath = config['mqtt']['key_path'];

    for (var group in groups) {
      if (!isRunning) break;
      
      log('Starting Group: ${group.name}', 'info');
      
      for (int i = group.startDeviceNumber; i <= group.endDeviceNumber; i++) {
        if (!isRunning) break;

        String idxStr = i.toString(); 
        String clientId = '${group.clientIdPrefix}$idxStr';
        String username = '${group.usernamePrefix}$idxStr';
        String password = '${group.passwordPrefix}$idxStr';

        final context = AdvancedSimulationContext(
          topic: topic, 
          group: group
        );

        await _clientManager.createClient(
          host: host,
          port: port,
          clientId: clientId,
          username: username,
          password: password,
          topic: topic,
          context: context,
          enableSsl: enableSsl,
          caPath: caPath,
          certPath: certPath,
          keyPath: keyPath,
        );
        
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }
  }

  // --- Callbacks ---

  void _onClientConnected(String clientId, MqttServerClient client) {
    if (!isRunning) return;
    
    // Update stats
    statisticsCollector.setOnlineDevices(_clientManager.activeClientCount);
    
    // Start Scheduler
    final config = _clientManager.getClientContext(clientId);
    if (config != null) {
      _schedulerService.startPublishing(client, clientId, config);
    }
  }

  void _onClientDisconnected(String clientId) {
    statisticsCollector.setOnlineDevices(_clientManager.activeClientCount);
    _schedulerService.stopPublishing(clientId); // Stop scheduler for this client
  }
}
