// ignore_for_file: avoid_hardcoded_color
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'l10n/generated/app_localizations.dart';
import 'services/mqtt_controller.dart';
import 'services/lab_theme_manager.dart';
import 'ui/styles/app_theme_effect.dart';
import 'services/language_provider.dart';
import 'services/status_registry.dart';
import 'services/feature_visibility_provider.dart';
import 'utils/statistics_collector.dart';
import 'ui/screens/home_screen.dart';
import 'utils/about_dialog_helper.dart';
import 'services/log_storage_service.dart';
import 'services/simulation_worker_runtime.dart';
import 'viewmodels/timesheet_provider.dart';
import 'models/process_shard.dart';

import 'package:window_manager/window_manager.dart';

Future<void> _writePanicLog(Object error, StackTrace stack) async {
  try {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final File crashFile =
        File(p.join(appDocDir.path, 'IoT DevKit', 'crash_startup.txt'));

    if (!crashFile.parent.existsSync()) {
      crashFile.parent.createSync(recursive: true);
    }

    final String timestamp = DateTime.now().toIso8601String();
    final String msg =
        '[$timestamp] FATAL ERROR:\n$error\n\nStack Trace:\n$stack\n\n--------------------------\n';

    // Using sync write to ensure it hits disk even if app dies
    crashFile.writeAsStringSync(msg, mode: FileMode.append);
    if (kDebugMode) {
      print('Written to panic log: ${crashFile.path}');
    }
  } catch (e) {
    if (kDebugMode) print('Failed to write panic log: $e');
  }
}

void main(List<String> arguments) async {
  late final ProcessShard processShard;
  try {
    processShard = ProcessShard.fromArguments(arguments);
  } on FormatException catch (error) {
    stderr.writeln('IoT DevKit: ${error.message}');
    exitCode = 64;
    return;
  }
  // High-volume simulation is the primary workload, so detailed per-message
  // logs are opt-in. --performance remains accepted for explicit launch
  // scripts; --detailed-logs restores the diagnostic mode when needed.
  final performanceMode = arguments.contains('--performance') ||
      !arguments.contains('--detailed-logs');
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      // 1. Initialize File Logging Service
      await LogStorageService.instance.init(
        instanceLabel: processShard.isSharded
            ? 'shard-${processShard.index + 1}-of-${processShard.count}'
            : null,
      );
    } catch (e, stack) {
      await _writePanicLog('LogStorageService init failed: $e', stack);
    }

    // 2. Initialize Logging
    Logger.root.level = Level.ALL; // Defaults to Level.INFO
    Logger.root.onRecord.listen((record) {
      LogStorageService.instance.write(record);
      if (kDebugMode) {
        debugPrint(
            '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
        if (record.error != null) {
          debugPrint('Error: ${record.error}');
        }
      }
    });

    if (arguments.contains('--worker')) {
      if (!processShard.isSharded) {
        stderr.writeln('IoT DevKit worker requires --shard=N/M with M > 1.');
        await LogStorageService.instance.dispose();
        exit(64);
      }

      // Windows workers are kept hidden by the native runner before the Dart
      // entrypoint starts. Other desktop runners may create their window from a
      // storyboard/template, so hide it defensively before entering the
      // headless IPC loop.
      if (!Platform.isWindows) {
        await windowManager.ensureInitialized();
      }

      // A Flutter embedder may terminate after Dart main completes when no
      // frame tree has ever been attached (macOS does this even with an active
      // stdin subscription). A zero-size root keeps the engine/event loop
      // alive; the Windows native runner still never shows its worker window.
      runApp(const SizedBox.shrink());
      if (!Platform.isWindows) {
        await windowManager.hide();
      }

      final controller = MqttController(
        processShard: processShard,
        enableDetailedLogs: false,
        allowAutoProcesses: false,
      );
      final runtime = SimulationWorkerRuntime(
        controller: controller,
        processShard: processShard,
      );
      final workerExitCode = await runtime.run();
      controller.dispose();
      await LogStorageService.instance.dispose();
      // Close the anonymous protocol pipe before process termination. A final
      // `stopped` frame can otherwise remain in the desktop embedder's stdout
      // buffer even after IOSink.flush() completes.
      await stdout.flush();
      await stdout.close();
      exit(workerExitCode);
    }

    try {
      await windowManager.ensureInitialized();

      // 3. Restore theme choice before first frame to avoid FOUC.
      final themeManager = LabThemeManager();
      await themeManager.load();

      final windowTitle = processShard.isSharded
          ? 'IoT DevKit [${processShard.label}]'
          : 'IoT DevKit';
      WindowOptions windowOptions = WindowOptions(
        size: const Size(1100, 750),
        center: true,
        backgroundColor: Colors.white,
        skipTaskbar: false,
        title: windowTitle,
        titleBarStyle: TitleBarStyle.normal,
        minimumSize: const Size(800, 600),
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setResizable(true);
        await windowManager.setMinimizable(true);
        await windowManager.setMaximizable(true);
      });

      runApp(IoTDevKitApp(
        themeManager: themeManager,
        processShard: processShard,
        performanceMode: performanceMode,
      ));
    } catch (e, stack) {
      await _writePanicLog('Initialization failed: $e', stack);
      rethrow;
    }
  }, (error, stack) {
    _writePanicLog('Uncaught Dart Exception: $error', stack);
    if (kDebugMode) {
      debugPrint('Uncaught Error: $error');
      debugPrint(stack.toString());
    }
  });
}

class IoTDevKitApp extends StatelessWidget {
  final LabThemeManager themeManager;
  final ProcessShard processShard;
  final bool performanceMode;

  const IoTDevKitApp({
    super.key,
    required this.themeManager,
    this.processShard = ProcessShard.single,
    this.performanceMode = true,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LabThemeManager>.value(value: themeManager),
        ChangeNotifierProvider<LanguageProvider>(
            create: (_) => LanguageProvider()),
        ChangeNotifierProvider<StatusRegistry>(create: (_) => StatusRegistry()),
        ChangeNotifierProvider<FeatureVisibilityProvider>(
          create: (_) => FeatureVisibilityProvider(),
        ),
        ChangeNotifierProvider<TimesheetProvider>(
          create: (_) => TimesheetProvider(),
        ),
        ChangeNotifierProvider<MqttController>(
          create: (_) => MqttController(
            processShard: processShard,
            enableDetailedLogs: !performanceMode,
          ),
        ),
        ChangeNotifierProxyProvider<MqttController, StatisticsCollector>(
          create: (_) => StatisticsCollector(),
          update: (_, controller, __) => controller.statisticsCollector,
        ),
      ],
      child: Consumer2<LabThemeManager, LanguageProvider>(
        builder: (context, themeManager, languageProvider, child) {
          final base = themeManager.theme.themeData;
          // P0→P1 compat bridge: legacy screens (simulator_panel,
          // simulator_log_dock, timestamp_tool) still read AppThemeEffect.
          // Keep LabTokens and append a neutral AppThemeEffect so they
          // don't null-crash until P1 migrates them off it.
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
            title: processShard.isSharded
                ? 'IoT DevKit [${processShard.label}]'
                : 'IoT DevKit',
            theme: themed,
            darkTheme: themed,
            themeMode: themeManager.theme.brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            themeAnimationDuration: const Duration(milliseconds: 240),
            themeAnimationCurve: Curves.easeOutCubic,
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
            home: const AppRoot(),
          );
        },
      ),
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'IoT DevKit',
          menus: [
            PlatformMenuItem(
              label: l10n.menuAbout,
              onSelected: () {
                AboutDialogHelper.showAboutDialog(context);
              },
            ),
            PlatformMenuItem(
              label: l10n.menuOpenLogs,
              onSelected: () {
                LogStorageService.instance.openLogFolder();
              },
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.quit),
              ],
            ),
          ],
        ),
      ],
      child: AnimatedTheme(
        data: Theme.of(context),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: const HomeScreen(),
      ),
    );
  }
}
