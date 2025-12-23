import 'package:flutter/material.dart';
import 'dart:async';
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
  
  // Performance Optimization: Log Throttling
  final List<LogEntry> _logBuffer = [];
  Timer? _logThrottleTimer;

  @override
  void initState() {
    super.initState();
    // Hook up logging
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Provider.of<MqttController>(context, listen: false);
      controller.onLog = (String message, String type, {String? tag}) {
        if (!mounted) return;
        
        // Check for critical errors to show in Status Banner
        if (type == 'error' && message.contains('Max reconnect attempts')) {
           Provider.of<StatusRegistry>(context, listen: false).setStatus(message, Theme.of(context).colorScheme.error);
        }
        
        final now = DateTime.now();
        final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        
        // Add to buffer (Background operation, no setState)
        _logBuffer.add(LogEntry(message, type, timestamp, tag: tag));

        // Schedule batch update if not already running
        if (_logThrottleTimer == null || !_logThrottleTimer!.isActive) {
          _logThrottleTimer = Timer(const Duration(milliseconds: 300), _flushLogs);
        }
      };
    });
  }

  void _flushLogs() {
    if (!mounted || _logBuffer.isEmpty) return;

    setState(() {
      _logs.addAll(_logBuffer);
      _logBuffer.clear();
      
      // Limit logs to prevent memory issues
      if (_logs.length > 2000) {
        _logs.removeRange(0, _logs.length - 1500); // Keep last 1500
      }
    });
  }

  @override
  void dispose() {
    _logThrottleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      body: Row(
        children: [
          RepaintBoundary(
            child: NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            minWidth: 48.0,
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Language Switcher
                      Consumer<LanguageProvider>(
                        builder: (context, langProvider, child) {
                          final currentLang = langProvider.currentLocale.languageCode == 'zh' ? '中' : 'EN';
                          return Tooltip(
                            message: l10n.selectLanguage,
                            child: PopupMenuButton<Locale>(
                              onSelected: (Locale locale) {
                                langProvider.setLocale(locale);
                              },
                              itemBuilder: (BuildContext context) {
                                return [
                                  CheckedPopupMenuItem(
                                    value: const Locale('en'),
                                    checked: langProvider.currentLocale.languageCode == 'en',
                                    child: const Text('English'),
                                  ),
                                  CheckedPopupMenuItem(
                                    value: const Locale('zh'),
                                    checked: langProvider.currentLocale.languageCode == 'zh',
                                    child: const Text('简体中文'),
                                  ),
                                ];
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.language, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    const SizedBox(height: 2),
                                    Text(currentLang, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      // Theme Switcher
                      Consumer<ThemeManager>(
                        builder: (context, themeManager, child) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          return Tooltip(
                            message: l10n.selectTheme,
                            child: PopupMenuButton<String>(
                              onSelected: (String themeName) {
                                themeManager.setTheme(themeName);
                              },
                              itemBuilder: (BuildContext context) {
                                return themeManager.availableThemes.map((String theme) {
                                  String label;
                                  switch (theme) {
                                    case 'matrix-emerald': label = l10n.themeMatrixEmerald; break;
                                    case 'forest-mint': label = l10n.themeForestMint; break;
                                    case 'arctic-blue': label = l10n.themeArcticBlue; break;
                                    case 'deep-ocean': label = l10n.themeDeepOcean; break;
                                    case 'crimson-night': label = l10n.themeCrimsonNight; break;
                                    case 'ruby-elegance': label = l10n.themeRubyElegance; break;
                                    case 'void-black': label = l10n.themeVoidBlack; break;
                                    case 'graphite-pro': label = l10n.themeGraphitePro; break;
                                    default: label = theme;
                                  }
                                  return CheckedPopupMenuItem<String>(
                                    value: theme,
                                    checked: theme == themeManager.currentThemeName,
                                    child: Text(label),
                                  );
                                }).toList();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isDark ? '暗' : '亮',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: RepaintBoundary(child: _buildBody()),
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
