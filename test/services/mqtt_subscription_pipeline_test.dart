import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/models/subscription_config.dart';
import 'package:iot_devkit/services/mqtt/mqtt_client_manager.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Covers the inbound-message pipeline that turns a received MQTT message into
/// a log line and (for ThingsBoard RPC) an auto-ack publish — without needing
/// a live broker. This is the "simulate a subscription receiving messages"
/// correctness suite.
void main() {
  const rpcRequest = 'v1/devices/me/rpc/request/42';
  const rpcResponse = 'v1/devices/me/rpc/response/42';
  const attributes = 'v1/devices/me/attributes';

  test('performance logging disables hidden MQTT payload formatting', () {
    final client = MqttServerClient('127.0.0.1', 'logging_regression');
    client.logging(on: false); // mqtt_client defaults logPayloads back to true.
    expect(MqttLogger.logPayloads, isTrue);

    MqttClientManager.disableLibraryLogging(client);

    expect(MqttLogger.loggingOn, isFalse);
    expect(MqttLogger.logPayloads, isFalse);
  });

  group('effectiveSubscriptions (what actually reaches the broker)', () {
    test('drops disabled rows', () {
      final result = MqttClientManager.effectiveSubscriptions([
        SubscriptionConfig(topic: 'a', enabled: true),
        SubscriptionConfig(topic: 'b', enabled: false),
      ]);
      expect(result.map((s) => s.topic), ['a']);
    });

    test('drops blank / whitespace-only topics', () {
      final result = MqttClientManager.effectiveSubscriptions([
        SubscriptionConfig(topic: ''),
        SubscriptionConfig(topic: '   '),
        SubscriptionConfig(topic: 'real/topic'),
      ]);
      expect(result.map((s) => s.topic), ['real/topic']);
    });

    test('keeps enabled rows with valid topics', () {
      final result = MqttClientManager.effectiveSubscriptions([
        SubscriptionConfig.thingsboardRpcPreset(),
        SubscriptionConfig.thingsboardAttributesPreset(),
      ]);
      expect(result.length, 2);
    });

    test('empty input → empty output', () {
      expect(MqttClientManager.effectiveSubscriptions(const []), isEmpty);
    });
  });

  group('formatInboundPayload (log truncation)', () {
    test('short payload passes through unchanged', () {
      expect(
        MqttClientManager.formatInboundPayload('{"a":1}'),
        '{"a":1}',
      );
    });

    test('payload exactly at the limit is not truncated', () {
      final exact = 'x' * 1024;
      expect(MqttClientManager.formatInboundPayload(exact), exact);
    });

    test('oversized payload is tail-truncated with a byte-count marker', () {
      final big = 'y' * 1500;
      final out = MqttClientManager.formatInboundPayload(big);
      expect(out.startsWith('y' * 1024), isTrue);
      expect(out, contains('... +476 bytes'));
      // Truncated form must be shorter than the original blob.
      expect(out.length, lessThan(big.length));
    });
  });

  group('decideInbound (receive → log + auto-ack decision)', () {
    SubscriptionConfig rpc(
            {bool autoAck = true, bool enabled = true, int qos = 1}) =>
        SubscriptionConfig(
          topic: 'v1/devices/me/rpc/request/+',
          autoAck: autoAck,
          enabled: enabled,
          qos: qos,
        );

    test('RPC request + auto-ack ON → acks the matching response topic', () {
      final action = MqttClientManager.decideInbound(
        [rpc(qos: 2)],
        rpcRequest,
        '{"method":"setGpioStatus","params":{"pin":7}}',
      );
      expect(action.autoAckTopic, rpcResponse);
      expect(action.autoAckQos, 2, reason: 'auto-ack mirrors the sub QoS');
      expect(action.displayPayload, contains('setGpioStatus'));
    });

    test('RPC request + auto-ack OFF → log only, no ack', () {
      final action = MqttClientManager.decideInbound(
        [rpc(autoAck: false)],
        rpcRequest,
        '{}',
      );
      expect(action.autoAckTopic, isNull);
    });

    test('RPC request but sub disabled → no ack', () {
      final action = MqttClientManager.decideInbound(
        [rpc(enabled: false)],
        rpcRequest,
        '{}',
      );
      expect(action.autoAckTopic, isNull);
    });

    test('non-RPC topic (attributes) never acks even with RPC auto-ack sub',
        () {
      final action = MqttClientManager.decideInbound(
        [
          rpc(),
          SubscriptionConfig.thingsboardAttributesPreset(),
        ],
        attributes,
        '{"shared":{"x":1}}',
      );
      expect(action.autoAckTopic, isNull,
          reason: 'attributes topic has no RPC response mapping');
      expect(action.displayPayload, contains('shared'));
    });

    test('attributes-only subscription → log only', () {
      final action = MqttClientManager.decideInbound(
        [SubscriptionConfig.thingsboardAttributesPreset()],
        attributes,
        '{"shared":{"threshold":80}}',
      );
      expect(action.autoAckTopic, isNull);
    });

    test('empty subscription list → log only', () {
      final action =
          MqttClientManager.decideInbound(const [], rpcRequest, '{}');
      expect(action.autoAckTopic, isNull);
    });

    test('different RPC request id maps to the matching response id', () {
      final action = MqttClientManager.decideInbound(
        [rpc()],
        'v1/devices/me/rpc/request/abc-123',
        '{}',
      );
      expect(action.autoAckTopic, 'v1/devices/me/rpc/response/abc-123');
    });

    test('oversized inbound payload is truncated in the log portion', () {
      final action = MqttClientManager.decideInbound(
        [rpc()],
        rpcRequest,
        'z' * 2000,
      );
      expect(action.displayPayload, contains('... +976 bytes'));
      expect(action.autoAckTopic, rpcResponse,
          reason: 'truncation must not affect the ack decision');
    });
  });

  group('processInbound wiring (log + publish side effects)', () {
    late List<String> logs;
    late MqttClientManager manager;
    late MqttServerClient client;

    setUp(() {
      logs = [];
      manager = MqttClientManager(
        onConnected: (_, __) {},
        onDisconnected: (_) {},
        onLog: (msg, type, {tag}) => logs.add('$type|$msg'),
      );
      // Unconnected client — never touched because we install a publish stub.
      client = MqttServerClient('localhost', 'test-client');
    });

    test('RPC request with auto-ack: logs receipt AND publishes empty response',
        () {
      manager.setSubscriptions([
        SubscriptionConfig.thingsboardRpcPreset(), // autoAck on, qos 1
      ]);

      final published = <String>[];
      MqttQos? publishedQos;
      manager.debugPublishOverride = (topic, qos) {
        published.add(topic);
        publishedQos = qos;
      };

      manager.processInbound(
        'device1',
        client,
        rpcRequest,
        '{"method":"reboot"}',
      );

      // 1) inbound logged with the ← arrow + topic + payload
      expect(
        logs.any((l) => l.contains('[← $rpcRequest]') && l.contains('reboot')),
        isTrue,
        reason: 'inbound message should be logged: $logs',
      );
      // 2) auto-ack published to the response topic at the sub's QoS
      expect(published, [rpcResponse]);
      expect(publishedQos, MqttQos.atLeastOnce);
      // 3) auto-ack logged with the → arrow
      expect(
        logs.any(
            (l) => l.contains('[→ $rpcResponse]') && l.contains('auto-ack')),
        isTrue,
        reason: 'auto-ack publish should be logged: $logs',
      );
    });

    test('attributes message: logs receipt but never publishes', () {
      manager.setSubscriptions([
        SubscriptionConfig.thingsboardRpcPreset(),
        SubscriptionConfig.thingsboardAttributesPreset(),
      ]);

      var publishCount = 0;
      manager.debugPublishOverride = (_, __) => publishCount++;

      manager.processInbound(
        'device1',
        client,
        attributes,
        '{"shared":{"x":1}}',
      );

      expect(
        logs.any((l) => l.contains('[← $attributes]')),
        isTrue,
      );
      expect(publishCount, 0, reason: 'attributes must not trigger auto-ack');
    });

    test('RPC request with auto-ack disabled: logs receipt, no publish', () {
      manager.setSubscriptions([
        SubscriptionConfig(
          topic: 'v1/devices/me/rpc/request/+',
          autoAck: false,
        ),
      ]);

      var publishCount = 0;
      manager.debugPublishOverride = (_, __) => publishCount++;

      manager.processInbound('device1', client, rpcRequest, '{}');

      expect(logs.any((l) => l.contains('[← $rpcRequest]')), isTrue);
      expect(publishCount, 0);
    });
  });
}
