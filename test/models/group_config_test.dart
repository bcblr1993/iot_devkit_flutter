import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/models/group_config.dart';
import 'package:iot_devkit/models/custom_key_config.dart';

void main() {
  group('GroupConfig Logic', () {
    test('should serialize and deserialize correctly', () {
      final customKey = CustomKeyConfig(name: 'temp', mode: CustomKeyMode.random);
      final group = GroupConfig(
        name: 'Test Group',
        startDeviceNumber: 1,
        endDeviceNumber: 5,
        customKeys: [customKey],
      );

      final json = group.toJson();
      final newGroup = GroupConfig.fromJson(json);

      expect(newGroup.name, 'Test Group');
      expect(newGroup.startDeviceNumber, 1);
      expect(newGroup.endDeviceNumber, 5);
      expect(newGroup.customKeys.length, 1);
      expect(newGroup.customKeys.first.name, 'temp');
    });

    test('copyWith creates new instance with updated values', () {
      final group = GroupConfig(name: 'Old Name', totalKeyCount: 10);
      final newGroup = group.copyWith(name: 'New Name', totalKeyCount: 20);

      expect(newGroup.name, 'New Name');
      expect(newGroup.totalKeyCount, 20);
      // Original remains unchanged
      expect(group.name, 'Old Name');
      expect(group.totalKeyCount, 10);
    });
  });

  group('CustomKeyConfig Logic', () {
    test('toJson/fromJson preserves enum values', () {
      final key = CustomKeyConfig(
        type: CustomKeyType.float,
        mode: CustomKeyMode.increment,
        min: 10.5,
      );

      final json = key.toJson();
      final newKey = CustomKeyConfig.fromJson(json);

      expect(newKey.type, CustomKeyType.float);
      expect(newKey.mode, CustomKeyMode.increment);
      expect(newKey.min, 10.5);
    });
  });
}
