import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/models/subscription_config.dart';

void main() {
  group('SubscriptionConfig', () {
    test('default constructor values', () {
      final s = SubscriptionConfig();
      expect(s.id, isNotEmpty);
      expect(s.topic, '');
      expect(s.qos, 1);
      expect(s.enabled, isTrue);
      expect(s.autoAck, isFalse);
      expect(s.label, isNull);
    });

    test('ThingsBoard RPC preset', () {
      final s = SubscriptionConfig.thingsboardRpcPreset();
      expect(s.topic, 'v1/devices/me/rpc/request/+');
      expect(s.qos, 1);
      expect(s.enabled, isTrue);
      expect(s.autoAck, isTrue);
      expect(s.label, 'ThingsBoard RPC');
      expect(s.isThingsBoardRpcFilter, isTrue);
    });

    test('ThingsBoard shared-attributes preset', () {
      final s = SubscriptionConfig.thingsboardAttributesPreset();
      expect(s.topic, 'v1/devices/me/attributes');
      expect(s.autoAck, isFalse,
          reason: 'auto-ack only applies to RPC requests');
      expect(s.isThingsBoardRpcFilter, isFalse);
    });

    test('isThingsBoardRpcFilter recognises + and # forms only', () {
      expect(
        SubscriptionConfig(topic: 'v1/devices/me/rpc/request/+')
            .isThingsBoardRpcFilter,
        isTrue,
      );
      expect(
        SubscriptionConfig(topic: 'v1/devices/me/rpc/request/#')
            .isThingsBoardRpcFilter,
        isTrue,
      );
      // Concrete id is NOT a filter — it's the inbound request topic itself.
      expect(
        SubscriptionConfig(topic: 'v1/devices/me/rpc/request/42')
            .isThingsBoardRpcFilter,
        isFalse,
      );
      expect(
        SubscriptionConfig(topic: 'v1/devices/me/attributes')
            .isThingsBoardRpcFilter,
        isFalse,
      );
    });

    test('toJson / fromJson roundtrip preserves id and all fields', () {
      final original = SubscriptionConfig(
        topic: 'a/b/c',
        qos: 2,
        enabled: false,
        autoAck: true,
        label: 'note',
      );
      final restored = SubscriptionConfig.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.topic, 'a/b/c');
      expect(restored.qos, 2);
      expect(restored.enabled, isFalse);
      expect(restored.autoAck, isTrue);
      expect(restored.label, 'note');
    });

    test('fromJson clamps qos to 0..2 range', () {
      expect(SubscriptionConfig.fromJson({'topic': 'x', 'qos': 7}).qos, 2);
      expect(SubscriptionConfig.fromJson({'topic': 'x', 'qos': -3}).qos, 0);
      expect(SubscriptionConfig.fromJson({'topic': 'x', 'qos': 1.0}).qos, 1);
      expect(SubscriptionConfig.fromJson({'topic': 'x'}).qos, 1,
          reason: 'missing qos defaults to TB default 1');
    });

    test('fromJson tolerates missing optional fields', () {
      final s = SubscriptionConfig.fromJson({'topic': 'only-topic'});
      expect(s.topic, 'only-topic');
      expect(s.qos, 1);
      expect(s.enabled, isTrue);
      expect(s.autoAck, isFalse);
      expect(s.label, isNull);
      expect(s.id, isNotEmpty, reason: 'new id generated when missing');
    });

    test('copyWith preserves id and overrides only listed fields', () {
      final a = SubscriptionConfig(topic: 't', qos: 0, autoAck: true);
      final b = a.copyWith(qos: 2, label: 'tagged');
      expect(b.id, a.id);
      expect(b.topic, 't');
      expect(b.qos, 2);
      expect(b.autoAck, isTrue, reason: 'unchanged field preserved');
      expect(b.label, 'tagged');
    });

    group('listFromProfile (legacy compatibility)', () {
      test('returns [] when key absent (pre-1.7 profile)', () {
        expect(SubscriptionConfig.listFromProfile({'mqtt': {}}), isEmpty);
      });

      test('returns [] when value is not a list', () {
        expect(
            SubscriptionConfig.listFromProfile({'subscriptions': 'oops'}),
            isEmpty);
      });

      test('decodes valid entries and skips malformed ones', () {
        final profile = {
          'subscriptions': [
            {'topic': 'a', 'qos': 0},
            'garbage', // non-map entry, must be skipped silently
            {'topic': 'b', 'qos': 2, 'auto_ack': true},
          ],
        };
        final list = SubscriptionConfig.listFromProfile(profile);
        expect(list.length, 2);
        expect(list[0].topic, 'a');
        expect(list[1].autoAck, isTrue);
      });
    });
  });
}
