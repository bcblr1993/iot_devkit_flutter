import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/models/custom_key_config.dart';
import 'package:iot_devkit/models/group_config.dart';
import 'package:iot_devkit/services/simulation_config_validator.dart';

void main() {
  group('SimulationConfigValidator', () {
    const validator = SimulationConfigValidator();

    test('accepts a valid basic simulation config', () {
      final result = validator.validate(
        _basicConfig(),
        mode: SimulationMode.basic,
      );

      expect(result.isValid, isTrue);
    });

    test('rejects basic config with invalid range and port', () {
      final config = _basicConfig()
        ..['device_start_number'] = 10
        ..['device_end_number'] = 1
        ..['mqtt'] = {
          'host': 'localhost',
          'port': 70000,
          'topic': 'v1/devices/me/telemetry',
        };

      final result = validator.validate(
        config,
        mode: SimulationMode.basic,
      );

      expect(result.isValid, isFalse);
      expect(result.issues.map((issue) => issue.field), contains('mqtt.port'));
      expect(
          result.issues.map((issue) => issue.field), contains('basic.range'));
    });

    test('rejects duplicate custom keys and invalid random range', () {
      final config = _basicConfig()
        ..['custom_keys'] = [
          CustomKeyConfig(name: 'temperature', min: 100, max: 1).toJson(),
          CustomKeyConfig(name: 'temperature').toJson(),
        ];

      final result = validator.validate(
        config,
        mode: SimulationMode.basic,
      );

      expect(result.isValid, isFalse);
      expect(
        result.issues.map((issue) => issue.field),
        contains('custom_keys[0].range'),
      );
      expect(
        result.issues.map((issue) => issue.field),
        contains('custom_keys[1].name'),
      );
    });

    test('rejects advanced mode without groups', () {
      final config = _basicConfig()
        ..['groups'] = []
        ..['mode'] = 'advanced';

      final result = validator.validate(
        config,
        mode: SimulationMode.advanced,
      );

      expect(result.isValid, isFalse);
      expect(result.firstIssue?.field, 'groups');
    });

    test('rejects invalid advanced group settings', () {
      final config = _basicConfig()
        ..['groups'] = [
          GroupConfig(
            name: '',
            startDeviceNumber: 5,
            endDeviceNumber: 3,
            totalKeyCount: 0,
            changeIntervalSeconds: 0,
            fullIntervalSeconds: 0,
            changeRatio: 1.5,
            customKeys: [
              CustomKeyConfig(
                name: 'enabled',
                type: CustomKeyType.boolean,
                mode: CustomKeyMode.static,
                staticValue: 'maybe',
              ),
            ],
          ).toJson(),
        ]
        ..['mode'] = 'advanced';

      final result = validator.validate(
        config,
        mode: SimulationMode.advanced,
      );

      expect(result.isValid, isFalse);
      expect(
        result.issues.map((issue) => issue.field),
        containsAll([
          'groups[0].name',
          'groups[0].range',
          'groups[0].totalKeyCount',
          'groups[0].changeIntervalSeconds',
          'groups[0].fullIntervalSeconds',
          'groups[0].changeRatio',
          'custom_keys[0].static_value',
        ]),
      );
    });
  });
}

Map<String, dynamic> _basicConfig() {
  return {
    'mode': 'basic',
    'mqtt': {
      'host': 'localhost',
      'port': 1883,
      'topic': 'v1/devices/me/telemetry',
      'qos': 0,
      'enable_ssl': false,
    },
    'device_start_number': 1,
    'device_end_number': 10,
    'device_prefix': 'device',
    'client_id_prefix': 'device',
    'username_prefix': 'user',
    'password_prefix': 'pass',
    'send_interval': 1,
    'data': {
      'format': 'default',
      'data_point_count': 10,
    },
    'custom_keys': [],
    'groups': [GroupConfig().toJson()],
  };
}
