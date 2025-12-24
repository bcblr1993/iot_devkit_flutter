import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'services/mqtt_controller.dart';
import 'services/theme_manager.dart';
import 'services/language_provider.dart';
import 'services/status_registry.dart';
import 'utils/statistics_collector.dart';
import 'ui/screens/home_screen.dart';
import 'utils/about_dialog_helper.dart';
import 'services/log_storage_service.dart';

import 'package:window_manager/window_manager.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize File Logging Service
  await LogStorageService.instance.init();

  // 2. Initialize Logging
  Logger.root.level = Level.ALL; // Defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    LogStorageService.instance.write(record);
    if (kDebugMode) {
      debugPrint('${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
      if (record.error != null) {
        debugPrint('Error: ${record.error}');
      }
    }
  });

  await windowManager.ensureInitialized();
  
  // 3. Preload Theme Preference (Sync) to avoid FOUC
  final prefs = await SharedPreferences.getInstance();
  final String? savedTheme = prefs.getString(ThemeManager.kThemePreferenceKey);

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1100, 750),
    center: true,
    backgroundColor: Colors.white,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    minimumSize: Size(800, 600),
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setResizable(true);
    await windowManager.setMinimizable(true);
    await windowManager.setMaximizable(true);
  });

  runApp(IoTDevKitApp(initialTheme: savedTheme));
}

class IoTDevKitApp extends StatelessWidget {
  final String? initialTheme;
  const IoTDevKitApp({super.key, this.initialTheme});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeManager>(create: (_) => ThemeManager(initialTheme: initialTheme)),
        ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
        ChangeNotifierProvider<StatusRegistry>(create: (_) => StatusRegistry()),
        ChangeNotifierProvider<MqttController>(create: (_) => MqttController()),
        ChangeNotifierProxyProvider<MqttController, StatisticsCollector>(
          create: (_) => StatisticsCollector(), 
          update: (_, controller, __) => controller.statisticsCollector,
        ),
      ],
      child: Consumer2<ThemeManager, LanguageProvider>(
        builder: (context, themeManager, languageProvider, child) {
          return MaterialApp(
            title: 'IoT DevKit',
            theme: themeManager.currentTheme,
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
              label: l10n.menuOpenLogs ?? 'Open Logs Location',
              onSelected: () {
                LogStorageService.instance.openLogFolder();
              },
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
              ],
            ),
          ],
        ),
      ],
      child: AnimatedTheme(
        data: Theme.of(context),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: const HomeScreen(),
      ),
    );
  }
}
