import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../services/data_generator.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/mqtt_controller.dart';
import '../../utils/statistics_collector.dart';
import '../../utils/app_dialog_helper.dart';
import '../../utils/app_toast.dart';
import '../../models/group_config.dart';
import '../../models/custom_key_config.dart';
import 'groups_manager.dart';
import 'custom_keys_manager.dart';
import '../../services/config_service.dart';
import '../../services/status_registry.dart';
import 'log_console.dart';
import '../styles/app_theme_effect.dart';
import '../styles/app_constants.dart';
import 'package:file_picker/file_picker.dart';
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
  
  // SSL Config
  bool _enableSsl = false;
  final _caPathController = TextEditingController();
  final _certPathController = TextEditingController();
  final _keyPathController = TextEditingController();

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
        _enableSsl = config['mqtt']['enable_ssl'] ?? false;
        _caPathController.text = config['mqtt']['ca_path'] ?? '';
        _certPathController.text = config['mqtt']['cert_path'] ?? '';
        _keyPathController.text = config['mqtt']['key_path'] ?? '';
      }

      if (config['mode'] == 'advanced') {
      // Use animateTo to ensure TabBar and TabBarView are in sync
      Future.microtask(() {
        if (mounted && _tabController.index != 1) {
          _tabController.animateTo(1);
        }
      });
    } else {
      Future.microtask(() {
        if (mounted && _tabController.index != 0) {
          _tabController.animateTo(0);
        }
      });
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
                   const AppThemeEffect(animationCurve: Curves.easeInOut, layoutDensity: 1.0, borderRadius: 8.0, icons: AppIcons.standard);

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
                      child: Column(
                        children: [
                          _buildMqttSection(isRunning, l10n, effect),
                          SizedBox(height: 12 * effect.layoutDensity),
                        ],
                      ),
                    ),
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
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.primary.withOpacity(0.08),
              ),
              
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
              headerContent: _buildLogToolbarStats(l10n),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMqttSection(bool isRunning, AppLocalizations l10n, AppThemeEffect effect) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Check if we should use the "Featured Highlight" style
    final bool useFeaturedStyle = colorScheme.primaryContainer != colorScheme.surface && 
                                 colorScheme.primaryContainer != colorScheme.background;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          l10n.mqttBroker, 
          color: useFeaturedStyle ? colorScheme.onPrimaryContainer : null,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一行: Host/Port/SSL开关
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(l10n.host, _hostController, isRunning, customColor: useFeaturedStyle ? colorScheme.onPrimaryContainer : null),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 1,
                    child: _buildTextField(l10n.port, _portController, isRunning, isNumber: true, customColor: useFeaturedStyle ? colorScheme.onPrimaryContainer : null),
                  ),
                  const SizedBox(width: 8),
                  // SSL开关
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _enableSsl,
                      side: BorderSide(color: useFeaturedStyle ? colorScheme.onPrimaryContainer.withOpacity(0.7) : colorScheme.onSurfaceVariant),
                      checkColor: useFeaturedStyle ? colorScheme.surface : colorScheme.onPrimary,
                      activeColor: useFeaturedStyle ? colorScheme.onPrimaryContainer : colorScheme.primary,
                      onChanged: isRunning ? null : (v) => setState(() => _enableSsl = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.enableSsl,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: useFeaturedStyle ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // 第二行: Topic
              _buildTextField(l10n.topic, _topicController, isRunning, customColor: useFeaturedStyle ? colorScheme.onPrimaryContainer : null),
              
              // SSL证书字段(仅在启用SSL时显示) - 一行三列
              if (_enableSsl) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildSslField(l10n.caCertificate, _caPathController, isRunning, useFeaturedStyle ? colorScheme.onPrimaryContainer : null, l10n)),
                    const SizedBox(width: 6),
                    Expanded(child: _buildSslField(l10n.clientCertificate, _certPathController, isRunning, useFeaturedStyle ? colorScheme.onPrimaryContainer : null, l10n)),
                    const SizedBox(width: 6),
                    Expanded(child: _buildSslField(l10n.privateKey, _keyPathController, isRunning, useFeaturedStyle ? colorScheme.onPrimaryContainer : null, l10n)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (useFeaturedStyle) {
      return Container(
        padding: EdgeInsets.fromLTRB(
          14 * effect.layoutDensity, 
          18 * effect.layoutDensity, 
          14 * effect.layoutDensity, 
          14 * effect.layoutDensity
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

  Widget _buildSslField(String label, TextEditingController controller, bool isLocked, Color? customColor, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40, // More compact height
            child: _buildTextField(label, controller, isLocked, customColor: customColor),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: isLocked ? null : () => _pickFile(controller),
          icon: Icon(Icons.folder_open, size: AppIconSize.md, color: customColor ?? Theme.of(context).colorScheme.primary),
          tooltip: l10n.selectFile,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Future<void> _pickFile(TextEditingController controller) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        controller.text = result.files.single.path!;
      });
    }
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
            // Unified Device Configuration Section
            _buildSectionHeader(l10n.deviceConfig, trailing: '${l10n.unitDevices}: $count'),
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.surfaceVariant.withOpacity(0.4),
                    theme.colorScheme.surfaceVariant.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: theme.dividerColor.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: 起始/结束/设备名/ClientID
                    Row(
                      children: [
                        Expanded(child: _buildTextField(l10n.startIndex, _startIdxController, isRunning, isNumber: true, onChanged: (_) => setState(() {}))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField(l10n.endIndex, _endIdxController, isRunning, isNumber: true, onChanged: (_) => setState(() {}))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField(l10n.deviceName, _devicePrefixController, isRunning)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField(l10n.clientId, _clientIdPrefixController, isRunning)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    // Row 2: 用户名/密码/间隔/数据点数
                    Row(
                      children: [
                        Expanded(child: _buildTextField(l10n.username, _usernamePrefixController, isRunning)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField(l10n.password, _passwordPrefixController, isRunning)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField(l10n.interval, _intervalController, isRunning, isNumber: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextField(l10n.dataPointCount, _dataPointController, isRunning, isNumber: true, onChanged: (_) => setState(() {}))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    // Row 3: 数据格式单独一行
                    DropdownButtonFormField<String>(
                      borderRadius: BorderRadius.circular(8),
                      dropdownColor: theme.colorScheme.surface,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface, 
                        fontSize: 14 
                      ),
                      iconEnabledColor: theme.colorScheme.onSurface.withOpacity(0.7),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        labelText: l10n.dataFormat,
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
                   const AppThemeEffect(animationCurve: Curves.easeInOut, layoutDensity: 1.0, borderRadius: 8.0, icons: AppIcons.standard);
                   
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


        // 主操作按钮 - 开始/停止
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
              height: 42,
              child: FilledButton.icon(
                onPressed: () {}, 
                icon: Icon(isRunning ? effect.icons.stop : effect.icons.play, size: AppIconSize.lg),
                label: Text(
                  isRunning ? l10n.stopSimulation : l10n.startSimulation,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                style: FilledButton.styleFrom(
                  elevation: 3,
                  shadowColor: (isRunning ? errorColor : primaryColor).withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: isRunning ? errorColor : primaryColor,
                  foregroundColor: isRunning ? theme.colorScheme.onError : theme.colorScheme.onPrimary,
                  disabledBackgroundColor: isRunning ? errorColor : primaryColor,
                  disabledForegroundColor: isRunning ? theme.colorScheme.onError : theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        
        // 次要操作按钮 - 预览/导入/导出一行排列
        Row(
          children: [
            Expanded(
              child: _AnimatedTactileButton(
                onPressed: isRunning ? null : _handlePreview,
                child: OutlinedButton.icon(
                  onPressed: isRunning ? null : () {},
                  icon: Icon(Icons.remove_red_eye_outlined, size: AppIconSize.sm),
                  label: Text(
                    l10n.previewPayload,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AnimatedTactileButton(
                onPressed: isRunning ? null : _handleImport,
                child: OutlinedButton.icon(
                  onPressed: isRunning ? null : () {},
                  icon: Icon(effect.icons.upload, size: AppIconSize.sm),
                  label: Text(
                    l10n.importConfig,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AnimatedTactileButton(
                onPressed: isRunning ? null : _handleExport,
                child: OutlinedButton.icon(
                  onPressed: isRunning ? null : () {},
                  icon: Icon(effect.icons.download, size: AppIconSize.sm),
                  label: Text(
                    l10n.exportConfig,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Shared Helper to Generate Data
  Map<String, dynamic>? _generatePreviewData({required bool isBasic}) {
    final theme = Theme.of(context);
    try {
      if (isBasic) {
        if (_format == 'tn') {
          return DataGenerator.generateTnPayload(int.tryParse(_dataPointController.text) ?? 10);
        } else if (_format == 'tn-empty') {
          return DataGenerator.generateTnEmptyPayload();
        } else {
          return DataGenerator.generateBatteryStatus(
            int.tryParse(_dataPointController.text) ?? 10,
            customKeys: _basicCustomKeys,
            clientId: 'preview_client',
          );
        }
      } else {
        // Advanced Mode
        if (_groups.isEmpty) {
           _setStatus('No groups configured', Colors.orange);
           return null;
        }
        final group = _groups.first;
        if (group.format == 'tn') {
          return DataGenerator.generateTnPayload(group.totalKeyCount);
        } else if (group.format == 'tn-empty') {
          return DataGenerator.generateTnEmptyPayload();
        } else {
          return DataGenerator.generateBatteryStatus(
            group.totalKeyCount,
            customKeys: group.customKeys,
            clientId: '${group.clientIdPrefix}preview',
          );
        }
      }
    } catch (e) {
      _setStatus('Error generating preview: $e', theme.colorScheme.error);
      return null;
    }
  }

  // Unified Dialog - 使用统一对话框样式
  void _showUnifiedPreviewDialog({
    required Map<String, dynamic> data, 
    VoidCallback? onConfirm
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final isConfirmMode = onConfirm != null;

    final result = await AppDialogHelper.showCodePreview(
      context: context,
      title: isConfirmMode ? l10n.previewAndStart : l10n.payloadPreview,
      code: jsonStr,
      icon: Icons.preview_rounded,
      onCopy: () {
        Clipboard.setData(ClipboardData(text: jsonStr));
        _setStatus(l10n.jsonCopied, Colors.green);
      },
      showConfirmButton: isConfirmMode,
      confirmText: l10n.startNow,
      cancelText: isConfirmMode ? l10n.cancel : l10n.close,
      // NEW: Performance Mode Toggle in Dialog
      extraWidget: isConfirmMode ? StatefulBuilder(
        builder: (context, setState) {
          final controller = Provider.of<MqttController>(context, listen: false);
          final theme = Theme.of(context);
          // Note: controller.enableDetailedLogs is true by default (Logs ON).
          // Performance Mode = Logs OFF.
          // So: Toggle ON (High Perf) -> Logs OFF (false)
          //     Toggle OFF (Normal) -> Logs ON (true)
          bool isPerformanceMode = !controller.enableDetailedLogs;

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.speed_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.performanceMode ?? 'High Performance Mode',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        l10n.performanceMode ?? 'Disables logs for maximum speed', // Fallback hint
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isPerformanceMode,
                  onChanged: (val) {
                    setState(() {
                      controller.toggleDetailedLogs(!val);
                    });
                  },
                ),
              ],
            ),
          );
        }
      ) : null,
    );
    
    if (result == true && onConfirm != null) {
      onConfirm();
    }
  }

  // Handlers
  void _handleStartBasic(MqttController controller) {
    if (_formKeyBasic.currentState!.validate()) {
       // Validate Config First
       final config = _getCompleteConfig();
       ConfigService.saveToLocalStorage(config);
       
       // Show Preview Dialog before starting
       _showPreviewAndStart(controller, config, isBasic: true);
    }
  }

  void _handleStartAdvanced(MqttController controller) {
     final config = _getCompleteConfig();
     
     // Validate groups
     if ((config['groups'] as List).isEmpty) {
       _setStatus('No groups configured', Colors.orange);
       return;
     }

     ConfigService.saveToLocalStorage(config);
     _showPreviewAndStart(controller, config, isBasic: false);
  }

  void _showPreviewAndStart(MqttController controller, Map<String, dynamic> config, {required bool isBasic}) {
     final data = _generatePreviewData(isBasic: isBasic);
     if (data != null) {
       _showUnifiedPreviewDialog(
         data: data, 
         onConfirm: () {
            controller.start(config);
            widget.onSimulationStarted?.call();
         }
       );
     }
  }

  // 使用AppToast显示消息通知
  void _setStatus(String msg, Color color) {
    if (mounted) {
      // 根据颜色判断通知类型
      if (color == Colors.green) {
        AppToast.success(context, msg);
      } else if (color == Colors.orange) {
        AppToast.warning(context, msg);
      } else if (color == Theme.of(context).colorScheme.error || color == Colors.red) {
        AppToast.error(context, msg);
      } else {
        AppToast.info(context, msg);
      }
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
    
    // Step 2: Show error if validation failed - 使用统一对话框样式
    if (result.error != null) {
      if (mounted) {
        await AppDialogHelper.showError(
          context: context,
          title: l10n.importFailed,
          message: '${l10n.invalidJson}: ${result.error}',
          buttonText: l10n.confirm,
        );
      }
      return;
    }
    
    // Step 3: Validation passed - show confirmation dialog - 使用统一对话框样式
    final confirmed = await AppDialogHelper.showConfirm(
      context: context,
      title: l10n.confirmImport,
      message: l10n.importWarning,
      confirmText: l10n.confirmImport,
      cancelText: l10n.cancel,
      icon: Icons.upload_file_rounded,
    );
    
    if (confirmed != true) return;
    
    // Step 4: Apply config
    _applyConfig(result.config!);
    debugPrint('[Import] Applied config. Groups count: ${_groups.length}');
    _setStatus(l10n.configImported, Colors.green);
  }

  void _handlePreview() {
    final isBasic = _tabController.index == 0;
    final data = _generatePreviewData(isBasic: isBasic);
    if (data != null) {
      _showUnifiedPreviewDialog(data: data, onConfirm: null);
    }
  }

  Map<String, dynamic> _getCompleteConfig() {
    return {
      'mode': _tabController.index == 0 ? 'basic' : 'advanced',
      'mqtt': {
        'host': _hostController.text,
        'port': int.tryParse(_portController.text) ?? 1883,
        'topic': _topicController.text,
        'enable_ssl': _enableSsl,
        'ca_path': _caPathController.text,
        'cert_path': _certPathController.text,
        'key_path': _keyPathController.text,
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
      onChanged: isLocked ? null : onChanged,
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

  Widget _buildLogToolbarStats(AppLocalizations l10n) {
    return Consumer<StatisticsCollector>(
      builder: (context, stats, child) {
        final s = stats.getSnapshot();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _compactStatItem(Icons.devices, '${s['onlineDevices']}/${s['totalDevices']}', Colors.blue, l10n.online),
            const SizedBox(width: 12),
            _compactStatItem(Icons.send, '${s['totalMessages']}', Colors.indigo, l10n.statSent),
            const SizedBox(width: 12),
            _compactStatItem(Icons.check_circle, '${s['successCount']}', Colors.green, l10n.statSuccess),
            const SizedBox(width: 12),
            _compactStatItem(Icons.error, '${s['failureCount']}', Colors.red, l10n.statFailed),
            const SizedBox(width: 12),
            _compactStatItem(Icons.timer, '${s['avgLatency']} ms', Colors.orange, l10n.latency),
          ],
        );
      },
    );
  }

  Widget _compactStatItem(IconData icon, String text, Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.xs, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
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
