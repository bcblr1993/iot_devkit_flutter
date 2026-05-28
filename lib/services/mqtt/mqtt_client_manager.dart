import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../../models/simulation_context.dart';
import '../../models/subscription_config.dart';

/// Max characters of inbound MQTT payload to surface in the log; longer
/// payloads are tail-truncated with a "... +N bytes" marker so the log dock
/// doesn't choke on a 100KB shared-attributes blob.
const int _inboundPayloadLogLimit = 1024;

class MqttClientManager {
  final _logger = Logger('MqttClientManager');

  // Active Clients
  final Map<String, MqttServerClient> _clients = {};

  // Per-client inbound message stream subscription (so we can cancel cleanly).
  final Map<String, StreamSubscription> _messageSubscriptions = {};

  // Subscriptions applied to every (re)connected client. Set via
  // [setSubscriptions] before / during start. Immutable snapshot.
  List<SubscriptionConfig> _subscriptions = const <SubscriptionConfig>[];

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
  final Function(String clientId, Object error)? onConnectionFailed;
  final Function(String clientId, int attempt, Duration delay)?
      onReconnectScheduled;
  final Function(String message, String type, {String? tag}) onLog;

  MqttClientManager({
    required this.onConnected,
    required this.onDisconnected,
    this.onConnectionFailed,
    this.onReconnectScheduled,
    required this.onLog,
  });

  bool get hasActiveClients => _clients.isNotEmpty;
  int get activeClientCount => _clients.length;
  int get trackedClientCount => _clientConfigs.length;

  /// Snapshot of the active subscription list (for diagnostics / tests).
  List<SubscriptionConfig> get subscriptions =>
      List.unmodifiable(_subscriptions);

  /// Replace the subscription set. Newly-connected clients (including
  /// reconnects) will pick up the new list. Already-connected clients are
  /// **not** retroactively re-subscribed in this version — restart the
  /// simulation if you change topics while running.
  void setSubscriptions(List<SubscriptionConfig> subs) {
    _subscriptions = List.unmodifiable(
      subs.where((s) => s.enabled && s.topic.trim().isNotEmpty),
    );
  }

  SimulationContext? getClientContext(String clientId) {
    return _clientConfigs[clientId]?['context'] as SimulationContext?;
  }

  void forEachClient(
      void Function(String clientId, MqttServerClient client) action) {
    _clients.forEach(action);
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
    String protocolVersion = 'mqtt_3_1_1',
  }) async {
    // Store config for reconnection. The map instance is also the generation
    // token for this async connect attempt.
    final clientConfig = <String, dynamic>{
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
      'protocolVersion': protocolVersion,
    };
    _clientConfigs[clientId] = clientConfig;

    // Ensure old client is cleaned up if it exists
    // Ensure old client is cleaned up if it exists
    // Fix: Remove from map first to prevent _handleDisconnect from scheduling a reconnect
    _reconnectTimers[clientId]?.cancel();
    _reconnectTimers.remove(clientId);

    if (_clients.containsKey(clientId)) {
      _logger.info('[$clientId] Force replacing existing client');
      final oldClient = _clients.remove(clientId); // Remove first
      try {
        oldClient
            ?.disconnect(); // This triggers _handleDisconnect, but map is empty/different
      } catch (_) {}

      // Ensure UI knows it's disconnected (though we are about to reconnect)
      // onDisconnected(clientId);
    }

    final client = MqttServerClient(host, clientId);
    client.port = port;
    client.connectTimeoutPeriod = 3000;
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
        if (certPath != null &&
            certPath.isNotEmpty &&
            keyPath != null &&
            keyPath.isNotEmpty) {
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

    final connMess = _applyProtocolVersion(
      MqttConnectMessage().withClientIdentifier(clientId),
      protocolVersion,
    ).authenticateAs(username, password).startClean();
    client.connectionMessage = connMess;

    client.onDisconnected = () {
      _handleDisconnect(clientId, client);
    };

    try {
      await client.connect();
    } catch (e) {
      if (!identical(_clientConfigs[clientId], clientConfig)) {
        _disconnectQuietly(client);
        return;
      }
      _handleConnectionFailure(clientId, e);
      return;
    }

    if (!identical(_clientConfigs[clientId], clientConfig)) {
      _disconnectQuietly(client);
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      _handleConnectionSuccess(clientId, client);
    } else {
      _handleConnectionFailure(
          clientId, 'Status: ${client.connectionStatus!.state}');
    }
  }

  void _disconnectQuietly(MqttServerClient client) {
    try {
      client.disconnect();
    } catch (_) {}
  }

  void _handleConnectionSuccess(String clientId, MqttServerClient client) {
    _clients[clientId] = client;
    _reconnectAttempts[clientId] = 0; // Reset retries
    onConnected(clientId, client);
    onLog('[$clientId] Connected', 'success', tag: _getTag(clientId));
    _applySubscriptionsTo(clientId, client);
  }

  /// Wire inbound messages to the log channel and register every enabled
  /// subscription on this freshly-connected client.
  void _applySubscriptionsTo(String clientId, MqttServerClient client) {
    // 1) inbound stream listener — replace any stale one for this clientId.
    unawaited(_messageSubscriptions.remove(clientId)?.cancel());
    final updates = client.updates;
    if (updates != null) {
      _messageSubscriptions[clientId] = updates.listen(
        (events) => _handleInboundMessages(clientId, client, events),
        onError: (Object e) => onLog(
          '[$clientId] Subscription stream error: $e',
          'warning',
          tag: _getTag(clientId),
        ),
      );
    }

    // 2) subscribe each enabled topic; failures are logged but non-fatal so
    //    one bad row can't take down the whole client.
    for (final sub in _subscriptions) {
      try {
        client.subscribe(sub.topic, _toMqttQos(sub.qos));
        onLog(
          '[$clientId] Subscribed: ${sub.topic} (QoS ${sub.qos})',
          'info',
          tag: _getTag(clientId),
        );
      } catch (e) {
        onLog(
          '[$clientId] Subscribe failed for ${sub.topic}: $e',
          'warning',
          tag: _getTag(clientId),
        );
      }
    }
  }

  void _handleInboundMessages(
    String clientId,
    MqttServerClient client,
    List<MqttReceivedMessage<MqttMessage?>> events,
  ) {
    for (final event in events) {
      final msg = event.payload;
      if (msg is! MqttPublishMessage) continue;
      final raw = MqttPublishPayload.bytesToStringAsString(msg.payload.message);
      final payload = raw.length > _inboundPayloadLogLimit
          ? '${raw.substring(0, _inboundPayloadLogLimit)}... +${raw.length - _inboundPayloadLogLimit} bytes'
          : raw;
      onLog(
        '[$clientId] [← ${event.topic}] $payload',
        'info',
        tag: _getTag(clientId),
      );
      _maybeAutoAck(clientId, client, event.topic);
    }
  }

  /// If any enabled subscription targets the ThingsBoard RPC request filter
  /// with `autoAck == true`, publish an empty `{}` to the matching response
  /// topic on the same client. Logged as `[→ response/<id>]`.
  /// Failures are non-fatal: we just log a warning.
  void _maybeAutoAck(
    String clientId,
    MqttServerClient client,
    String requestTopic,
  ) {
    SubscriptionConfig? autoAck;
    for (final s in _subscriptions) {
      if (s.autoAck && s.isThingsBoardRpcFilter && s.enabled) {
        autoAck = s;
        break;
      }
    }
    if (autoAck == null) return;

    final responseTopic = rpcResponseTopicFor(requestTopic);
    if (responseTopic == null) return;

    try {
      final builder = MqttClientPayloadBuilder()..addString('{}');
      client.publishMessage(responseTopic, _toMqttQos(autoAck.qos),
          builder.payload!);
      onLog(
        '[$clientId] [→ $responseTopic] {} (auto-ack)',
        'info',
        tag: _getTag(clientId),
      );
    } catch (e) {
      onLog(
        '[$clientId] Auto-ack publish failed for $responseTopic: $e',
        'warning',
        tag: _getTag(clientId),
      );
    }
  }

  /// Maps a ThingsBoard RPC request topic to its response counterpart.
  ///
  ///   v1/devices/me/rpc/request/42   → v1/devices/me/rpc/response/42
  ///
  /// Returns `null` when:
  ///   · topic does not start with the RPC request prefix
  ///   · the id segment is empty
  ///   · the id segment contains a `/` (multi-segment, invalid for TB RPC)
  ///
  /// Exposed as a top-level static so unit tests don't need a live client.
  static String? rpcResponseTopicFor(String requestTopic) {
    const prefix = 'v1/devices/me/rpc/request/';
    if (!requestTopic.startsWith(prefix)) return null;
    final id = requestTopic.substring(prefix.length);
    if (id.isEmpty || id.contains('/')) return null;
    return 'v1/devices/me/rpc/response/$id';
  }

  static MqttQos _toMqttQos(int qos) {
    switch (qos) {
      case 2:
        return MqttQos.exactlyOnce;
      case 1:
        return MqttQos.atLeastOnce;
      case 0:
      default:
        return MqttQos.atMostOnce;
    }
  }

  void _handleConnectionFailure(String clientId, dynamic error) {
    onLog('[$clientId] Connection failed: $error', 'error',
        tag: _getTag(clientId));
    onConnectionFailed?.call(clientId, error);
    _scheduleReconnect(clientId);
  }

  void _handleDisconnect(String clientId, MqttServerClient client) {
    // Identity Check: Only handle if THIS client is the currently active one
    if (_clients[clientId] == client) {
      _clients.remove(clientId);
      unawaited(_messageSubscriptions.remove(clientId)?.cancel());
      onDisconnected(clientId);
      onLog('[$clientId] Disconnected, will retry...', 'warning',
          tag: _getTag(clientId));
      _scheduleReconnect(clientId);
    } else {
      // Logic: Client mismatch (replaced or removed already). Do not reconnect.
    }
  }

  void _scheduleReconnect(String clientId) {
    if (!_clientConfigs.containsKey(clientId)) return;

    int attempts = _reconnectAttempts[clientId] ?? 0;

    // Infinite retry: no max attempts check

    _reconnectTimers[clientId]?.cancel();

    int delayMs = (_baseReconnectDelayMs * (1 << attempts.clamp(0, 5)))
        .clamp(0, _maxReconnectDelayMs);
    _reconnectAttempts[clientId] = attempts + 1;

    onLog('Reconnecting in ${delayMs ~/ 1000}s (attempt ${attempts + 1})...',
        'warning',
        tag: _getTag(clientId));
    onReconnectScheduled?.call(
      clientId,
      attempts + 1,
      Duration(milliseconds: delayMs),
    );

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
        protocolVersion: config['protocolVersion'] ?? 'mqtt_3_1_1',
      );
    });
  }

  MqttConnectMessage _applyProtocolVersion(
    MqttConnectMessage message,
    String protocolVersion,
  ) {
    switch (protocolVersion) {
      case 'mqtt_3_1':
        return message
            .withProtocolName(MqttClientConstants.mqttV31ProtocolName)
            .withProtocolVersion(MqttClientConstants.mqttV31ProtocolVersion);
      case 'mqtt_3_1_1':
      default:
        return message
            .withProtocolName(MqttClientConstants.mqttV311ProtocolName)
            .withProtocolVersion(MqttClientConstants.mqttV311ProtocolVersion);
    }
  }

  Future<void> stopAll() async {
    _logger.info('Stopping all clients...');

    // 1. Clear configs to prevent reconnects
    for (var timer in _reconnectTimers.values) {
      timer?.cancel();
    }
    _reconnectTimers.clear();
    _reconnectAttempts.clear();
    _clientConfigs.clear();

    // 1b. Cancel every inbound message stream subscription
    for (final sub in _messageSubscriptions.values) {
      unawaited(sub.cancel());
    }
    _messageSubscriptions.clear();

    // 2. Disconnect clients safely
    // Create a copy of values to avoid concurrent modification issues during iteration
    final clientsToDisconnect = List<MqttServerClient>.from(_clients.values);

    // Clear the map immediately so callbacks know we are shutting down
    _clients.clear();

    for (final client in clientsToDisconnect) {
      try {
        // Prevent callback from triggering logic if possible, or let it trigger but find nothing in _clients
        // We already cleared _clients, so _handleDisconnect will see map mismatch and do nothing.
        client.disconnect();
      } catch (e) {
        _logger.warning('Error disconnecting client', e);
      }
    }
  }

  // ignore: unused_element
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
