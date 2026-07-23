import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/l10n/generated/app_localizations.dart';
import 'package:iot_devkit/services/language_provider.dart';
import 'package:iot_devkit/services/mqtt_controller.dart';
import 'package:iot_devkit/services/status_registry.dart';
import 'package:iot_devkit/services/lab_theme_manager.dart';
import 'package:iot_devkit/ui/screens/home_screen.dart';
import 'package:iot_devkit/ui/styles/app_theme_effect.dart';
import 'package:iot_devkit/ui/tools/json_virtualized_editor.dart';
import 'package:iot_devkit/ui/widgets/json_tree_view.dart';
import 'package:iot_devkit/ui/widgets/log_console.dart';
import 'package:iot_devkit/ui/widgets/simulator_panel.dart';
import 'package:iot_devkit/ui/lab/lab.dart';
import 'package:iot_devkit/viewmodels/timesheet_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('simulator smoke: config, mode tabs, preview, and log dock',
      (tester) async {
    await _pumpSmokeApp(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SimulatorPanel), findsOneWidget);
    expect(find.byType(LogConsole), findsOneWidget);
    // LabSection uppercases its header title (Lab Console design).
    expect(find.text('MQTT BROKER'), findsOneWidget);
    expect(find.text('Basic Mode'), findsOneWidget);
    expect(find.text('Advanced Mode'), findsOneWidget);
    expect(find.text('DEVICE CONFIGURATION'), findsOneWidget);
    expect(find.text('START SIMULATION'), findsOneWidget);
    expect(find.text('Preview Payload'), findsOneWidget);

    _selectSimulatorMode(tester, 1);
    await tester.pump(const Duration(milliseconds: 420));
    expect(tester.takeException(), isNull);

    _selectSimulatorMode(tester, 0);
    await tester.pump(const Duration(milliseconds: 420));
    await _pressButton(tester, 'Preview Payload');

    expect(find.text('Payload Preview'), findsOneWidget);
    expect(find.text('JSON'), findsWidgets);

    await _pressButton(tester, 'Close', last: true);
  });

  testWidgets(
      'subscriptions smoke: enable toggle + RPC preset reveals row with Auto-ACK',
      (tester) async {
    await _pumpSmokeApp(tester);

    // Flip the "Enable subscriptions" switch inside the MQTT broker panel
    // (mirrors the SSL/TLS toggle pattern). Tap the embedded Switch directly
    // — tapping the label text alone isn't a reliable hit target.
    final enableToggle =
        find.byKey(const ValueKey('enable_subscriptions_toggle'));
    expect(enableToggle, findsOneWidget);
    await tester
        .tap(find.descendant(of: enableToggle, matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    // Tap the "ThingsBoard RPC" preset icon (its tooltip identifies it).
    await tester.tap(find.byTooltip('Preset: ThingsBoard RPC').first);
    await tester.pumpAndSettle();

    // Row appears with the canonical RPC filter and Auto-ACK checkbox.
    expect(find.text('v1/devices/me/rpc/request/+'), findsWidgets);
    expect(find.text('Auto-ACK'), findsWidgets);

    // Re-tap is a no-op (presets de-duplicate by topic).
    await tester.tap(find.byTooltip('Preset: ThingsBoard RPC').first);
    await tester.pumpAndSettle();
    expect(
      find.text('v1/devices/me/rpc/request/+'),
      findsWidgets,
      reason: 'preset must not duplicate when topic already present',
    );
  });

  testWidgets('timestamp smoke: converts in both directions', (tester) async {
    await _pumpSmokeApp(tester);
    await _selectRailDestination(tester, 1);

    expect(find.text('Timestamp → Date'), findsOneWidget);
    expect(find.text('Date → Timestamp'), findsOneWidget);

    await tester.enterText(_textFieldWithLabel('Timestamp (ms or s)'), '0');
    await _pressButton(tester, 'Convert');
    clearLabToasts();
    await tester.pump();

    expect(find.text('1970-01-01 08:00:00'), findsOneWidget);

    await tester.enterText(
      _textFieldWithLabel('Date (yyyy-MM-dd HH:mm:ss)'),
      '1970-01-01 08:00:00',
    );
    await _pressButton(tester, 'Convert', last: true);
    clearLabToasts();
    await tester.pump();

    expect(find.text('0'), findsWidgets);
  });

  testWidgets('json smoke: parses, formats, searches, and minifies',
      (tester) async {
    await _pumpSmokeApp(tester);
    await _selectRailDestination(tester, 2);

    expect(find.text('Input'), findsOneWidget);
    expect(find.text('Tree View'), findsOneWidget);
    expect(find.text('Format'), findsOneWidget);
    expect(find.text('Minify'), findsOneWidget);

    await tester.enterText(
      _textFieldWithHint('Paste or type JSON here...'),
      '{"device":"dev-1","temperature":23}',
    );
    await tester.pump(const Duration(milliseconds: 180));

    await _pressButton(tester, 'Format');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    clearLabToasts();

    final formattedInput = tester
        .widget<TextField>(_textFieldWithHint('Paste or type JSON here...'));
    expect(formattedInput.controller?.text, contains('\n'));
    expect(formattedInput.controller?.text, contains('"temperature": 23'));

    await tester.enterText(_textFieldWithHint('Search...'), 'temperature');
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('1/1'), findsOneWidget);

    await _pressButton(tester, 'Minify');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    clearLabToasts();

    final minifiedInput = tester
        .widget<TextField>(_textFieldWithHint('Paste or type JSON here...'));
    expect(
      minifiedInput.controller?.text,
      '{"device":"dev-1","temperature":23}',
    );
  });

  testWidgets('json large document remains fully editable and virtualized',
      (tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _pumpSmokeApp(tester);
    await _selectRailDestination(tester, 2);

    final largeJson = jsonEncode({
      'values': [
        for (var index = 0; index < 25000; index++)
          {'ts': index, 'value': '$index'},
      ],
    });
    expect(largeJson.length, greaterThan(512 * 1024));
    await tester.enterText(
      _textFieldWithHint('Paste or type JSON here...'),
      largeJson,
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    expect(find.byType(VirtualizedJsonEditor), findsOneWidget);
    final editor = tester.widget<VirtualizedJsonEditor>(
      find.byType(VirtualizedJsonEditor),
    );
    expect(editor.controller.text, largeJson);
    expect(editor.controller.blocks.length, greaterThan(50));
    expect(
      tester
          .widgetList<TextField>(find.descendant(
            of: find.byType(VirtualizedJsonEditor),
            matching: find.byType(TextField),
          ))
          .length,
      lessThan(20),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await _pressButton(tester, 'Expand All');
    await tester.pumpAndSettle();
    expect(find.byType(JsonTreeView), findsNWidgets(2));
    await _pressButton(tester, 'Collapse All');
    await tester.pumpAndSettle();

    await _pressButton(tester, 'Format');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
    clearLabToasts();
    await tester.pump();

    final formattedEditor = tester.widget<VirtualizedJsonEditor>(
      find.byType(VirtualizedJsonEditor),
    );
    expect(formattedEditor.controller.text, contains('\n'));
    expect(jsonDecode(formattedEditor.controller.text), jsonDecode(largeJson));

    await _pressButton(tester, 'Copy');
    await tester.pump();
    expect(copiedText, formattedEditor.controller.text);
    clearLabToasts();
    await tester.pump();
  });

  testWidgets('certificate smoke: previews ThingsBoard SSL package',
      (tester) async {
    await _pumpSmokeApp(tester);
    await _selectRailDestination(tester, 3);

    expect(find.text('Certificate Generator'), findsOneWidget);
    expect(find.text('HTTPS + MQTTS'), findsOneWidget);
    expect(find.text('PEM'), findsOneWidget);
    expect(find.text('CERTIFICATE SAN ADDRESSES'), findsWidgets);
    expect(find.text('ThingsBoard Env'), findsOneWidget);
    expect(find.text('server.pem'), findsWidgets);
    expect(find.text('server_key.pem'), findsWidgets);
    expect(find.text('cafile.pem'), findsWidgets);

    await tester.enterText(
      _textFieldWithLabel('Certificate Password'),
      'thingsboard',
    );
    await tester.enterText(
      _textFieldWithLabel('Certificate SAN Addresses'),
      'tb.local, mqtt.local, 192.168.1.10',
    );
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('DNS: tb.local'), findsOneWidget);
    expect(find.text('DNS: mqtt.local'), findsOneWidget);
    expect(find.text('IP: 192.168.1.10'), findsOneWidget);
    expect(find.text('Generate ZIP'), findsOneWidget);
  });

  testWidgets('settings smoke: opens theme and language pickers',
      (tester) async {
    await _pumpSmokeApp(tester, enableTimesheet: true);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('Select Theme'), findsOneWidget);
    expect(find.text('Select Language'), findsOneWidget);
    expect(find.text('Timesheet'), findsWidgets);

    await tester.tapAt(const Offset(720, 120));
    await tester.pump(const Duration(milliseconds: 260));
    _selectSettingsAction(tester, 'theme');
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('Signal · default · lime'), findsOneWidget);
    expect(find.text('Cobalt · tech blue'), findsOneWidget);

    await tester.tap(find.text('Cobalt · tech blue'));
    await tester.pump(const Duration(milliseconds: 260));
    await _pressButton(tester, 'Close', last: true);

    _selectSettingsAction(tester, 'language');
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('English'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);

    await tester.tap(find.text('简体中文'));
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('数据模拟'), findsWidgets);
  });

  testWidgets('timesheet smoke: adds, edits, copies report, and deletes entry',
      (tester) async {
    await _pumpSmokeApp(tester, enableTimesheet: true);
    await _selectRailDestination(tester, 4);
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('Timesheet'), findsWidgets);
    expect(find.text('What did you do today'), findsOneWidget);
    expect(find.text('Daily entries'), findsOneWidget);

    await tester.enterText(
      _textFieldWithLabel('Task Content'),
      'Smoke tested feature flow',
    );
    await tester.enterText(_textFieldWithLabel('Hours'), '1');
    await _pressButton(tester, 'Add');

    expect(find.text('Smoke tested feature flow'), findsOneWidget);
    expect(find.text('1 entries / 1 h'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pump(const Duration(milliseconds: 180));
    await tester.enterText(
      _textFieldWithLabel('Task Content'),
      'Updated smoke entry',
    );
    await tester.enterText(_textFieldWithLabel('Hours'), '2');
    await _pressButton(tester, 'Save');

    expect(find.text('Updated smoke entry'), findsOneWidget);
    expect(find.text('1 entries / 2 h'), findsOneWidget);

    await _pressButton(tester, 'Copy Report');
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('Delete this entry?'), findsOneWidget);

    await _pressButton(tester, 'Delete');

    expect(find.text('Updated smoke entry'), findsNothing);
    expect(find.text('0 entries / 0 h'), findsOneWidget);
  });
}

Future<void> _pumpSmokeApp(
  WidgetTester tester, {
  bool enableTimesheet = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'lab_theme_id': 'signal',
    'lab_theme_mode': 'dark',
    'app-locale': 'en',
    'ts_enabled': enableTimesheet,
  });
  clearLabToasts();
  addTearDown(clearLabToasts);

  await _setDesktopSurface(tester);
  await tester.pumpWidget(const _SmokeApp());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 260));
}

Future<void> _selectRailDestination(
  WidgetTester tester,
  int index,
) async {
  // Lab Console rail items carry ValueKey('rail_item_<index>').
  await tester.tap(find.byKey(ValueKey('rail_item_$index')));
  await tester.pump(const Duration(milliseconds: 260));
}

void _selectSimulatorMode(WidgetTester tester, int index) {
  final modeSelector =
      tester.widget<LabSegmented<int>>(find.byType(LabSegmented<int>).first);
  modeSelector.onChanged(index);
}

Future<void> _pressButton(
  WidgetTester tester,
  String label, {
  bool last = false,
}) async {
  // Legacy Material buttons expose ButtonStyleButton ancestry.
  final styled = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
  if (styled.evaluate().isNotEmpty) {
    final button =
        tester.widget<ButtonStyleButton>(last ? styled.last : styled.first);
    button.onPressed?.call();
  } else {
    // LabButton is a Material+InkWell, not a ButtonStyleButton — match by label.
    final lab = find.byWidgetPredicate(
      (widget) => widget is LabButton && widget.label == label,
      description: 'LabButton "$label"',
    );
    expect(lab, findsWidgets);
    final button = tester.widget<LabButton>(last ? lab.last : lab.first);
    button.onPressed?.call();
  }
  await tester.pump(const Duration(milliseconds: 260));
}

void _selectSettingsAction(WidgetTester tester, String action) {
  final popup = tester
      .widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>));
  popup.onSelected?.call(action);
}

Future<void> _setDesktopSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _textFieldWithLabel(String label) {
  // Legacy AppInputDecoration fields expose decoration.labelText directly.
  final legacy = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
    description: 'TextField with label "$label"',
  );
  if (legacy.evaluate().isNotEmpty) return legacy;
  // LabField renders the (uppercased) label above its inner field; target
  // the editable field within the matching LabField instead.
  return find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is LabField && widget.label == label,
      description: 'LabField with label "$label"',
    ),
    matching: find.byType(TextField),
  );
}

Finder _textFieldWithHint(String hint) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
    description: 'TextField with hint "$hint"',
  );
}

class _SmokeApp extends StatelessWidget {
  const _SmokeApp();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LabThemeManager>(
          create: (_) => LabThemeManager()..load(),
        ),
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(),
        ),
        ChangeNotifierProvider<StatusRegistry>(
          create: (_) => StatusRegistry(),
        ),
        ChangeNotifierProvider<TimesheetProvider>(
          create: (_) => TimesheetProvider(),
        ),
        ChangeNotifierProvider<MqttController>(
          create: (_) => MqttController(initializeWorkers: false),
        ),
      ],
      child: Consumer2<LabThemeManager, LanguageProvider>(
        builder: (context, themeManager, languageProvider, child) {
          final base = themeManager.theme.themeData;
          final themed = base.copyWith(
            extensions: [
              ...base.extensions.values,
              const AppThemeEffect(
                animationCurve: Curves.easeOutCubic,
                layoutDensity: 1.0,
                borderRadius: 8.0,
                icons: AppIcons.standard,
              ),
            ],
          );
          return MaterialApp(
            theme: themed,
            darkTheme: themed,
            themeMode: themeManager.theme.brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            locale: languageProvider.currentLocale,
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
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
