import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/l10n/generated/app_localizations.dart';
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
