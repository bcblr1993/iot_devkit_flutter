import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/models/group_config.dart';
import 'package:iot_devkit/models/custom_key_config.dart';

void main() {
  group('Configuration Models Serialization', () {
    
    test('CustomKeyConfig serialization round-trip', () {
      final key = CustomKeyConfig(
        name: 'test_key',
        type: CustomKeyType.float,
        mode: CustomKeyMode.random,
        min: 10.0,
        max: 20.0,
      );
      
      final json = key.toJson();
      expect(json['name'], 'test_key');
      expect(json['type'], 'float');
      expect(json['mode'], 'random');
      
      final restored = CustomKeyConfig.fromJson(json);
      expect(restored.name, key.name);
      expect(restored.min, 10.0);
    });

    test('GroupConfig serialization round-trip', () {
      final group = GroupConfig(
        id: 'g1',
        name: 'Group 1',
        startDeviceNumber: 1,
        endDeviceNumber: 100,
        devicePrefix: 'dev_',
        customKeys: [
             CustomKeyConfig(name: 'k1', type: CustomKeyType.integer)
        ]
      );
      
      final json = group.toJson();
      expect(json['name'], 'Group 1');
      expect((json['customKeys'] as List).length, 1);
      
      final restored = GroupConfig.fromJson(json);
      expect(restored.name, 'Group 1');
      expect(restored.customKeys.length, 1);
      expect(restored.customKeys.first.name, 'k1');
    });
  });
}
