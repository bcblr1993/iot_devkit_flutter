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
import '../utils/isolate_worker.dart';

enum SimulationRunState {
  idle,
  starting,
  connecting,
  running,
  reconnecting,
  partialRunning,
  stopping,
  failed,
}

typedef MqttClientManagerFactory = MqttClientManager Function({
  required void Function(String clientId, MqttServerClient client) onConnected,
  required void Function(String clientId) onDisconnected,
  void Function(String clientId, Object error)? onConnectionFailed,
  void Function(String clientId, int attempt, Duration delay)?
      onReconnectScheduled,
  required void Function(String message, String type, {String? tag}) onLog,
});

MqttClientManager _createDefaultMqttClientManager({
  required void Function(String clientId, MqttServerClient client) onConnected,
  required void Function(String clientId) onDisconnected,
  void Function(String clientId, Object error)? onConnectionFailed,
  void Function(String clientId, int attempt, Duration delay)?
      onReconnectScheduled,
  required void Function(String message, String type, {String? tag}) onLog,
}) {
  return MqttClientManager(
    onConnected: onConnected,
    onDisconnected: onDisconnected,
    onConnectionFailed: onConnectionFailed,
    onReconnectScheduled: onReconnectScheduled,
    onLog: onLog,
  );
}

class MqttController extends ChangeNotifier {
  final _logger = Logger('MqttController');
  final Duration _stabilizationDelay;
  final Duration _stopTimeout;

  SimulationRunState _runState = SimulationRunState.idle;
  SimulationRunState get runState => _runState;

  String? _runStateMessage;
  String? get runStateMessage => _runStateMessage;

  bool get isRunning {
    return switch (_runState) {
      SimulationRunState.starting ||
      SimulationRunState.connecting ||
      SimulationRunState.running ||
      SimulationRunState.reconnecting ||
      SimulationRunState.partialRunning ||
      SimulationRunState.stopping =>
        true,
      SimulationRunState.idle || SimulationRunState.failed => false,
    };
  }

  final StatisticsCollector statisticsCollector = StatisticsCollector();
  late final MqttClientManager _clientManager;
  late final SchedulerService _schedulerService;

  // Callback for logs (UI)
  Function(String message, String type, {String? tag})? onLog;

  // Performance: Global Log Switch
  bool get isBusy {
    return switch (_runState) {
      SimulationRunState.starting ||
      SimulationRunState.connecting ||
      SimulationRunState.stopping =>
        true,
      SimulationRunState.idle ||
      SimulationRunState.running ||
      SimulationRunState.reconnecting ||
      SimulationRunState.partialRunning ||
      SimulationRunState.failed =>
        false,
    };
  }

  bool get isStarting =>
      _runState == SimulationRunState.starting ||
      _runState == SimulationRunState.connecting;
  bool get isStopping => _runState == SimulationRunState.stopping;

  bool _enableDetailedLogs = true;
  bool get enableDetailedLogs => _enableDetailedLogs;

  void toggleDetailedLogs(bool value) {
    if (_enableDetailedLogs == value) return;
    _enableDetailedLogs = value;
    _schedulerService.enableLogs = value;

    // Log visible only in console/system log, not UI if disabled (optional, but keep system log generally)
    log('Detailed logging ${value ? 'ENABLED' : 'DISABLED'}', 'info');
    notifyListeners();
  }

  MqttController({
    bool initializeWorkers = true,
    Duration stabilizationDelay = const Duration(seconds: 3),
    Duration stopTimeout = const Duration(seconds: 3),
    MqttClientManagerFactory? clientManagerFactory,
  })  : _stabilizationDelay = stabilizationDelay,
        _stopTimeout = stopTimeout {
    final createClientManager =
        clientManagerFactory ?? _createDefaultMqttClientManager;
    _clientManager = createClientManager(
      onConnected: _onClientConnected,
      onDisconnected: _onClientDisconnected,
      onConnectionFailed: _onClientConnectionFailed,
      onReconnectScheduled: _onClientReconnectScheduled,
      onLog: log,
    );
    _schedulerService = SchedulerService(
      statisticsCollector: statisticsCollector,
      onLog: log,
    );
    if (initializeWorkers) {
      PersistentIsolateManager.instance.init();
    }
  }

  @override
  void dispose() {
    _schedulerService.stopAll();
    unawaited(_clientManager.stopAll());
    PersistentIsolateManager.instance.dispose();
    statisticsCollector.dispose();
    super.dispose();
  }

  void _setRunState(SimulationRunState state, {String? message}) {
    if (_runState == state && _runStateMessage == message) return;
    _runState = state;
    _runStateMessage = message;
    notifyListeners();
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

    // 2. Notify UI (Only if enabled)
    if (onLog != null && _enableDetailedLogs) {
      onLog!(message, type, tag: tag);
    }
  }

  // --- Public API ---

  Future<void>? _stopFuture;

  Future<void> stop() async {
    if (isStopping) {
      return _stopFuture ?? Future<void>.value();
    }
    if (!isRunning && !isBusy) return;

    _stopFuture = _stopInternal();
    return _stopFuture!;
  }

  Future<void> _stopInternal() async {
    _setRunState(
      SimulationRunState.stopping,
      message: 'Stopping simulation...',
    );
    _isInitializing = false;
    log('Stopping simulation...', 'info');

    try {
      _schedulerService.stopAll();
      await _clientManager.stopAll().timeout(
        _stopTimeout,
        onTimeout: () {
          log('Stop timed out while disconnecting MQTT clients. Forcing UI state reset.',
              'warning');
        },
      );
      log('Simulation stopped.', 'info');
    } catch (e) {
      log('Error during stop: $e', 'error');
    } finally {
      // Always ensure state is reset
      _stopFuture = null;
      statisticsCollector.setOnlineDevices(0);
      _setRunState(SimulationRunState.idle);
    }
  }

  // State for delayed start
  bool _isInitializing = false;

  Future<void> start(Map<String, dynamic> config) async {
    if (isRunning || isBusy) {
      log('Simulation already running.', 'error');
      return;
    }

    _isInitializing = true; // Block auto-start in onConnected
    _setRunState(
      SimulationRunState.starting,
      message: 'Preparing simulation...',
    );

    statisticsCollector.reset();

    try {
      // Determine Mode
      String mode = config['mode'] ?? 'basic';
      _setRunState(
        SimulationRunState.connecting,
        message: 'Connecting MQTT clients...',
      );

      // Phase 1: Connect All Devices
      if (mode == 'basic') {
        await _startBasicMode(config);
      } else if (mode == 'advanced') {
        await _startAdvancedMode(config);
      } else {
        log('Unknown mode: $mode', 'error');
        await stop();
        return;
      }

      // Phase 2: Stabilization Delay
      if (isRunning && !isStopping) {
        log('All devices connected. Waiting 3s for stabilization...', 'info');
        await Future.delayed(_stabilizationDelay);
        if (!isRunning || isStopping) return;

        // Phase 3: Start Data Upload
        log('Stabilization complete. Starting data upload...', 'info');
        _isInitializing = false;

        // Reset scheduler time to now (so data starts from t=0)
        _schedulerService.reset();

        _clientManager.forEachClient((clientId, client) {
          final ctx = _clientManager.getClientContext(clientId);
          if (ctx != null) {
            _schedulerService.startPublishing(client, clientId, ctx);
          }
        });
        _syncRunStateWithConnectivity();
      }
    } catch (e) {
      log('Error starting simulation: $e', 'error');
      _setRunState(
        SimulationRunState.failed,
        message: 'Error starting simulation: $e',
      );
    } finally {
      _isInitializing = false; // Ensure reset
      if (!isStopping && _runState != SimulationRunState.failed) {
        _syncRunStateWithConnectivity();
      }
    }
  }

  // --- Internal Start Logic ---

  Future<void> _startBasicMode(Map<String, dynamic> config) async {
    int startIdx = config['device_start_number'] ?? 1;
    int endIdx = config['device_end_number'] ?? 10;
    int total = endIdx - startIdx + 1;

    statisticsCollector.setTotalDevices(total);
    log('Starting Basic Mode: Devices $startIdx - $endIdx ($total total)',
        'info');

    DataGenerator.resetKey1Counter();
    DataGenerator.resetCustomKeyCounters();

    String host = config['mqtt']['host'] ?? 'localhost';
    int port = config['mqtt']['port'] ?? 1883;
    String topic = config['mqtt']['topic'] ?? 'v1/devices/me/telemetry';
    int qos = config['mqtt']['qos'] ?? 0;

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
      customKeys = (config['custom_keys'] as List)
          .map((e) => CustomKeyConfig.fromJson(e))
          .toList();
    }

    // Connect in batches to avoid overwhelming the system while staying fast
    const int batchSize = 10;
    for (int i = startIdx; i <= endIdx; i += batchSize) {
      if (!isRunning || isStopping) break;

      List<Future<void>> batch = [];
      for (int j = i; j < i + batchSize && j <= endIdx; j++) {
        String idxStr = j.toString();
        String clientId = '$clientIdPrefix$idxStr';
        String username = '$userPrefix$idxStr';
        String password = '$passPrefix$idxStr';

        final context = BasicSimulationContext(
            topic: topic,
            qos: qos,
            intervalSeconds: sendInterval,
            format: format,
            dataPointCount: dataPointCount,
            customKeys: customKeys);

        batch.add(_clientManager.createClient(
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
        ));
      }

      await Future.wait(batch);
      // Small pause between batches
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _startAdvancedMode(Map<String, dynamic> config) async {
    List<dynamic> groupsRaw = config['groups'] ?? [];
    List<GroupConfig> groups = [];
    for (var g in groupsRaw) {
      if (g is GroupConfig) {
        groups.add(g);
      } else if (g is Map<String, dynamic>) {
        groups.add(GroupConfig.fromJson(g));
      }
    }

    if (groups.isEmpty) {
      log('No groups configured for Advanced Mode.', 'warning');
      await stop();
      return;
    }

    int total = groups.fold(
        0, (sum, g) => sum + (g.endDeviceNumber - g.startDeviceNumber + 1));
    statisticsCollector.setTotalDevices(total);
    log('Starting Advanced Mode: ${groups.length} Groups, $total Devices total.',
        'info');

    DataGenerator.resetKey1Counter();
    DataGenerator.resetCustomKeyCounters();

    String host = config['mqtt']['host'] ?? 'localhost';
    int port = config['mqtt']['port'] ?? 1883;
    String topic = config['mqtt']['topic'] ?? 'v1/devices/me/telemetry';
    int qos = config['mqtt']['qos'] ?? 0;

    // SSL Config
    bool enableSsl = config['mqtt']['enable_ssl'] ?? false;
    String? caPath = config['mqtt']['ca_path'];
    String? certPath = config['mqtt']['cert_path'];
    String? keyPath = config['mqtt']['key_path'];

    const int batchSize = 5; // Smaller batch for advanced mode groups
    for (var group in groups) {
      if (!isRunning || isStopping) break;

      log('Starting Group: ${group.name}', 'info');

      for (int i = group.startDeviceNumber;
          i <= group.endDeviceNumber;
          i += batchSize) {
        if (!isRunning || isStopping) break;

        List<Future<void>> batch = [];
        for (int j = i; j < i + batchSize && j <= group.endDeviceNumber; j++) {
          String idxStr = j.toString();
          String clientId = '${group.clientIdPrefix}$idxStr';
          String username = '${group.usernamePrefix}$idxStr';
          String password = '${group.passwordPrefix}$idxStr';

          final context =
              AdvancedSimulationContext(topic: topic, qos: qos, group: group);

          batch.add(_clientManager.createClient(
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
          ));
        }

        await Future.wait(batch);
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  // --- Callbacks ---

  void _onClientConnected(String clientId, MqttServerClient client) {
    if (!isRunning) return;

    // Update stats
    statisticsCollector.setOnlineDevices(_clientManager.activeClientCount);

    // Start Scheduler
    // If initializing (Phase 1), do NOT start scheduler yet.
    if (_isInitializing) return;

    final config = _clientManager.getClientContext(clientId);
    if (config != null) {
      _schedulerService.startPublishing(client, clientId, config);
    }
    _syncRunStateWithConnectivity();
  }

  void _onClientDisconnected(String clientId) {
    statisticsCollector.setOnlineDevices(_clientManager.activeClientCount);
    _schedulerService
        .stopPublishing(clientId); // Stop scheduler for this client
    _syncRunStateWithConnectivity();
  }

  void _onClientConnectionFailed(String clientId, Object error) {
    if (!isRunning || isStopping) return;
    _syncRunStateWithConnectivity(
      fallbackMessage: 'Connection failed for $clientId: $error',
    );
  }

  void _onClientReconnectScheduled(
    String clientId,
    int attempt,
    Duration delay,
  ) {
    if (!isRunning || isStopping) return;
    _syncRunStateWithConnectivity(
      fallbackMessage:
          'Reconnecting $clientId in ${delay.inSeconds}s (attempt $attempt).',
    );
  }

  void _syncRunStateWithConnectivity({String? fallbackMessage}) {
    if (isStopping || _isInitializing) return;
    if (!isRunning && !isBusy) return;

    final activeClients = _clientManager.activeClientCount;
    final trackedClients = _clientManager.trackedClientCount;
    final totalDevices = statisticsCollector.totalDevices;
    final expectedClients = totalDevices > 0 ? totalDevices : trackedClients;

    if (expectedClients <= 0) {
      _setRunState(
        SimulationRunState.running,
        message: fallbackMessage ?? 'Simulation running.',
      );
      return;
    }

    if (activeClients <= 0 && trackedClients > 0) {
      _setRunState(
        SimulationRunState.reconnecting,
        message: fallbackMessage ?? 'All clients offline. Reconnecting...',
      );
      return;
    }

    if (activeClients < expectedClients) {
      _setRunState(
        SimulationRunState.partialRunning,
        message: fallbackMessage ??
            '$activeClients/$expectedClients clients online.',
      );
      return;
    }

    _setRunState(
      SimulationRunState.running,
      message: fallbackMessage ?? 'Simulation running.',
    );
  }
}
