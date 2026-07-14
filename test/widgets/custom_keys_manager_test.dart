import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/l10n/generated/app_localizations.dart';
import 'package:iot_devkit/models/custom_key_config.dart';
import 'package:iot_devkit/ui/lab/lab.dart';
import 'package:iot_devkit/ui/widgets/custom_keys_manager.dart';

void main() {
  testWidgets('toggle keeps a custom key row but marks it inactive',
      (tester) async {
    tester.view.physicalSize = const Size(800, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    List<CustomKeyConfig>? changedKeys;
    final key = CustomKeyConfig(
      id: 'temperature',
      name: 'temperature',
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        theme: labThemeSignal.themeData,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomKeysManager(
            keys: [key],
            customKeysEnabled: true,
            onCustomKeysEnabledChanged: (_) {},
            maxKeys: 10,
            onKeysChanged: (keys) => changedKeys = List.from(keys),
          ),
        ),
      ),
    );

    expect(find.text('temperature'), findsOneWidget);
    expect(find.text('生效 1/10 · 已保留 1 个'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('custom_key_enabled_temperature')),
    );
    await tester.pumpAndSettle();

    expect(changedKeys, isNotNull);
    expect(changedKeys!.single.enabled, isFalse);
    expect(find.text('temperature'), findsOneWidget);
    expect(find.text('停用'), findsOneWidget);
    expect(find.text('生效 0/10 · 已保留 1 个'), findsOneWidget);
  });

  testWidgets('master switch gates all keys without changing row selections',
      (tester) async {
    tester.view.physicalSize = const Size(800, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var masterEnabled = true;
    final keys = [
      CustomKeyConfig(id: 'active', name: 'active_key'),
      CustomKeyConfig(id: 'inactive', name: 'inactive_key', enabled: false),
    ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        theme: labThemeSignal.themeData,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CustomKeysManager(
              keys: keys,
              customKeysEnabled: masterEnabled,
              onCustomKeysEnabledChanged: (enabled) {
                setState(() => masterEnabled = enabled);
              },
              maxKeys: 10,
              onKeysChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('生效 1/10 · 已保留 2 个'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('custom_keys_master_toggle')),
    );
    await tester.pumpAndSettle();

    expect(masterEnabled, isFalse);
    expect(find.text('生效 0/10 · 已保留 2 个'), findsOneWidget);
    expect(find.text('待生效'), findsOneWidget);
    expect(keys.first.enabled, isTrue,
        reason: 'master switch must preserve the per-key selection');
    expect(keys.last.enabled, isFalse);

    await tester.tap(
      find.byKey(const ValueKey('custom_keys_master_toggle')),
    );
    await tester.pumpAndSettle();

    expect(masterEnabled, isTrue);
    expect(find.text('生效 1/10 · 已保留 2 个'), findsOneWidget);
  });
}
