import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../../models/simulation_context.dart';

class MqttClientManager {
  final _logger = Logger('MqttClientManager');
  
  // Active Clients
  final Map<String, MqttServerClient> _clients = {};
  
  // Reconnection Logic
  final Map<String, Map<String, dynamic>> _clientConfigs = {};
  final Map<String, int> _reconnectAttempts = {};
  final Map<String, Timer?> _reconnectTimers = {};
  static const int _baseReconnectDelayMs = 2000;
  static const int _maxReconnectDelayMs = 30000;
  // static const int _maxReconnectAttempts = 5; // Removed for infinite retry

  // Callbacks
  final Function(String clientId, MqttServerClient client) onConnected;
  final Function(String clientId) onDisconnected;
  final Function(String message, String type, {String? tag}) onLog;

  MqttClientManager({
    required this.onConnected,
    required this.onDisconnected,
    required this.onLog,
  });

  bool get hasActiveClients => _clients.isNotEmpty;
  int get activeClientCount => _clients.length;

  SimulationContext? getClientContext(String clientId) {
    return _clientConfigs[clientId]?['context'] as SimulationContext?;
  }

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
    // Store config for reconnection
    _clientConfigs[clientId] = {
      'host': host,
      'port': port,
      'clientId': clientId,
      'username': username,
      'password': password,
      'topic': topic,
      'context': context,
      'enableSsl': enableSsl,
      'caPath': caPath,
      'certPath': certPath,
      'keyPath': keyPath,
    };

    // Ensure old client is cleaned up if it exists
    // Ensure old client is cleaned up if it exists
    if (_clients.containsKey(clientId)) {
      _logger.info('[$clientId] Force replacing existing client');
      try {
        _clients[clientId]?.disconnect();
      } catch (_) {}
      
      // CRITICAL FIX: Manually trigger cleanup because _handleDisconnect checks for map presence,
      // which we are about to remove. We must ensure onDisconnected is called to stop Schedulers.
      onDisconnected(clientId);
      _clients.remove(clientId);
    }

    final client = MqttServerClient(host, clientId);
    client.port = port;
    client.keepAlivePeriod = 60;
    client.logging(on: false);
    client.autoReconnect = false; // Manual handling
    
    if (enableSsl) {
      client.secure = true;
      client.securityContext = SecurityContext.defaultContext;
      
      try {
        if (caPath != null && caPath.isNotEmpty) {
           client.securityContext.setTrustedCertificates(caPath);
        }
        if (certPath != null && certPath.isNotEmpty && keyPath != null && keyPath.isNotEmpty) {
           client.securityContext.useCertificateChain(certPath);
           client.securityContext.usePrivateKey(keyPath);
        }
      } catch (e) {
        onLog('SSL Configuration Error: $e', 'error', tag: _getTag(clientId));
        // We might want to stop here, but let's try connecting or fail during connect
      }
    } else {
      client.secure = false;
    }

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(username, password)
        .startClean();
    client.connectionMessage = connMess;

    client.onDisconnected = () {
      _handleDisconnect(clientId, client);
    };

    try {
      await client.connect();
    } catch (e) {
      _handleConnectionFailure(clientId, e);
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      _handleConnectionSuccess(clientId, client);
    } else {
      _handleConnectionFailure(clientId, 'Status: ${client.connectionStatus!.state}');
    }
  }

  void _handleConnectionSuccess(String clientId, MqttServerClient client) {
    _clients[clientId] = client;
    _reconnectAttempts[clientId] = 0; // Reset retries
    onConnected(clientId, client);
    onLog('[$clientId] Connected', 'success', tag: _getTag(clientId));
  }

  void _handleConnectionFailure(String clientId, dynamic error) {
    onLog('[$clientId] Connection failed: $error', 'error', tag: _getTag(clientId));
    _scheduleReconnect(clientId);
  }

  void _handleDisconnect(String clientId, MqttServerClient client) {
    if (_clients.containsKey(clientId)) {
      _clients.remove(clientId);
      onDisconnected(clientId);
      onLog('[$clientId] Disconnected, will retry...', 'warning', tag: _getTag(clientId));
      _scheduleReconnect(clientId);
    }
  }

  void _scheduleReconnect(String clientId) {
    if (!_clientConfigs.containsKey(clientId)) return;

    int attempts = _reconnectAttempts[clientId] ?? 0;

    // Infinite retry: no max attempts check
    
    _reconnectTimers[clientId]?.cancel();

    int delayMs = (_baseReconnectDelayMs * (1 << attempts.clamp(0, 5))).clamp(0, _maxReconnectDelayMs);
    _reconnectAttempts[clientId] = attempts + 1;

    onLog('Reconnecting in ${delayMs ~/ 1000}s (attempt ${attempts + 1})...', 'warning', tag: _getTag(clientId));

    _reconnectTimers[clientId] = Timer(Duration(milliseconds: delayMs), () {
      if (!_clientConfigs.containsKey(clientId)) return;
      final config = _clientConfigs[clientId]!;
      createClient(
        host: config['host'],
        port: config['port'],
        clientId: config['clientId'],
        username: config['username'],
        password: config['password'],
        topic: config['topic'],
        context: config['context'],
        enableSsl: config['enableSsl'] ?? false,
        caPath: config['caPath'],
        certPath: config['certPath'],
        keyPath: config['keyPath'],
      );
    });
  }

  Future<void> stopAll() async {
    // Cancel reconnect timers
    for (var timer in _reconnectTimers.values) {
      timer?.cancel();
    }
    _reconnectTimers.clear();
    _reconnectAttempts.clear();
    _clientConfigs.clear();

    // Disconnect clients
    for (var client in _clients.values) {
      try {
        client.disconnect();
      } catch (e) {
        _logger.warning('Error disconnecting client', e);
      }
    }
    _clients.clear();
  }

  void _cleanupClient(String clientId) {
    _reconnectTimers[clientId]?.cancel();
    _reconnectTimers.remove(clientId);
    _clientConfigs.remove(clientId);
    _reconnectAttempts.remove(clientId);
    _clients.remove(clientId);
    // Notify controller that this client is dead?
    onDisconnected(clientId); 
  }

  String _getTag(String clientId) {
    final config = _clientConfigs[clientId];
    if (config == null) return clientId;
    
    final context = config['context'];
    if (context is AdvancedSimulationContext) {
      return context.group.name;
    }
    return clientId;
  }
}
