import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/viewmodels/mqtt_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MqttViewModel Tests', () {
    late MqttViewModel vm;

    setUp(() async {
      SharedPreferences.setMockInitialValues({}); // Start clean
      vm = MqttViewModel();
      await vm.loadConfig(); // Wait for initialization logic to complete
    });
    
    tearDown(() {
      vm.dispose();
    });

    test('Initializes with default values', () {
      expect(vm.hostController.text, 'localhost');
      expect(vm.portController.text, '1883');
      expect(vm.groups.length, 1); // loadConfig adds 1 default group if empty
    });

    test('setEnableSsl updates state', () {
      expect(vm.enableSsl, false);
      vm.setEnableSsl(true);
      expect(vm.enableSsl, true);
    });
    
    test('generatePreviewData returns data for basic mode', () {
      final data = vm.generatePreviewData(isBasic: true);
      expect(data, isNotNull);
      expect(data!.containsKey('key_1'), true);
    });
    
    test('getCompleteConfig returns valid map', () {
      vm.hostController.text = 'test.host';
      final config = vm.getCompleteConfig();
      expect(config['mqtt']['host'], 'test.host');
      expect(config['data']['data_point_count'], 10);
    });
  });
}
