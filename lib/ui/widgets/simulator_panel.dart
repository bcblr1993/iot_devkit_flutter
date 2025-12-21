import 'package:flutter/material.dart';
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

class SimulatorPanel extends StatefulWidget {
  final List<LogEntry> logs;
  final bool isLogExpanded;
  final VoidCallback onToggleLog;
  final VoidCallback onClearLog;

  const SimulatorPanel({
    super.key,
    required this.logs,
    required this.isLogExpanded,
    required this.onToggleLog,
    required this.onClearLog,
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

    return Column(
      children: [
        // Shared MQTT Config Section
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              _buildMqttSection(isRunning, l10n),
              const SizedBox(height: 12),
              _buildStats(l10n),
            ],
          ),
        ),

        // Tab Bar
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: [
            Tab(text: l10n.basicMode),
            Tab(text: l10n.advancedMode),
          ],
        ),
        
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildBasicTab(mqttController, isRunning, l10n),
              _buildAdvancedTab(mqttController, isRunning, l10n),
            ],
          ),
        ),
        const Divider(height: 1),
        
        // Persistent Action Buttons
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: _buildActionButtons(
            mqttController, 
            isRunning, 
            l10n, 
            isBasic: _tabController.index == 0
          ),
        ),

        const Divider(height: 1),
        // Integrated Log Console
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: widget.isLogExpanded ? MediaQuery.of(context).size.height * 0.35 : 40,
          child: LogConsole(
            logs: widget.logs,
            isExpanded: widget.isLogExpanded,
            onToggle: widget.onToggleLog,
            onClear: widget.onClearLog,
          ),
        ),
      ],
    );
  }

  Widget _buildMqttSection(bool isRunning, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(l10n.mqttBroker),
        Row(
          children: [
            Expanded(flex: 3, child: _buildTextField(l10n.host, _hostController, isRunning)),
            const SizedBox(width: 8),
            Expanded(flex: 1, child: _buildTextField(l10n.port, _portController, isRunning, isNumber: true)),
          ],
        ),
        const SizedBox(height: 8),
        _buildTextField(l10n.topic, _topicController, isRunning),
      ],
    );
  }

  Widget _buildBasicTab(MqttController controller, bool isRunning, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Form(
        key: _formKeyBasic,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(l10n.deviceConfig),
          Row(
            children: [
              Expanded(child: _buildTextField(l10n.startIndex, _startIdxController, isRunning, isNumber: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField(l10n.endIndex, _endIdxController, isRunning, isNumber: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField(l10n.deviceName, _devicePrefixController, isRunning)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField(l10n.clientId, _clientIdPrefixController, isRunning)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField(l10n.username, _usernamePrefixController, isRunning)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField(l10n.password, _passwordPrefixController, isRunning)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField(l10n.dataPointCount, _dataPointController, isRunning, isNumber: true, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField(l10n.interval, _intervalController, isRunning, isNumber: true)),
            ],
          ),
          const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: l10n.format, border: const OutlineInputBorder()),
              value: _format,
              items: [
                DropdownMenuItem(value: 'default', child: Text(l10n.formatDefault)),
                DropdownMenuItem(value: 'tn', child: Text(l10n.formatTieNiu)),
                DropdownMenuItem(value: 'tn-empty', child: Text(l10n.formatTieNiuEmpty)),
              ],
              onChanged: isRunning ? null : (v) => setState(() => _format = v!),
            ),

            const SizedBox(height: 12),
            const Divider(),
            CustomKeysManager(
              keys: _basicCustomKeys,
              isLocked: isRunning,
              maxKeys: int.tryParse(_dataPointController.text) ?? 10,
              onKeysChanged: (newKeys) {
                setState(() {
                  _basicCustomKeys = newKeys;
                });
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedTab(MqttController controller, bool isRunning, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            GroupsManager(
              groups: _groups,
              isLocked: isRunning,
              onGroupsChanged: (newGroups) {
                _groups = newGroups;
              },
            ),
            const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActionButtons(MqttController controller, bool isRunning, AppLocalizations l10n, {required bool isBasic}) {
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
                icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
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
                  icon: const Icon(Icons.download, size: 18),
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
                  icon: const Icon(Icons.upload, size: 18),
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
    }
  }

  void _handleStartAdvanced(MqttController controller) {
     final config = _getCompleteConfig();
     ConfigService.saveToLocalStorage(config);
     controller.start(config);
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
      // Silent cancel - matches system style
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

  Widget _buildStats(AppLocalizations l10n) {
    return Consumer<StatisticsCollector>(
      builder: (context, stats, child) {
        final s = stats.getSnapshot();
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(child: _statBox('📱', '${l10n.online}', '${s['onlineDevices']} / ${s['totalDevices']}', colorScheme.primary)),
                const SizedBox(width: 8),
                Expanded(child: _statBox('📨', '发送', '${s['totalMessages']}', colorScheme.secondary)),
                const SizedBox(width: 8),
                Expanded(child: _statBox('✅', '成功', '${s['successCount']} (${s['successRate']}%)', Colors.green)), // Keep green for success semantics
                const SizedBox(width: 8),
                Expanded(child: _statBox('❌', '失败', '${s['failureCount']}', colorScheme.error)),
                const SizedBox(width: 8),
                Expanded(child: _statBox('⏱️', '延迟', '${s['avgLatency']} ms', colorScheme.tertiary ?? Colors.orange)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statBox(String icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
              Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isLocked, {bool isNumber = false, Function(String)? onChanged}) {
    return TextFormField(
      controller: controller,
      enabled: !isLocked,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
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
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
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
