import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/mqtt_controller.dart';
import '../../utils/statistics_collector.dart';
import '../../models/group_config.dart';
import '../../models/custom_key_config.dart';
import 'groups_manager.dart';
import 'custom_keys_manager.dart';
import '../../services/config_service.dart';
import '../../services/status_registry.dart';
import 'log_console.dart';
import '../styles/app_theme_effect.dart';
import '../../services/theme_manager.dart';

class SimulatorPanel extends StatefulWidget {
  final List<LogEntry> logs;
  final bool isLogExpanded;
  final VoidCallback onToggleLog;
  final VoidCallback onClearLog;
  final VoidCallback? onSimulationStarted;

  const SimulatorPanel({
    super.key,
    required this.logs,
    required this.isLogExpanded,
    required this.onToggleLog,
    required this.onClearLog,
    this.onSimulationStarted,
  });

  @override
  State<SimulatorPanel> createState() => _SimulatorPanelState();
}

class _SimulatorPanelState extends State<SimulatorPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKeyBasic = GlobalKey<FormState>();
  
  // Basic Mode Controllers
  final _hostController = TextEditingController(text: 'localhost');
  final _portController = TextEditingController(text: '1883');
  final _topicController = TextEditingController(text: 'v1/devices/me/telemetry');
  bool _isStatsExpanded = true;
  bool _isBasicConfigExpanded = true;
  final _startIdxController = TextEditingController(text: '1');
  final _endIdxController = TextEditingController(text: '10');
  final _intervalController = TextEditingController(text: '1');
  final _dataPointController = TextEditingController(text: '10');
  
  // Prefix Controllers for Basic Mode
  final _devicePrefixController = TextEditingController(text: 'device');
  final _clientIdPrefixController = TextEditingController(text: 'device');
  final _usernamePrefixController = TextEditingController(text: 'user');
  final _passwordPrefixController = TextEditingController(text: 'pass');

  String _format = 'default';
  List<CustomKeyConfig> _basicCustomKeys = [];

  // Advanced Mode State
  List<GroupConfig> _groups = [];
  bool _isLogMaximized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Update action buttons when tab changes
      }
    });
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await ConfigService.loadFromLocalStorage();
    if (config != null) {
      _applyConfig(config);
    }
  }

  void _applyConfig(Map<String, dynamic> config) {
    setState(() {
      if (config['mqtt'] != null) {
        _hostController.text = config['mqtt']['host'] ?? 'localhost';
        _portController.text = (config['mqtt']['port'] ?? 1883).toString();
        _topicController.text = config['mqtt']['topic'] ?? 'v1/devices/me/telemetry';
      }

      if (config['mode'] == 'advanced') {
        _tabController.index = 1;
      } else {
        _tabController.index = 0;
      }

      // Basic Mode mapping
      _startIdxController.text = (config['device_start_number'] ?? 1).toString();
      _endIdxController.text = (config['device_end_number'] ?? 10).toString();
      _intervalController.text = (config['send_interval'] ?? 1).toString();
      
      _clientIdPrefixController.text = config['client_id_prefix'] ?? 'device';
      _devicePrefixController.text = config['device_prefix'] ?? 'device';
      _usernamePrefixController.text = config['username_prefix'] ?? 'user';
      _passwordPrefixController.text = config['password_prefix'] ?? 'pass';

      if (config['data'] != null) {
        _format = config['data']['format'] ?? 'default';
        _dataPointController.text = (config['data']['data_point_count'] ?? 10).toString();
      }

      if (config['custom_keys'] != null) {
        _basicCustomKeys = (config['custom_keys'] as List)
            .map((e) => CustomKeyConfig.fromJson(e))
            .toList();
      }

      if (config['groups'] != null) {
        _groups = (config['groups'] as List)
            .map((e) => GroupConfig.fromJson(e))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mqttController = Provider.of<MqttController>(context);
    final isRunning = mqttController.isRunning;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final effect = theme.extension<AppThemeEffect>() ?? 
                   const AppThemeEffect(animationCurve: Curves.easeInOut, layoutDensity: 1.0, icons: AppIcons.standard);

    return Stack(
      children: [
        Positioned.fill(
          bottom: 40, // Reserve space for collapsed logs
          child: Column(
            children: [
              // Shared MQTT Config Section
              Padding(
                padding: EdgeInsets.all(12.0 * effect.layoutDensity),
                child: Column(
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: !isRunning
                          ? Column(
                              children: [
                                _buildMqttSection(isRunning, l10n, effect),
                                SizedBox(height: 12 * effect.layoutDensity),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    _buildStats(l10n, effect),
                  ],
                ),
              ),

              // Integrated Tabs & Content
              Expanded(
                child: IgnorePointer(
                  ignoring: isRunning,
                  child: Opacity(
                    opacity: isRunning ? 0.7 : 1.0,
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0 * effect.layoutDensity),
                          child: TabBar(
                            controller: _tabController,
                            labelColor: theme.colorScheme.primary,
                            unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
                            indicatorColor: theme.colorScheme.primary,
                            dividerColor: Colors.transparent,
                            tabs: [
                              Tab(text: l10n.basicMode),
                              Tab(text: l10n.advancedMode),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              KeepAliveWrapper(child: _buildBasicTab(mqttController, isRunning, l10n)),
                              KeepAliveWrapper(child: _buildAdvancedTab(mqttController, isRunning, l10n)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              
              // Persistent Action Buttons
              Padding(
                padding: EdgeInsets.all(12.0 * effect.layoutDensity),
                child: _buildActionButtons(
                  mqttController, 
                  isRunning, 
                  l10n, 
                  isBasic: _tabController.index == 0,
                  effect: effect,
                ),
              ),
            ],
          ),
        ),

        // Floating Log Console
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: effect.animationCurve,
          left: 0, 
          right: 0,
          bottom: 0,
          height: _isLogMaximized 
              ? MediaQuery.of(context).size.height 
              : (widget.isLogExpanded ? MediaQuery.of(context).size.height * 0.5 : 40),
          child: Material(
            elevation: 16,
            shadowColor: Colors.black.withOpacity(0.5),
            child: LogConsole(
              logs: widget.logs,
              isExpanded: widget.isLogExpanded,
              onToggle: widget.onToggleLog,
              onClear: widget.onClearLog,
              isMaximized: _isLogMaximized,
              onMaximize: () => setState(() => _isLogMaximized = !_isLogMaximized),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMqttSection(bool isRunning, AppLocalizations l10n, AppThemeEffect effect) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Check if we should use the "Featured Highlight" style (Green card in Elegant Forest)
    final bool useFeaturedStyle = colorScheme.primaryContainer != colorScheme.surface && 
                                 colorScheme.primaryContainer != colorScheme.background;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          l10n.mqttBroker, 
          color: useFeaturedStyle ? colorScheme.onPrimaryContainer : null,
        ),
        AnimatedCrossFade(
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(flex: 3, child: _buildTextField(l10n.host, _hostController, isRunning, customColor: useFeaturedStyle ? colorScheme.onPrimaryContainer : null)),
                    const SizedBox(width: 8),
                    Expanded(flex: 1, child: _buildTextField(l10n.port, _portController, isRunning, isNumber: true, customColor: useFeaturedStyle ? colorScheme.onPrimaryContainer : null)),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTextField(l10n.topic, _topicController, isRunning, customColor: useFeaturedStyle ? colorScheme.onPrimaryContainer : null),
              ],
            ),
          ),
          secondChild: const SizedBox(width: double.infinity),
          crossFadeState: isRunning ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );

    if (useFeaturedStyle) {
      return Container(
        padding: EdgeInsets.fromLTRB(
          16 * effect.layoutDensity, 
          32 * effect.layoutDensity, 
          16 * effect.layoutDensity, 
          16 * effect.layoutDensity
        ),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(theme.cardTheme.shape is RoundedRectangleBorder 
            ? (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius.resolve(Directionality.of(context)).topLeft.x
            : 16),
        ),
        child: content,
      );
    }

    return content;
  }

  Widget _buildBasicTab(MqttController controller, bool isRunning, AppLocalizations l10n) {
    final theme = Theme.of(context);
    
    // Calculate device count
    int start = int.tryParse(_startIdxController.text) ?? 1;
    int end = int.tryParse(_endIdxController.text) ?? 10;
    int count = (end - start + 1).clamp(0, 99999);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Form(
        key: _formKeyBasic,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scope Section
            _buildSectionHeader(l10n.sectionDeviceScope, trailing: '${l10n.unitDevices}: $count'),
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0,
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: _buildTextField(l10n.startIndex, _startIdxController, isRunning, isNumber: true, onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(l10n.endIndex, _endIdxController, isRunning, isNumber: true, onChanged: (_) => setState(() {}))),
                  ],
                ),
              ),
            ),

            // Naming Section
            _buildSectionHeader(l10n.sectionNamingAuth),
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0,
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildTextField(l10n.deviceName, _devicePrefixController, isRunning)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField(l10n.clientId, _clientIdPrefixController, isRunning)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(l10n.username, _usernamePrefixController, isRunning)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField(l10n.password, _passwordPrefixController, isRunning)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Data Config
            _buildSectionHeader(l10n.sectionDataConfig),
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0,
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: _buildTextField(l10n.interval, _intervalController, isRunning, isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(l10n.dataPointCount, _dataPointController, isRunning, isNumber: true, onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        borderRadius: BorderRadius.circular(12),
                        dropdownColor: theme.colorScheme.surface, // Use surface color
                        style: TextStyle(
                          color: theme.colorScheme.onSurface, 
                          fontSize: 14 
                        ),
                        iconEnabledColor: theme.colorScheme.onSurface.withOpacity(0.7),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          labelText: 'Format', // Should use l10n but format isn't in l10n params passed
                        ),
                        value: _format,
                        items: [
                          DropdownMenuItem(value: 'default', child: Text(l10n.formatDefault, style: const TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'tn', child: Text(l10n.formatTieNiu, style: const TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'tn-empty', child: Text(l10n.formatTieNiuEmpty, style: const TextStyle(fontSize: 13))),
                        ],
                        onChanged: isRunning ? null : (String? value) {
                          if (value != null) {
                            setState(() {
                              _format = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            CustomKeysManager(
              keys: _basicCustomKeys,
              isLocked: isRunning,
              maxKeys: int.tryParse(_dataPointController.text) ?? 10,
              enableExpandedLayout: false,
              onKeysChanged: (newKeys) => setState(() => _basicCustomKeys = newKeys),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedTab(MqttController controller, bool isRunning, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final effect = theme.extension<AppThemeEffect>() ?? 
                   const AppThemeEffect(animationCurve: Curves.easeInOut, layoutDensity: 1.0, icons: AppIcons.standard);
                   
    Widget content = GroupsManager(
      groups: _groups,
      isLocked: isRunning,
      onGroupsChanged: (newGroups) {
        _groups = newGroups;
      },
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(12.0 * effect.layoutDensity),
      child: content,
    );
  }

  Widget _buildActionButtons(MqttController controller, bool isRunning, AppLocalizations l10n, {required bool isBasic, required AppThemeEffect effect}) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    final primaryColor = theme.colorScheme.primary;

    return Column(
      children: [
        _AnimatedTactileButton(
          onPressed: isRunning 
            ? () => controller.stop()
            : () => isBasic ? _handleStartBasic(controller) : _handleStartAdvanced(controller),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: SizedBox(
              key: ValueKey(isRunning),
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () {}, // Dummy to keep button in "enabled" visual state
                icon: Icon(isRunning ? effect.icons.stop : effect.icons.play),
                label: Text(isRunning ? l10n.stopSimulation : l10n.startSimulation),
                style: FilledButton.styleFrom(
                  backgroundColor: isRunning ? errorColor : primaryColor,
                  foregroundColor: isRunning ? theme.colorScheme.onError : theme.colorScheme.onPrimary,
                  disabledBackgroundColor: isRunning ? errorColor : primaryColor,
                  disabledForegroundColor: isRunning ? theme.colorScheme.onError : theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AnimatedTactileButton(
                onPressed: isRunning ? null : _handleExport,
                child: OutlinedButton.icon(
                  onPressed: isRunning ? null : () {}, // Reflect correct enabled/disabled state
                  icon: Icon(effect.icons.download, size: 18),
                  label: Text(l10n.exportConfig),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnimatedTactileButton(
                onPressed: isRunning ? null : _handleImport,
                child: OutlinedButton.icon(
                  onPressed: isRunning ? null : () {}, // Reflect correct enabled/disabled state
                  icon: Icon(effect.icons.upload, size: 18),
                  label: Text(l10n.importConfig),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Handlers
  
  // Handlers
  void _handleStartBasic(MqttController controller) {
    if (_formKeyBasic.currentState!.validate()) {
       final config = _getCompleteConfig();
       ConfigService.saveToLocalStorage(config);
       controller.start(config);
       widget.onSimulationStarted?.call();
    }
  }

  void _handleStartAdvanced(MqttController controller) {
     final config = _getCompleteConfig();
     ConfigService.saveToLocalStorage(config);
     controller.start(config);
     widget.onSimulationStarted?.call();
  }

  void _setStatus(String msg, Color color) {
    if (mounted) {
      Provider.of<StatusRegistry>(context, listen: false).setStatus(msg, color);
    }
  }

  Future<void> _handleExport() async {
    final l10n = AppLocalizations.of(context)!;
    final config = _getCompleteConfig();
    final result = await ConfigService.exportToFile(config);
    
    if (result.cancelled) {
      _setStatus(l10n.configExportCancelled, Colors.orange);
      return;
    }

    if (result.success) {
      _setStatus(l10n.configExported, Colors.green);
    } else {
      _setStatus('${l10n.configExportFailed}: ${result.error}', Theme.of(context).colorScheme.error);
    }
  }

  Future<void> _handleImport() async {
    final l10n = AppLocalizations.of(context)!;
    
    // Step 1: Select and validate file first
    final result = await ConfigService.importFromFile();
    debugPrint('[Import] Result: config=${result.config}, error=${result.error}');
    
    // User cancelled file picker or closed dialog
    if (result.config == null && result.error == null) {
      return;
    }
    
    // Step 2: Show error if validation failed
    if (result.error != null) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.importFailed),
            content: Text('${l10n.invalidJson}: ${result.error}'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    // Step 3: Validation passed - show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmImport),
        content: Text(l10n.importWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirmImport),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // Step 4: Apply config
    _applyConfig(result.config!);
    debugPrint('[Import] Applied config. Groups count: ${_groups.length}');
    _setStatus(l10n.configImported, Colors.green);
  }

  Map<String, dynamic> _getCompleteConfig() {
    return {
      'mode': _tabController.index == 0 ? 'basic' : 'advanced',
      'mqtt': {
        'host': _hostController.text,
        'port': int.tryParse(_portController.text) ?? 1883,
        'topic': _topicController.text,
      },
      'device_start_number': int.tryParse(_startIdxController.text) ?? 1,
      'device_end_number': int.tryParse(_endIdxController.text) ?? 10,
      'send_interval': int.tryParse(_intervalController.text) ?? 1,
      'client_id_prefix': _clientIdPrefixController.text,
      'device_prefix': _devicePrefixController.text,
      'username_prefix': _usernamePrefixController.text,
      'password_prefix': _passwordPrefixController.text,
      'data': {
        'format': _format,
        'data_point_count': int.tryParse(_dataPointController.text) ?? 10,
      },
      'custom_keys': _basicCustomKeys,
      'groups': _groups,
    };
  }

  Widget _buildStats(AppLocalizations l10n, AppThemeEffect effect) {
    return Consumer<StatisticsCollector>(
      builder: (context, stats, child) {
        final s = stats.getSnapshot();
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        
        // Check if we should use the "Featured Highlight" style
        final bool useFeaturedStyle = colorScheme.primaryContainer != colorScheme.surface && 
                                     colorScheme.primaryContainer != colorScheme.background;

        Widget content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.dataStatistics, style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold, 
                    color: useFeaturedStyle ? colorScheme.onPrimaryContainer : theme.colorScheme.primary,
                  )),
                  IconButton(
                    icon: Icon(_isStatsExpanded ? Icons.expand_less : Icons.expand_more, 
                      color: useFeaturedStyle ? colorScheme.onPrimaryContainer : theme.colorScheme.primary
                    ),
                    onPressed: () => setState(() => _isStatsExpanded = !_isStatsExpanded),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 20,
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: Row(
                children: [
                  Expanded(child: _statBox('📱', '${l10n.online}', '${s['onlineDevices']} / ${s['totalDevices']} ${l10n.unitDevices}', colorScheme.primary, useFeaturedStyle)),
                  const SizedBox(width: 8),
                  Expanded(child: _statBox('📨', '发送', '${s['totalMessages']} ${l10n.unitMessages}', colorScheme.secondary, useFeaturedStyle)),
                  const SizedBox(width: 8),
                  Expanded(child: _statBox('✅', '成功', '${s['successCount']} (${s['successRate']}%)', Colors.green, useFeaturedStyle)), // Keep green for success semantics
                  const SizedBox(width: 8),
                  Expanded(child: _statBox('❌', '失败', '${s['failureCount']} ${l10n.unitMessages}', colorScheme.error, useFeaturedStyle)),
                  const SizedBox(width: 8),
                  Expanded(child: _statBox('⏱️', '延迟', '${s['avgLatency']} ms', colorScheme.tertiary ?? Colors.orange, useFeaturedStyle)),
                ],
              ),
              secondChild: const SizedBox(width: double.infinity),
              crossFadeState: _isStatsExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 300),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        );

        if (useFeaturedStyle) {
          return Container(
            padding: EdgeInsets.all(16 * effect.layoutDensity),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(theme.cardTheme.shape is RoundedRectangleBorder 
                ? (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius.resolve(Directionality.of(context)).topLeft.x
                : 16),
            ),
            child: content,
          );
        }
        
        // Return without Container in standard modes (to avoid double padding issue if parent has padding)
        // But since we removed Card wrap, we should probably ensure it visually groups if not highlighted.
        // The original code returned a Card. If we remove Card, we might lose visual grouping in standard themes.
        // Let's stick to the requested "Same as MQTT Agent" style which does simple Column if not highlighted.
        return content;
      },
    );
  }

  Widget _statBox(String icon, String label, String value, Color color, bool isInverse) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // In "Featured" mode (e.g. Terminal Green), the background IS primaryContainer.
    // So inner boxes should probably be slightly different or transparent to look good.
    // If isInverse is true, we are on a colored background.
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isInverse ? Colors.black.withOpacity(0.1) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isInverse ? colorScheme.onPrimaryContainer.withOpacity(0.2) : color.withOpacity(0.3)
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Expanded( // Prevent overflow
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label, 
                  style: TextStyle(
                    fontSize: 10, 
                    color: isInverse ? colorScheme.onPrimaryContainer.withOpacity(0.8) : color, 
                    fontWeight: FontWeight.w500
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value, 
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.bold,
                    color: isInverse ? colorScheme.onPrimaryContainer : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isLocked, {bool isNumber = false, Function(String)? onChanged, Color? customColor}) {
    final theme = Theme.of(context);
    
    return TextFormField(
      controller: controller,
      enabled: !isLocked,
      style: customColor != null ? TextStyle(color: customColor) : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: customColor != null ? TextStyle(color: customColor.withOpacity(0.7)) : null,
        floatingLabelStyle: customColor != null ? TextStyle(color: customColor, fontWeight: FontWeight.bold) : null,
        border: const OutlineInputBorder(),
        enabledBorder: customColor != null ? OutlineInputBorder(borderSide: BorderSide(color: customColor.withOpacity(0.5))) : null,
        focusedBorder: customColor != null ? OutlineInputBorder(borderSide: BorderSide(color: customColor, width: 2)) : null,
        isDense: true,
      ),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        if (isNumber && int.tryParse(value) == null) return 'Invalid number';
        return null;
      },
    );
  }
  
  Widget _buildSectionHeader(String title, {Color? color, String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold, 
            color: color ?? Theme.of(context).colorScheme.primary,
          )),
          if (trailing != null)
            Text(trailing, style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
        ],
      ),
    );
  }
}

class _AnimatedTactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;

  const _AnimatedTactileButton({required this.child, this.onPressed});

  @override
  State<_AnimatedTactileButton> createState() => _AnimatedTactileButtonState();
}

class _AnimatedTactileButtonState extends State<_AnimatedTactileButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onPressed == null ? null : (_) => setState(() => _scale = 0.96),
      onTapUp: widget.onPressed == null ? null : (_) => setState(() => _scale = 1.0),
      onTapCancel: widget.onPressed == null ? null : () => setState(() => _scale = 1.0),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: IgnorePointer(child: widget.child),
      ),
    );
  }
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
