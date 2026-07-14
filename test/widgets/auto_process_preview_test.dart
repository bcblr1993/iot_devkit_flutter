import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/l10n/generated/app_localizations.dart';
import 'package:iot_devkit/services/mqtt_controller.dart';
import 'package:iot_devkit/services/status_registry.dart';
import 'package:iot_devkit/ui/lab/lab.dart';
import 'package:iot_devkit/ui/styles/app_theme_effect.dart';
import 'package:iot_devkit/ui/widgets/simulator_panel.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'start preview disables confirmation above automatic process safety limit',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1440, 920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const _PreviewTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(_labField('End Index'), '2000');
      await tester.enterText(_labField('Data Point Count'), '500');
      await tester.pump();

      final startButton = tester.widget<LabButton>(
        find.byWidgetPredicate(
          (widget) => widget is LabButton && widget.label == 'START SIMULATION',
        ),
      );
      startButton.onPressed?.call();
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'This load requires at least 4 sending processes, exceeding this '
          "machine's automatic startup safety limit of 2.",
        ),
        findsOneWidget,
      );

      final confirmButton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Start 4 Processes'),
          matching: find.byWidgetPredicate(
            (widget) => widget is ElevatedButton,
          ),
        ),
      );
      expect(confirmButton.onPressed, isNull);
    },
  );

  test('process-plan warning and safety messages are distinct in both locales',
      () {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh'));

    expect(
      en.autoProcessPlanSingleDeviceUnsatisfied,
      isNot(en.autoProcessPlanShardDistributionUnsatisfied),
    );
    expect(
      zh.autoProcessPlanSingleDeviceUnsatisfied,
      isNot(zh.autoProcessPlanShardDistributionUnsatisfied),
    );
    expect(en.autoProcessSafetyLimitExceeded(4, 2), contains('4'));
    expect(zh.autoProcessSafetyLimitExceeded(4, 2), contains('安全上限 2 个'));
  });
}

Finder _labField(String label) {
  return find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is LabField && widget.label == label,
    ),
    matching: find.byType(TextField),
  );
}

class _PreviewTestApp extends StatelessWidget {
  const _PreviewTestApp();

  @override
  Widget build(BuildContext context) {
    final baseTheme = labThemeSignal.themeData;
    final theme = baseTheme.copyWith(
      extensions: [
        ...baseTheme.extensions.values,
        const AppThemeEffect(
          animationCurve: Curves.easeOutCubic,
          layoutDensity: 1,
          borderRadius: 8,
          icons: AppIcons.standard,
        ),
      ],
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MqttController>(
          create: (_) => MqttController(
            initializeWorkers: false,
            maxAutomaticProcessCount: 2,
          ),
        ),
        ChangeNotifierProvider<StatusRegistry>(
          create: (_) => StatusRegistry(),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('zh')],
        home: const Scaffold(
          body: SimulatorPanel(
            logs: [],
            isLogExpanded: false,
            onToggleLog: _doNothing,
            onClearLog: _doNothing,
          ),
        ),
      ),
    );
  }
}

void _doNothing() {}
