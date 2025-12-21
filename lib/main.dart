import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'services/mqtt_controller.dart';
import 'services/theme_manager.dart';
import 'services/language_provider.dart';
import 'services/status_registry.dart';
import 'utils/statistics_collector.dart';
import 'ui/screens/home_screen.dart';
import 'utils/version_helper.dart';

void main() {
  runApp(const IoTDevKitApp());
}

class IoTDevKitApp extends StatelessWidget {
  const IoTDevKitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeManager>(create: (_) => ThemeManager()),
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
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'IoT DevKit',
          menus: [
            PlatformMenuItem(
              label: 'About IoT DevKit',
              onSelected: () async {
                final version = await VersionHelper.getAppVersion();
                if (context.mounted) {
                  showAboutDialog(
                    context: context,
                    applicationName: 'IoT DevKit',
                    applicationVersion: version,
                    applicationIcon: const FlutterLogo(),
                    applicationLegalese: 'Copyright © 2025 Chen Xu & Antigravity',
                    children: [
                      const SizedBox(height: 10),
                      const Text('A powerful MQTT Device Simulator for IoT development.'),
                      const SizedBox(height: 10),
                      const Text('Built with Flutter & Dart.'),
                    ],
                  );
                }
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
      child: const HomeScreen(),
    );
  }
}
    );
  }
}
