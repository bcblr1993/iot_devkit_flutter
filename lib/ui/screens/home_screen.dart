import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/mqtt_controller.dart';
import '../../services/language_provider.dart';
import '../../services/status_registry.dart';
import '../../services/theme_manager.dart';
import '../../utils/about_dialog_helper.dart';
import '../../utils/app_dialog_helper.dart';
import '../widgets/simulator_panel.dart';
import '../widgets/log_console.dart';
import '../tools/timestamp_tool.dart';
import '../tools/json_formatter_tool.dart';
import '../../services/log_storage_service.dart';

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
                      // Unified Settings Menu
                      Tooltip(
                        message: l10n.menuSettings ?? 'Settings',
                        child: PopupMenuButton<String>(
                          icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          tooltip: '', // Disable default tooltip to use custom one
                          offset: const Offset(50, 0), // Position menu to the right
                          position: PopupMenuPosition.over,
                          onSelected: (String action) {
                            switch (action) {
                              case 'theme':
                                _showThemeDialog(context);
                                break;
                              case 'language':
                                _showLanguageDialog(context);
                                break;
                              case 'logs':
                                LogStorageService.instance.openLogFolder();
                                break;
                              case 'about':
                                AboutDialogHelper.showAboutDialog(context);
                                break;
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            return [
                              // Theme
                              PopupMenuItem(
                                value: 'theme',
                                child: Row(
                                  children: [
                                    Icon(Icons.palette_outlined, size: 20, color: Theme.of(context).colorScheme.onSurface),
                                    const SizedBox(width: 12),
                                    Text(l10n.selectTheme, style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ),
                              // Language
                              PopupMenuItem(
                                value: 'language',
                                child: Row(
                                  children: [
                                    Icon(Icons.language, size: 20, color: Theme.of(context).colorScheme.onSurface),
                                    const SizedBox(width: 12),
                                    Text(l10n.selectLanguage, style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              // Open Logs
                              PopupMenuItem(
                                value: 'logs',
                                child: Row(
                                  children: [
                                    Icon(Icons.folder_open, size: 20, color: Theme.of(context).colorScheme.onSurface),
                                    const SizedBox(width: 12),
                                    Text(l10n.menuOpenLogs ?? 'Open Logs', style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ),
                              // About
                              PopupMenuItem(
                                value: 'about',
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.onSurface),
                                    const SizedBox(width: 12),
                                    Text(l10n.menuAbout, style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ),
                            ];
                          },
                        ),
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

  void _showThemeDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    AppDialogHelper.show(
      context: context,
      title: l10n.selectTheme,
      icon: Icons.palette_outlined,
      content: Consumer<ThemeManager>(
        builder: (context, themeManager, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: themeManager.availableThemes.map((String theme) {
              String label;
                switch (theme) {
                case 'forest-mint': label = l10n.themeForestMint; break;
                case 'cosmic-void': label = l10n.themeCosmicVoid; break;
                case 'polar-blue': label = l10n.themePolarBlue; break;
                case 'porcelain-red': label = l10n.themePorcelainRed; break;
                case 'wisteria-white': label = l10n.themeWisteriaWhite; break;
                case 'amber-glow': label = l10n.themeAmberGlow; break;
                case 'graphite-mono': label = l10n.themeGraphiteMono; break;
                case 'azure-coast': label = l10n.themeAzureCoast; break;
                default: label = theme;
              }
              
              final isSelected = themeManager.currentThemeName == theme;
              final primaryColor = Theme.of(context).colorScheme.primary;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      themeManager.setTheme(theme);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor.withOpacity(0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? primaryColor.withOpacity(0.3) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? primaryColor : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? primaryColor : Theme.of(context).disabledColor,
                                width: 2,
                              ),
                            ),
                            child: isSelected 
                              ? const Center(child: Icon(Icons.check, size: 12, color: Colors.white))
                              : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    AppDialogHelper.show(
      context: context,
      title: l10n.selectLanguage,
      icon: Icons.language_outlined,
      content: Consumer<LanguageProvider>(
        builder: (context, langProvider, child) {
          final options = [
            {'code': 'en', 'label': 'English'},
            {'code': 'zh', 'label': '简体中文'},
          ];
          
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              final code = opt['code']!;
              final label = opt['label']!;
              final isSelected = langProvider.currentLocale.languageCode == code;
              final primaryColor = Theme.of(context).colorScheme.primary;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      langProvider.setLocale(Locale(code));
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor.withOpacity(0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? primaryColor.withOpacity(0.3) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? primaryColor : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? primaryColor : Theme.of(context).disabledColor,
                                width: 2,
                              ),
                            ),
                            child: isSelected 
                              ? const Center(child: Icon(Icons.check, size: 12, color: Colors.white))
                              : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        // Tab 0: Simulator
        Column(
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
        ),
        
        // Tab 1: Timestamp
        const TimestampTool(),
        
        // Tab 2: JSON
        const JsonFormatterTool(),
      ],
    );
  }
}
