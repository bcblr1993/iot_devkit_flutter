import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/l10n/generated/app_localizations.dart';
import 'package:iot_devkit/models/payload_format.dart';
import 'package:iot_devkit/models/subscription_config.dart';
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

    test('generatePreviewData returns timestamped payload for basic mode', () {
      // Default format is the ThingsBoard timestamped object: {ts, values}.
      final data = vm.generatePreviewData(isBasic: true);
      expect(data, isA<Map<String, dynamic>>());
      final map = data as Map<String, dynamic>;
      expect(map.containsKey('ts'), true);
      expect((map['values'] as Map).containsKey('key_1'), true);
    });

    test('generatePreviewData respects the selected format', () {
      vm.setFormat(PayloadFormat.simpleKv);
      final simple = vm.generatePreviewData(isBasic: true);
      expect(simple, isA<Map<String, dynamic>>());
      expect((simple as Map).containsKey('key_1'), true);
      expect(simple.containsKey('ts'), false);

      vm.setFormat(PayloadFormat.array);
      final arr = vm.generatePreviewData(isBasic: true);
      expect(arr, isA<List>());
      expect(((arr as List).first as Map).containsKey('ts'), true);
    });

    test('getCompleteConfig returns valid map', () {
      vm.hostController.text = 'test.host';
      final config = vm.getCompleteConfig();
      expect(config['mqtt']['host'], 'test.host');
      expect(config['mqtt']['protocol_version'], 'mqtt_3_1_1');
      expect(config['data']['data_point_count'], 10);
    });

    test('setMqttProtocolVersion persists selected protocol', () {
      vm.setMqttProtocolVersion('mqtt_3_1');
      final config = vm.getCompleteConfig();
      expect(vm.mqttProtocolVersion, 'mqtt_3_1');
      expect(config['mqtt']['protocol_version'], 'mqtt_3_1');
    });

    group('subscriptions', () {
      test('default: empty list, disabled', () {
        expect(vm.subscriptions, isEmpty);
        expect(vm.subscriptionsEnabled, isFalse);
        final config = vm.getCompleteConfig();
        expect(config['subscriptions'], isEmpty);
        expect(config['subscriptions_enabled'], isFalse);
      });

      test('updateSubscriptions serializes into getCompleteConfig', () {
        vm.updateSubscriptions([
          SubscriptionConfig.thingsboardRpcPreset(),
          SubscriptionConfig(topic: 'custom/topic', qos: 2),
        ]);
        final config = vm.getCompleteConfig();
        final subs = config['subscriptions'] as List;
        expect(subs.length, 2);
        expect(subs[0]['topic'], 'v1/devices/me/rpc/request/+');
        expect(subs[0]['auto_ack'], isTrue);
        expect(subs[1]['topic'], 'custom/topic');
        expect(subs[1]['qos'], 2);
      });

      test('setSubscriptionsEnabled toggles the master flag', () {
        expect(vm.subscriptionsEnabled, isFalse);
        vm.setSubscriptionsEnabled(true);
        expect(vm.subscriptionsEnabled, isTrue);
        expect(vm.getCompleteConfig()['subscriptions_enabled'], isTrue);
      });

      test('legacy profile with subscriptions but no flag auto-enables',
          () async {
        // Simulate loading a pre-1.7 profile persisted under the config key:
        // it has a `subscriptions` array but NO `subscriptions_enabled`.
        final legacyJson = jsonEncode({
          'mqtt': {'host': 'legacy.host', 'port': 1883},
          'subscriptions': [
            SubscriptionConfig.thingsboardRpcPreset().toJson(),
          ],
          // intentionally no 'subscriptions_enabled'
        });
        SharedPreferences.setMockInitialValues({
          'simulator_config': legacyJson,
        });

        final legacy = MqttViewModel();
        addTearDown(legacy.dispose);
        await legacy.loadConfig();
        // Let the constructor's async _initProfile settle so its late
        // notifyListeners fires before tearDown disposes the VM.
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(legacy.subscriptions.length, 1);
        expect(legacy.subscriptionsEnabled, isTrue,
            reason: 'legacy subs without flag should default to enabled');
      });

      test('profile with explicit subscriptions_enabled=false stays disabled',
          () async {
        final json = jsonEncode({
          'mqtt': {'host': 'h', 'port': 1883},
          'subscriptions': [
            SubscriptionConfig.thingsboardRpcPreset().toJson(),
          ],
          'subscriptions_enabled': false,
        });
        SharedPreferences.setMockInitialValues({'simulator_config': json});

        final vm2 = MqttViewModel();
        addTearDown(vm2.dispose);
        await vm2.loadConfig();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(vm2.subscriptions.length, 1,
            reason: 'rows are preserved even when disabled');
        expect(vm2.subscriptionsEnabled, isFalse);
      });
    });

    testWidgets('startBasicSimulation blocks invalid device range',
        (tester) async {
      vm.startIdxController.text = '10';
      vm.endIdxController.text = '1';

      var previewCalled = false;
      bool? startResult;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('zh'),
          ],
          home: Builder(
            builder: (context) {
              return Column(
                children: [
                  Form(
                    key: vm.formKeyMqtt,
                    child: const SizedBox.shrink(),
                  ),
                  Form(
                    key: vm.formKeyBasic,
                    child: const SizedBox.shrink(),
                  ),
                  TextButton(
                    onPressed: () {
                      startResult = vm.startBasicSimulation(
                        context,
                        (_, __) => previewCalled = true,
                      );
                    },
                    child: const Text('start'),
                  ),
                ],
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('start'));
      await tester.pump();

      expect(startResult, isFalse);
      expect(previewCalled, isFalse);
      expect(
        vm.lastValidationError,
        'Basic mode end index cannot be smaller than start index.',
      );
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
