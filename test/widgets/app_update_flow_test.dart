import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/l10n/generated/app_localizations.dart';
import 'package:iot_devkit/models/app_release_info.dart';
import 'package:iot_devkit/services/app_update_service.dart';
import 'package:iot_devkit/services/feature_visibility_provider.dart';
import 'package:iot_devkit/services/language_provider.dart';
import 'package:iot_devkit/services/mqtt_controller.dart';
import 'package:iot_devkit/services/status_registry.dart';
import 'package:iot_devkit/ui/lab/lab.dart';
import 'package:iot_devkit/ui/screens/home_screen.dart';
import 'package:iot_devkit/viewmodels/app_update_provider.dart';
import 'package:iot_devkit/viewmodels/timesheet_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('iot_devkit_ui_update_');
    clearLabToasts();
  });

  tearDown(() async {
    clearLabToasts();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
      'shows in-app update banner and settings badge, supports skip & manual re-open',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app-locale': 'zh'});
    await _setDesktopSurface(tester);

    final service = _buildFakeUpdateService(
      tempDir: tempDir,
      platform: AppUpdatePlatform.macos,
      latestVersion: '1.12.0',
    );
    final updateProvider = AppUpdateProvider(
      service: service,
      versionLoader: () async => '1.11.0-20261119',
      startupCheckDelay: const Duration(milliseconds: 50),
    );
    addTearDown(updateProvider.dispose);

    await tester.pumpWidget(_buildUpdateTestApp(updateProvider));
    _triggerInit(updateProvider);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump();

    // Bottom status bar prompt and settings gear dot both appear.
    expect(find.byKey(const ValueKey('update_status_banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings_update_badge')), findsOneWidget);
    expect(find.textContaining('v1.12.0'), findsOneWidget);

    // Dismissing for session hides the banner while preserving the gear badge.
    updateProvider.dismissBannerForSession();
    await tester.pump();
    expect(find.byKey(const ValueKey('update_status_banner')), findsNothing);
    expect(find.byKey(const ValueKey('settings_update_badge')), findsOneWidget);

    // Skipping the version clears the gear badge as well.
    await updateProvider.skipAvailableVersion();
    await tester.pump();
    expect(find.byKey(const ValueKey('settings_update_badge')), findsNothing);

    // Manual check via Settings menu opens the dialog and surfaces v1.12.0 again.
    final popup = tester.widget<PopupMenuButton<String>>(
      find.byType(PopupMenuButton<String>),
    );
    popup.onSelected?.call('check_update');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const ValueKey('app_update_dialog')), findsOneWidget);
    expect(find.text('软件更新'), findsOneWidget);
    expect(find.textContaining('支持应用内在线下载与 SHA-256 完整性校验'), findsOneWidget);
  });

  testWidgets(
      'downloads verified installer in dialog and launches Windows upgrade cleanly',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app-locale': 'en'});
    await _setDesktopSurface(tester);

    String? launchedInstallerPath;
    var appExited = false;

    final service = _buildFakeUpdateService(
      tempDir: tempDir,
      platform: AppUpdatePlatform.windows,
      latestVersion: '1.12.0',
      onRunInstaller: (platform, path) async {
        launchedInstallerPath = path;
        return InstallActionOutcome.launchedInstallerRequiresExit;
      },
    );
    final updateProvider = AppUpdateProvider(
      service: service,
      versionLoader: () async => '1.11.0',
      autoCheckOnStart: false,
      exitApp: () async {
        appExited = true;
      },
    );
    addTearDown(updateProvider.dispose);

    await tester.pumpWidget(_buildUpdateTestApp(updateProvider));
    await tester.runAsync(() => updateProvider.initialize());
    await tester.runAsync(() => updateProvider.checkForUpdates(manual: true));
    await tester.pump();

    // Open update dialog from bottom banner "View Update" button.
    final viewBtn = find.byWidgetPredicate(
      (w) => w is LabButton && w.label == 'View Update',
    );
    expect(viewBtn, findsOneWidget);
    tester.widget<LabButton>(viewBtn).onPressed?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const ValueKey('app_update_dialog')), findsOneWidget);
    expect(find.text('SHA-256 VERIFIED'), findsOneWidget);

    // Start download inside dialog.
    final downloadBtn = find.byWidgetPredicate(
      (w) => w is LabButton && w.label.startsWith('Download Update'),
    );
    expect(downloadBtn, findsOneWidget);
    await tester.runAsync(() => updateProvider.startDownload());
    await tester.pump();

    expect(updateProvider.phase, AppUpdatePhase.readyToInstall);
    expect(find.text('Update package verified and ready'), findsOneWidget);

    // Trigger Install & Exit.
    final installBtn = find.byWidgetPredicate(
      (w) => w is LabButton && w.label == 'Install & Exit',
    );
    expect(installBtn, findsWidgets);
    await tester.runAsync(() async {
      tester.widget<LabButton>(installBtn.last).onPressed?.call();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(launchedInstallerPath, isNotNull);
    expect(File(launchedInstallerPath!).existsSync(), isTrue);
    expect(appExited, isTrue);
  });
}

AppUpdateService _buildFakeUpdateService({
  required Directory tempDir,
  required AppUpdatePlatform platform,
  required String latestVersion,
  PlatformInstallerRunner? onRunInstaller,
}) {
  // SHA-256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
  const payloadSha =
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

  return AppUpdateService(
    platformOverride: platform,
    getTempDirectory: () async => tempDir,
    fetchJson: (_) async => {
      'version': latestVersion,
      'tag': 'v$latestVersion',
      'publishedAt': '2026-11-20',
      'htmlUrl':
          'https://github.com/bcblr1993/iot_devkit_flutter/releases/tag/v$latestVersion',
      'notes': '## 新增\n- 支持应用内在线下载与 SHA-256 完整性校验',
      'platforms': {
        'macos': {
          'name': 'iot_devkit-$latestVersion-macos.dmg',
          'url':
              'https://github.com/bcblr1993/iot_devkit_flutter/releases/download/v$latestVersion/iot_devkit-$latestVersion-macos.dmg',
          'sha256': payloadSha,
          'size': 3,
        },
        'windows': {
          'name': 'iot_devkit-$latestVersion-windows.exe',
          'url':
              'https://github.com/bcblr1993/iot_devkit_flutter/releases/download/v$latestVersion/iot_devkit-$latestVersion-windows.exe',
          'sha256': payloadSha,
          'size': 3,
        },
        'linux': {
          'name': 'iot_devkit_linux.tar.gz',
          'url':
              'https://github.com/bcblr1993/iot_devkit_flutter/releases/download/v$latestVersion/iot_devkit_linux.tar.gz',
          'sha256': payloadSha,
          'size': 3,
        },
      },
    },
    downloadStream: ({
      required uri,
      required sink,
      required onChunk,
      required onProgress,
      required cancelToken,
    }) async {
      final bytes = Uint8List.fromList(utf8.encode('abc'));
      onChunk(bytes);
      sink.add(bytes);
      onProgress(bytes.length, bytes.length);
    },
    runInstaller: onRunInstaller ??
        (p, _) async => switch (p) {
              AppUpdatePlatform.windows =>
                InstallActionOutcome.launchedInstallerRequiresExit,
              AppUpdatePlatform.macos => InstallActionOutcome.mountedDiskImage,
              AppUpdatePlatform.linux =>
                InstallActionOutcome.openedArchiveDirectory,
            },
  );
}

void _triggerInit(AppUpdateProvider provider) {
  provider.initialize();
}

Future<void> _setDesktopSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 820);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _buildUpdateTestApp(AppUpdateProvider updateProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider(),
      ),
      ChangeNotifierProvider<StatusRegistry>(
        create: (_) => StatusRegistry(),
      ),
      ChangeNotifierProvider<FeatureVisibilityProvider>(
        create: (_) => FeatureVisibilityProvider(),
      ),
      ChangeNotifierProvider<TimesheetProvider>(
        create: (_) => TimesheetProvider(),
      ),
      ChangeNotifierProvider<MqttController>(
        create: (_) => MqttController(initializeWorkers: false),
      ),
      ChangeNotifierProvider<AppUpdateProvider>.value(value: updateProvider),
    ],
    child: Consumer<LanguageProvider>(
      builder: (context, lang, _) => MaterialApp(
        theme: labThemeSignal.themeData,
        locale: lang.currentLocale,
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
      ),
    ),
  );
}
