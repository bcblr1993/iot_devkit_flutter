import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iot_devkit/services/config_service.dart';
import 'package:iot_devkit/models/group_config.dart';
import 'dart:convert';

void main() {
  group('ConfigService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveToLocalStorage saves valid JSON', () async {
      final config = {
        'version': '1.0',
        'groups': [
          GroupConfig(name: 'Test Group').toJson(),
        ]
      };

      await ConfigService.saveToLocalStorage(config);

      final prefs = await SharedPreferences.getInstance();
      final storedString = prefs.getString('simulator_config');
      expect(storedString, isNotNull);
      
      final storedJson = jsonDecode(storedString!);
      expect(storedJson['version'], '1.0');
      expect((storedJson['groups'] as List).length, 1);
    });

    test('loadFromLocalStorage returns null if empty', () async {
      final config = await ConfigService.loadFromLocalStorage();
      expect(config, isNull);
    });

    test('loadFromLocalStorage returns data if exists', () async {
       final config = {'test_key': 'test_val'};
       SharedPreferences.setMockInitialValues({
         'simulator_config': jsonEncode(config)
       });
       
       final loaded = await ConfigService.loadFromLocalStorage();
       expect(loaded, isNotNull);
       expect(loaded!['test_key'], 'test_val');
    });
  });
}
