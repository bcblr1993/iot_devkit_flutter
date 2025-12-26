import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/services/data_generator.dart';
import 'package:iot_devkit/models/custom_key_config.dart';

void main() {
  group('DataGenerator Tests', () {
    
    setUp(() {
      DataGenerator.resetKey1Counter();
      DataGenerator.resetCustomKeyCounters();
    });

    test('generateBatteryStatus generates correct number of keys', () {
      final data = DataGenerator.generateBatteryStatus(10, clientId: 'test_client');
      expect(data.length, 10);
      expect(data.containsKey('key_1'), true);
      
      // key_1 logic test
      expect(data['key_1'], 1); // First call for this client
    });

    test('key_1 increments correctly per client', () {
      // Client A
      final d1 = DataGenerator.generateBatteryStatus(5, clientId: 'client_A');
      expect(d1['key_1'], 1);
      final d2 = DataGenerator.generateBatteryStatus(5, clientId: 'client_A');
      expect(d2['key_1'], 2);

      // Client B (Should be independent)
      final d3 = DataGenerator.generateBatteryStatus(5, clientId: 'client_B');
      expect(d3['key_1'], 1);
    });

    test('generateTnPayload structure is correct', () {
      final data = DataGenerator.generateTnPayload(5);
      expect(data['sn'], 'TN001');
      expect(data['type'], 'real');
      expect(data['data']['C24_D1'], isA<List>());
      expect((data['data']['C24_D1'] as List).length, 5);
      
      final tag1 = (data['data']['C24_D1'] as List)[0];
      expect(tag1['id'], 'Tag1');
    });

    test('Custom Keys - Static Mode', () {
      final keys = [
        CustomKeyConfig(name: 'static_test', type: CustomKeyType.string, mode: CustomKeyMode.static, staticValue: 'fixed_val')
      ];
      
      final data = DataGenerator.generateBatteryStatus(
        5, 
        clientId: 'test', 
        customKeys: keys
      );
      
      expect(data['static_test'], 'fixed_val');
    });

    test('Custom Keys - Increment Mode', () {
      final keys = [
        CustomKeyConfig(name: 'inc_test', type: CustomKeyType.integer, mode: CustomKeyMode.increment)
      ];
      
      var data = DataGenerator.generateBatteryStatus(5, clientId: 'test', customKeys: keys);
      expect(data['inc_test'], 1);
      
      data = DataGenerator.generateBatteryStatus(5, clientId: 'test', customKeys: keys);
      expect(data['inc_test'], 2);
    });
    
    test('wrapWithTimestamp adds ts field', () {
      final payload = {'val': 123};
      final ts = 10000;
      final wrapped = DataGenerator.wrapWithTimestamp(payload, ts);
      
      expect(wrapped['ts'], ts);
      expect(wrapped['values']['val'], 123);
    });
    
    test('generateTnEmptyPayload returns empty data object', () {
      final data = DataGenerator.generateTnEmptyPayload();
      expect(data['data'], isEmpty);
      expect(data['type'], 'real');
    });
  });
}
