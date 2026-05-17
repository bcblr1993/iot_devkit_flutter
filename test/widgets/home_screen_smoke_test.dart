import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/l10n/generated/app_localizations.dart';
import 'package:iot_devkit/services/mqtt_controller.dart';
import 'package:iot_devkit/services/status_registry.dart';
import 'package:iot_devkit/ui/lab/lab.dart';
import 'package:iot_devkit/ui/screens/home_screen.dart';
import 'package:iot_devkit/ui/screens/timesheet_screen.dart';
import 'package:iot_devkit/ui/shell/app_navigation_rail.dart';
import 'package:iot_devkit/viewmodels/timesheet_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('HomeScreen renders the app navigation shell', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(_buildTestApp());

    await tester.pump();

    expect(find.byType(AppNavigationRail), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('HomeScreen can show and navigate to Timesheet when enabled',
      (tester) async {
    SharedPreferences.setMockInitialValues({'ts_enabled': true});

    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    await tester.pump();

    expect(find.byType(AppNavigationRail), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month), findsWidgets);

    await tester.tap(find.byIcon(Icons.calendar_month).first);
    await tester.pump();

    expect(find.byType(TimesheetScreen), findsOneWidget);
  });

  testWidgets('HomeScreen shell stays stable at the minimum window size',
      (tester) async {
    SharedPreferences.setMockInitialValues({'ts_enabled': true});
    await _setSurfaceSize(tester, const Size(800, 600));

    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    await tester.tap(find.byIcon(Icons.calendar_month).first);
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _buildTestApp() {
  return MaterialApp(
    theme: labThemeSignal.themeData,
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
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<MqttController>(
          create: (_) => MqttController(initializeWorkers: false),
        ),
        ChangeNotifierProvider<StatusRegistry>(
          create: (_) => StatusRegistry(),
        ),
        ChangeNotifierProvider<TimesheetProvider>(
          create: (_) => TimesheetProvider(),
        ),
      ],
      child: const HomeScreen(),
    ),
  );
}
