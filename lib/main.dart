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
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
