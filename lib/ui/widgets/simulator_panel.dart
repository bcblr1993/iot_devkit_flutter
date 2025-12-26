import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/mqtt_controller.dart';
import '../../utils/app_dialog_helper.dart';
import '../../utils/app_toast.dart';
import 'groups_manager.dart';
import 'custom_keys_manager.dart';
import 'mqtt_config_section.dart';
import '../../services/config_service.dart';
import 'log_console.dart';
import '../styles/app_theme_effect.dart';
import '../styles/app_constants.dart';
import '../../services/theme_manager.dart';
import '../../viewmodels/mqtt_view_model.dart';
import '../../services/data_generator.dart';

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
  bool _isLogMaximized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setStatus(String msg, Color color) {
    if (!mounted) return;
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

  // --- Dialogs ---
  
  void _showUnifiedPreviewDialog(BuildContext context, Map<String, dynamic> data, VoidCallback? onConfirm) async {
    final l10n = AppLocalizations.of(context)!;
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final isConfirmMode = onConfirm != null;
    final theme = Theme.of(context);

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
      extraWidget: isConfirmMode ? StatefulBuilder(
        builder: (context, setState) {
          final controller = Provider.of<MqttController>(context, listen: false);
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
                      Text(l10n.performanceMode ?? 'Performance Mode', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      Text('Disables detailed logs for speed', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.6))),
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
    
    if (result == true) {
      onConfirm?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Inject MqttViewModel here.
    // Note: In a larger app, Provider might be higher up. 
    // Here we create it locally for the panel lifecycle if it doesn't exist, 
    // or rely on a parent provider. 
    // Given the architecture, HomeScreen uses SimulatorPanel directly.
    // We should allow SimulatorPanel to CREATE the VM.
    
    final mqttController = Provider.of<MqttController>(context);
    
    return ChangeNotifierProvider(
      create: (_) => MqttViewModel(),
      child: Consumer<MqttViewModel>(
        builder: (context, vm, _) {
          return _buildContent(context, vm, mqttController);
        }
      ),
    );
  }

  Widget _buildContent(BuildContext context, MqttViewModel vm, MqttController mqttController) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final effect = theme.extension<AppThemeEffect>() ?? 
                   const AppThemeEffect(animationCurve: Curves.easeInOut, layoutDensity: 1.0, borderRadius: 8.0, icons: AppIcons.standard);
    final isRunning = mqttController.isRunning;

    return Stack(
      children: [
        Positioned.fill(
          bottom: 40,
          child: Column(
            children: [
              // MQTT Section
              Padding(
                padding: EdgeInsets.all(12.0 * effect.layoutDensity),
                child: Form(
                  key: vm.formKeyMqtt,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: MqttConfigSection(
                    isRunning: isRunning,
                    hostController: vm.hostController,
                    portController: vm.portController,
                    topicController: vm.topicController,
                    enableSsl: vm.enableSsl,
                    onSslChanged: vm.setEnableSsl,
                    qos: vm.qos,
                    onQosChanged: vm.setQos,
                    caPathController: vm.caPathController,
                    certPathController: vm.certPathController,
                    keyPathController: vm.keyPathController,
                  ),
                ),
              ),

              // Tabs
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
                              KeepAliveWrapper(child: _buildBasicTab(context, vm, isRunning, l10n)),
                              KeepAliveWrapper(child: _buildAdvancedTab(context, vm, isRunning, l10n)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Divider(height: 1, thickness: 1, color: theme.colorScheme.primary.withOpacity(0.08)),

              // Action Buttons
              Padding(
                padding: EdgeInsets.all(12.0 * effect.layoutDensity),
                child: _buildActionButtons(context, vm, mqttController, l10n, effect),
              ),
            ],
          ),
        ),

        // Log Console (Unchanged logic roughly)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: effect.animationCurve,
          left: 0, right: 0, bottom: 0,
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
              headerContent: _buildLogToolbarStats(context, l10n),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBasicTab(BuildContext context, MqttViewModel vm, bool isRunning, AppLocalizations l10n) {
    // Need to parse count for UI display
    int start = int.tryParse(vm.startIdxController.text) ?? 1;
    int end = int.tryParse(vm.endIdxController.text) ?? 10;
    int count = (end - start + 1).clamp(0, 99999);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Form(
        key: vm.formKeyBasic,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, l10n.deviceConfig, trailing: '${l10n.unitDevices}: $count'),
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.surfaceVariant.withOpacity(0.4),
                    theme.colorScheme.surfaceVariant.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(child: _buildTextField(l10n.startIndex, vm.startIdxController, isRunning, isNumber: true, onChanged: (_) => setState(() {}))), 
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField(l10n.endIndex, vm.endIdxController, isRunning, isNumber: true, onChanged: (_) => setState(() {}))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField(l10n.deviceName, vm.devicePrefixController, isRunning)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField(l10n.clientId, vm.clientIdPrefixController, isRunning)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _buildTextField(l10n.username, vm.usernamePrefixController, isRunning)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField(l10n.password, vm.passwordPrefixController, isRunning)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField(l10n.interval, vm.intervalController, isRunning, isNumber: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField(l10n.dataPointCount, vm.dataPointController, isRunning, isNumber: true)),
                    ]),
                    const SizedBox(height: 10),
                     DropdownButtonFormField<String>(
                        borderRadius: BorderRadius.circular(8),
                        dropdownColor: theme.colorScheme.surface,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          labelText: l10n.dataFormat,
                        ),
                        value: vm.format,
                        items: [
                          DropdownMenuItem(value: 'default', child: Text(l10n.formatDefault)),
                          DropdownMenuItem(value: 'tn', child: Text(l10n.formatTieNiu)),
                          DropdownMenuItem(value: 'tn-empty', child: Text(l10n.formatTieNiuEmpty)),
                        ],
                        onChanged: isRunning ? null : (v) {
                          if (v != null) vm.setFormat(v);
                        },
                      ),
                  ],
                ),
              ),
            ),
            CustomKeysManager(
              keys: vm.basicCustomKeys,
              isLocked: isRunning,
              maxKeys: int.tryParse(vm.dataPointController.text) ?? 10,
              enableExpandedLayout: false,
              onKeysChanged: vm.updateBasicCustomKeys,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedTab(BuildContext context, MqttViewModel vm, bool isRunning, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Form(
        key: vm.formKeyAdvanced,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: GroupsManager(
          groups: vm.groups,
          isLocked: isRunning,
          onGroupsChanged: vm.updateGroups,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, MqttViewModel vm, MqttController controller, AppLocalizations l10n, AppThemeEffect effect) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    final primaryColor = theme.colorScheme.primary;
    final isBusy = controller.isBusy;
    final isRunning = controller.isRunning;
    final isBasic = _tabController.index == 0;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: isBusy ? null : (isRunning 
              ? () => controller.stop() 
              : () {
                if (isBasic) {
                  vm.startBasicSimulation(context, (config, basic) {
                     _showUnifiedPreviewDialog(context, vm.generatePreviewData(isBasic: true)!, () {
                       controller.start(config);
                       widget.onSimulationStarted?.call();
                     });
                  });
                } else {
                  vm.startAdvancedSimulation(context, (config, basic) {
                     final data = vm.generatePreviewData(isBasic: false);
                     if (data == null) {
                       _setStatus('No groups configured', Colors.orange);
                       return;
                     }
                     _showUnifiedPreviewDialog(context, data, () {
                        controller.start(config);
                        widget.onSimulationStarted?.call();
                     });
                  });
                }
              }),
            icon: isBusy 
               ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.colorScheme.onPrimary))
               : Icon(isRunning ? Icons.stop : Icons.play_arrow),
            label: Text(isBusy 
                ? (isRunning ? l10n.stopping : l10n.starting) 
                : (isRunning ? l10n.stopSimulation : l10n.startSimulation),
                style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: isRunning ? errorColor : primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: isRunning ? null : () {
                final data = vm.generatePreviewData(isBasic: isBasic);
                if (data != null) _showUnifiedPreviewDialog(context, data, null);
                else _setStatus('Cannot generate preview', Colors.orange);
              },
              icon: const Icon(Icons.remove_red_eye_outlined),
              label: Text(l10n.previewPayload),
            )),
            const SizedBox(width: 8),
            // Import/Export logic needs moving to VM or keeping here calling ConfigService directly is fine for UI actions
            Expanded(child: OutlinedButton.icon(
              onPressed: isRunning ? null : () async {
                final res = await ConfigService.importFromFile();
                if (res.config != null) {
                   // Updating VM state requires VM to have loadConfig(map) method or rely on reload
                   // VM has _applyConfig private. Need to expose plain apply method or save to local storage and reload.
                   // ConfigService saved it? No check importFromFile implementation... it returns Map.
                   // So we need to tell VM to apply this map.
                   // Since _applyConfig is private, I'll update it to be public or add applyConfig method in next step if it fails.
                   // For now assuming ConfigService saves it? No.
                   // I'll make VM.loadConfig() public (it is).
                   // I'll save imported config to LocalStorage then loadConfig().
                   await ConfigService.saveToLocalStorage(res.config!);
                   await vm.loadConfig();
                   _setStatus(l10n.configImported ?? 'Imported', Colors.green);
                } else if (res.error != null) {
                   _setStatus(res.error!, theme.colorScheme.error);
                }
              },
              icon: Icon(Icons.upload),
              label: Text(l10n.importConfig),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: isRunning ? null : () async {
                final res = await ConfigService.exportToFile(vm.getCompleteConfig());
                if (res.success) _setStatus(l10n.configExported ?? 'Exported', Colors.green);
                else if (res.error != null) _setStatus(res.error!, theme.colorScheme.error);
              },
              icon: Icon(Icons.download),
              label: Text(l10n.exportConfig),
            )),
          ],
        )
      ],
    );
  }

  // Helper Widgets
  Widget _buildSectionHeader(BuildContext context, String title, {String? trailing}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, color: theme.colorScheme.primary, margin: const EdgeInsets.only(right: 8)),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          if (trailing != null)
            Text(trailing, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isLocked, {bool isNumber = false, Function(String)? onChanged}) {
    return TextFormField(
      controller: controller,
      enabled: !isLocked,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    );
  }

  Widget _buildLogToolbarStats(BuildContext context, AppLocalizations l10n) {
    final mqttController = Provider.of<MqttController>(context, listen: false);
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return ListenableBuilder(
      listenable: mqttController.statisticsCollector,
      builder: (context, _) {
        final stats = mqttController.statisticsCollector;
        return Row(
          children: [
            if (!isSmallScreen) ...[
              _buildStatItem(context, l10n.totalDevices, stats.totalDevices.toString(), Colors.blue),
              const SizedBox(width: 12),
              _buildStatItem(context, l10n.online, stats.onlineDevices.toString(), Colors.green),
              const SizedBox(width: 12),
              _buildStatItem(context, l10n.statSent, stats.totalMessages.toString(), theme.colorScheme.onSurface),
              const SizedBox(width: 12),
              _buildStatItem(context, l10n.statSuccess, stats.successCount.toString(), Colors.green),
              const SizedBox(width: 12),
              _buildStatItem(context, l10n.statFailed, stats.failureCount.toString(), theme.colorScheme.error),
            ] else 
              Expanded(child: Text(
                'D:${stats.onlineDevices}/${stats.totalDevices} S:${stats.successCount} F:${stats.failureCount}',
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              )),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, Color color) {
    return Row(
      children: [
        Text('$label: ', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// Helper for KeepAlive
class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});
  @override
  _KeepAliveWrapperState createState() => _KeepAliveWrapperState();
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
