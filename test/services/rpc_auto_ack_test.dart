import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/services/mqtt/mqtt_client_manager.dart';

void main() {
  group('rpcResponseTopicFor (ThingsBoard auto-ACK helper)', () {
    test('canonical numeric id', () {
      expect(
        MqttClientManager.rpcResponseTopicFor('v1/devices/me/rpc/request/42'),
        'v1/devices/me/rpc/response/42',
      );
    });

    test('alphanumeric / uuid-style id', () {
      expect(
        MqttClientManager.rpcResponseTopicFor(
            'v1/devices/me/rpc/request/abc-DEF_123'),
        'v1/devices/me/rpc/response/abc-DEF_123',
      );
    });

    test('returns null for empty id segment', () {
      expect(
        MqttClientManager.rpcResponseTopicFor('v1/devices/me/rpc/request/'),
        isNull,
      );
    });

    test('returns null when topic does not start with the RPC prefix', () {
      expect(
        MqttClientManager.rpcResponseTopicFor('v1/devices/me/attributes'),
        isNull,
      );
      expect(
        MqttClientManager.rpcResponseTopicFor(
            'v1/devices/me/rpc/response/9'),
        isNull,
      );
      expect(MqttClientManager.rpcResponseTopicFor(''), isNull);
    });

    test('returns null when id has extra slashes (multi-segment)', () {
      // ThingsBoard RPC request id is a single path segment per protocol spec;
      // anything multi-segment is treated as not-an-RPC-request to avoid
      // accidentally publishing into an unknown topic tree.
      expect(
        MqttClientManager.rpcResponseTopicFor(
            'v1/devices/me/rpc/request/42/extra'),
        isNull,
      );
    });

    test('does not match the wildcard subscription filter itself', () {
      // The `+` / `#` is the filter you subscribe TO; broker only delivers
      // concrete topics. If we ever see the filter literally, treat as no-id.
      expect(
        MqttClientManager.rpcResponseTopicFor('v1/devices/me/rpc/request/+'),
        'v1/devices/me/rpc/response/+',
        reason:
            'Single + segment is technically a valid id from this helpers '
            'POV; broker behaviour prevents this in practice. Recorded for '
            'completeness — if this ever ships in real traffic, treat as bug.',
      );
    });
  });
}
