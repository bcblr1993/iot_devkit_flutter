import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/mqtt_controller.dart';
import '../../services/language_provider.dart';
import '../../services/status_registry.dart';
import '../../services/theme_manager.dart';
import '../widgets/simulator_panel.dart';
import '../widgets/log_console.dart';
import '../tools/timestamp_tool.dart';
import '../tools/json_formatter_tool.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final List<LogEntry> _logs = [];
  bool _isLogExpanded = false;

  @override
  void initState() {
    super.initState();
    // Hook up logging
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Provider.of<MqttController>(context, listen: false);
      controller.onLog = (String message, String type) {
        if (!mounted) return;
        setState(() {
          _logs.add(LogEntry(message, type, DateTime.now().toIso8601String().split('T')[1].substring(0, 8)));
          // Limit logs to prevent memory issues
          if (_logs.length > 2000) {
            _logs.removeRange(0, 500);
          }
        });
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: <NavigationRailDestination>[
              NavigationRailDestination(
                icon: const Icon(Icons.settings_input_component),
                label: Text(l10n.navSimulator),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.access_time),
                label: Text(l10n.navTimestamp),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.code),
                label: Text(l10n.navJson),
              ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // shrink wrap
                    children: [
                      // Language Switcher
                      Consumer<LanguageProvider>(
                        builder: (context, langProvider, child) {
                          return PopupMenuButton<Locale>(
                            icon: const Icon(Icons.language),
                            tooltip: l10n.selectLanguage,
                            onSelected: (Locale locale) {
                              langProvider.setLocale(locale);
                            },
                            itemBuilder: (BuildContext context) {
                              return const [
                                PopupMenuItem(value: Locale('en'), child: Text('English')),
                                PopupMenuItem(value: Locale('zh'), child: Text('简体中文')),
                              ];
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      // Theme Switcher
                      Consumer<ThemeManager>(
                        builder: (context, themeManager, child) {
                          return PopupMenuButton<String>(
                            icon: const Icon(Icons.palette),
                            tooltip: l10n.selectTheme,
                            onSelected: (String themeName) {
                              themeManager.setTheme(themeName);
                            },
                            itemBuilder: (BuildContext context) {
                              return themeManager.availableThemes.map((String theme) {
                                String label;
                                switch (theme) {
                                  case 'neon-core': label = l10n.themeNeonCore; break;
                                  case 'phantom-violet': label = l10n.themePhantomViolet; break;
                                  case 'aerix-amber': label = l10n.themeAerixAmber; break;
                                  case 'vitality-lime': label = l10n.themeVitalityLime; break;
                                  case 'azure-radiance': label = l10n.themeAzureRadiance; break;
                                  case 'glassy-ice': label = l10n.themeGlassyIce; break;
                                  case 'minimal-white': label = l10n.themeMinimalWhite; break;
                                  case 'classic-dark': label = l10n.themeClassicDark; break;
                                  case 'deep-glass': label = l10n.themeDeepGlass; break;
                                  case 'clear-glass': label = l10n.themeClearGlass; break;
                                  default: label = theme;
                                }
                                return CheckedPopupMenuItem<String>(
                                  value: theme,
                                  checked: theme == themeManager.currentThemeName,
                                  child: Text(label),
                                );
                              }).toList();
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedIndex == 0) {
      return Column(
        children: [
          Expanded(
            child: SimulatorPanel(
              logs: _logs,
              isLogExpanded: _isLogExpanded,
              onToggleLog: () {
                setState(() {
                  _isLogExpanded = !_isLogExpanded;
                });
              },
              onClearLog: () {
                setState(() {
                  _logs.clear();
                });
              },
            ),
          ),
          
          // Status Banner (Bottom)
          Consumer<StatusRegistry>(
            builder: (context, registry, child) {
              final color = registry.color;
              final msg = registry.message;
              
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: SizeTransition(sizeFactor: animation, child: child));
                },
                child: msg.isEmpty 
                  ? const SizedBox(key: ValueKey('empty_status'))
                  : Container(
                      key: const ValueKey('active_status'),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              msg,
                              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
              );
            },
          ),
        ],
      );
    } else if (_selectedIndex == 1) {
      return const TimestampTool();
    } else {
      return const JsonFormatterTool();
    }
  }
}
