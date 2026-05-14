import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/models/simulation_context.dart';
import 'package:iot_devkit/services/mqtt/mqtt_client_manager.dart';
import 'package:iot_devkit/services/mqtt_controller.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  test('stop during startup releases busy state and cancels upload start',
      () async {
    final controller = MqttController(
      initializeWorkers: false,
      stabilizationDelay: const Duration(milliseconds: 50),
    );
    addTearDown(controller.dispose);

    final startFuture = controller.start(_zeroDeviceConfig());
    await Future<void>.delayed(Duration.zero);

    expect(controller.isBusy, isTrue);
    expect(controller.isRunning, isTrue);
    expect(controller.isStarting, isTrue);
    expect(controller.runState, SimulationRunState.connecting);

    await controller.stop().timeout(const Duration(milliseconds: 200));

    expect(controller.isBusy, isFalse);
    expect(controller.isRunning, isFalse);
    expect(controller.isStarting, isFalse);
    expect(controller.isStopping, isFalse);
    expect(controller.runState, SimulationRunState.idle);

    await startFuture.timeout(const Duration(seconds: 1));

    expect(controller.isBusy, isFalse);
    expect(controller.isRunning, isFalse);
    expect(controller.runState, SimulationRunState.idle);
  });

  test('connection failure transitions to reconnecting state', () async {
    final controller = MqttController(
      initializeWorkers: false,
      stabilizationDelay: Duration.zero,
    );
    addTearDown(controller.dispose);

    await controller
        .start(_oneDeviceConfig(port: 1))
        .timeout(const Duration(seconds: 5));

    expect(controller.isBusy, isFalse);
    expect(controller.isRunning, isTrue);
    expect(controller.runState, SimulationRunState.reconnecting);
    expect(controller.runStateMessage, contains('Reconnecting'));

    await controller.stop().timeout(const Duration(milliseconds: 500));
    expect(controller.runState, SimulationRunState.idle);
  });

  test('partial connection success transitions to partialRunning state',
      () async {
    late _FakeMqttClientManager fakeManager;
    final controller = MqttController(
      initializeWorkers: false,
      stabilizationDelay: Duration.zero,
      clientManagerFactory: ({
        required onConnected,
        required onDisconnected,
        onConnectionFailed,
        onReconnectScheduled,
        required onLog,
      }) {
        fakeManager = _FakeMqttClientManager(
          onConnected: onConnected,
          onDisconnected: onDisconnected,
          onConnectionFailed: onConnectionFailed,
          onReconnectScheduled: onReconnectScheduled,
          onLog: onLog,
          successfulClientIds: {'device1'},
        );
        return fakeManager;
      },
    );
    addTearDown(controller.dispose);

    await controller
        .start(_twoDeviceConfig())
        .timeout(const Duration(milliseconds: 500));

    expect(fakeManager.trackedClientCount, 2);
    expect(fakeManager.activeClientCount, 1);
    expect(controller.isRunning, isTrue);
    expect(controller.isBusy, isFalse);
    expect(controller.runState, SimulationRunState.partialRunning);
    expect(controller.runStateMessage, contains('1/2'));

    await controller.stop().timeout(const Duration(milliseconds: 500));
  });

  test('stop timeout still resets state to idle', () async {
    final stopCompleter = Completer<void>();
    final controller = MqttController(
      initializeWorkers: false,
      stabilizationDelay: const Duration(milliseconds: 50),
      stopTimeout: const Duration(milliseconds: 10),
      clientManagerFactory: ({
        required onConnected,
        required onDisconnected,
        onConnectionFailed,
        onReconnectScheduled,
        required onLog,
      }) {
        return _FakeMqttClientManager(
          onConnected: onConnected,
          onDisconnected: onDisconnected,
          onConnectionFailed: onConnectionFailed,
          onReconnectScheduled: onReconnectScheduled,
          onLog: onLog,
          stopFuture: stopCompleter.future,
        );
      },
    );
    addTearDown(controller.dispose);

    final startFuture = controller.start(_zeroDeviceConfig());
    await Future<void>.delayed(Duration.zero);

    await controller.stop().timeout(const Duration(milliseconds: 200));
    await startFuture.timeout(const Duration(milliseconds: 500));

    expect(controller.isRunning, isFalse);
    expect(controller.isBusy, isFalse);
    expect(controller.runState, SimulationRunState.idle);

    stopCompleter.complete();
  });
}

Map<String, dynamic> _zeroDeviceConfig() {
  return {
    'mode': 'basic',
    'device_start_number': 1,
    'device_end_number': 0,
    'client_id_prefix': 'device',
    'username_prefix': 'user',
    'password_prefix': 'pass',
    'send_interval': 1,
    'mqtt': {
      'host': 'localhost',
      'port': 1883,
      'topic': 'v1/devices/me/telemetry',
      'qos': 0,
      'enable_ssl': false,
    },
    'data': {
      'format': 'default',
      'data_point_count': 1,
    },
    'custom_keys': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _oneDeviceConfig({required int port}) {
  return {
    'mode': 'basic',
    'device_start_number': 1,
    'device_end_number': 1,
    'client_id_prefix': 'device',
    'username_prefix': 'user',
    'password_prefix': 'pass',
    'send_interval': 1,
    'mqtt': {
      'host': '127.0.0.1',
      'port': port,
      'topic': 'v1/devices/me/telemetry',
      'qos': 0,
      'enable_ssl': false,
    },
    'data': {
      'format': 'default',
      'data_point_count': 1,
    },
    'custom_keys': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _twoDeviceConfig() {
  final config = _oneDeviceConfig(port: 1883);
  config['device_end_number'] = 2;
  return config;
}

class _FakeMqttClientManager extends MqttClientManager {
  final Set<String> successfulClientIds;
  final Future<void>? stopFuture;
  final Map<String, SimulationContext> _contexts = {};
  final Map<String, MqttServerClient> _clients = {};
  final Set<String> _trackedClientIds = {};

  _FakeMqttClientManager({
    required super.onConnected,
    required super.onDisconnected,
    super.onConnectionFailed,
    super.onReconnectScheduled,
    required super.onLog,
    this.successfulClientIds = const {},
    this.stopFuture,
  });

  @override
  int get activeClientCount => _clients.length;

  @override
  int get trackedClientCount => _trackedClientIds.length;

  @override
  SimulationContext? getClientContext(String clientId) => _contexts[clientId];

  @override
  void forEachClient(
    void Function(String clientId, MqttServerClient client) action,
  ) {
    _clients.forEach(action);
  }

  @override
  Future<void> createClient({
    required String host,
    required int port,
    required String clientId,
    required String username,
    required String password,
    required String topic,
    required SimulationContext context,
    bool enableSsl = false,
    String? caPath,
    String? certPath,
    String? keyPath,
  }) async {
    _trackedClientIds.add(clientId);
    _contexts[clientId] = context;

    if (successfulClientIds.contains(clientId)) {
      final client = MqttServerClient(host, clientId);
      _clients[clientId] = client;
      onConnected(clientId, client);
      return;
    }

    onConnectionFailed?.call(clientId, 'fake failure');
    onReconnectScheduled?.call(clientId, 1, const Duration(seconds: 2));
  }

  @override
  Future<void> stopAll() async {
    _trackedClientIds.clear();
    _contexts.clear();
    _clients.clear();
    if (stopFuture != null) {
      await stopFuture;
    }
  }
}
