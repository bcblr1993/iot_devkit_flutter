import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/services/data_generator.dart';
import 'package:iot_devkit/models/custom_key_config.dart';
import 'package:iot_devkit/models/schema_item.dart';

void main() {
  group('DataGenerator Tests', () {
    setUp(() {
      DataGenerator.resetKey1Counter();
      DataGenerator.resetCustomKeyCounters();
    });

    test('key_1 increments correctly per client', () {
      final val1 = DataGenerator.getKey1Value('client1');
      final val2 = DataGenerator.getKey1Value('client1');
      final val3 = DataGenerator.getKey1Value('client2');

      expect(val1, 1);
      expect(val2, 2);
      expect(val3, 1);
    });

    test('getRandomInt returns value within range', () {
      for (int i = 0; i < 100; i++) {
        final val = DataGenerator.getRandomInt(10, 20);
        expect(val, greaterThanOrEqualTo(10));
        expect(val, lessThanOrEqualTo(20));
      }
    });

    test('generateBatteryStatus produces valid map with correct keys', () {
      final data = DataGenerator.generateBatteryStatus(5, clientId: 'test_client');
      expect(data.length, 5);
      expect(data.containsKey('key_1'), true);
      expect(data.containsKey('key_2'), true);
      // key_1 is auto-handled if count > 0
      expect(data['key_1'], 1); 
    });

    test('generateCustomKeys works for Static mode', () {
      final key = CustomKeyConfig(
        name: 'static_key',
        type: CustomKeyType.string,
        mode: CustomKeyMode.static,
        staticValue: 'test_val',
      );
      final data = DataGenerator.generateCustomKeys([key]);
      expect(data['static_key'], 'test_val');
    });

    test('generateCustomKeys works for Increment mode', () {
      final key = CustomKeyConfig(
        name: 'inc_key',
        type: CustomKeyType.integer,
        mode: CustomKeyMode.increment,
      );
      
      var data = DataGenerator.generateCustomKeys([key]);
      expect(data['inc_key'], 1);
      
      data = DataGenerator.generateCustomKeys([key]);
      expect(data['inc_key'], 2);
    });
    
    test('generateCustomKeys works for Toggle mode', () {
      final key = CustomKeyConfig(
        name: 'toggle_key',
        type: CustomKeyType.integer,
        mode: CustomKeyMode.toggle,
      );
      
      var data = DataGenerator.generateCustomKeys([key]);
      expect(data['toggle_key'], 1); // First toggle gives 1
      
      data = DataGenerator.generateCustomKeys([key]);
      expect(data['toggle_key'], 0);
      
      data = DataGenerator.generateCustomKeys([key]);
      expect(data['toggle_key'], 1);
    });

    test('generateTnPayload structure check', () {
      final data = DataGenerator.generateTnPayload(2);
      expect(data['type'], 'real');
      expect(data['sn'], 'TN001');
      expect(data['data']['C24_D1'], isA<List>());
      expect((data['data']['C24_D1'] as List).length, 2);
    });
    
    test('generateTypedData creates data from schema', () {
      final schema = [
        SchemaItem(name: 'temp', type: 'float'),
        SchemaItem(name: 'status', type: 'bool'),
      ];
      final data = DataGenerator.generateTypedData(schema, 2);
      expect(data.containsKey('temp'), true);
      expect(data.containsKey('status'), true);
      expect(data['temp'], isA<double>());
      expect(data['status'], isA<bool>());
    });
  });
}
