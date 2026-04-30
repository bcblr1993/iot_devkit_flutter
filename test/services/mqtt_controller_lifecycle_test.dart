import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/services/mqtt_controller.dart';

void main() {
  test('stop during startup releases busy state and cancels upload start',
      () async {
    final controller = MqttController(
      initializeWorkers: false,
      stabilizationDelay: const Duration(milliseconds: 50),
    );
    addTearDown(controller.dispose);

    final startFuture = controller.start(_zeroDeviceConfig());
    await Future<void>.delayed(Duration.zero);

    expect(controller.isBusy, isTrue);
    expect(controller.isRunning, isTrue);
    expect(controller.isStarting, isTrue);

    await controller.stop().timeout(const Duration(milliseconds: 200));

    expect(controller.isBusy, isFalse);
    expect(controller.isRunning, isFalse);
    expect(controller.isStarting, isFalse);
    expect(controller.isStopping, isFalse);

    await startFuture.timeout(const Duration(seconds: 1));

    expect(controller.isBusy, isFalse);
    expect(controller.isRunning, isFalse);
  });
}

Map<String, dynamic> _zeroDeviceConfig() {
  return {
    'mode': 'basic',
    'device_start_number': 1,
    'device_end_number': 0,
    'client_id_prefix': 'device',
    'username_prefix': 'user',
    'password_prefix': 'pass',
    'send_interval': 1,
    'mqtt': {
      'host': 'localhost',
      'port': 1883,
      'topic': 'v1/devices/me/telemetry',
      'qos': 0,
      'enable_ssl': false,
    },
    'data': {
      'format': 'default',
      'data_point_count': 1,
    },
    'custom_keys': <Map<String, dynamic>>[],
  };
}
