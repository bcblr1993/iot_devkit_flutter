import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/mqtt_controller.dart';
import '../../utils/app_dialog_helper.dart';
import '../lab/lab.dart';
import 'groups_manager.dart';
import 'custom_keys_manager.dart';
import 'mqtt_config_section.dart';
import '../../services/config_service.dart';
import 'log_console.dart';
import 'performance_monitor.dart';
import 'profile_sidebar.dart';
import '../styles/app_theme_effect.dart';
import '../components/app_input_decoration.dart';
import '../components/app_section.dart';
import '../components/form_grid.dart';
import '../components/metric_chip.dart';
import '../simulator/keep_alive_wrapper.dart';
import '../simulator/simulator_header.dart';
import '../simulator/simulator_log_dock.dart';
import '../../viewmodels/mqtt_view_model.dart';

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

class _SimulatorPanelState extends State<SimulatorPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLogMaximized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _setStatus(String msg, Color color) {
    if (!mounted) return;
    if (color == Colors.green) {
      showLabToast(context, title: msg, kind: LabStatus.ok);
    } else if (color == Colors.orange) {
      showLabToast(context, title: msg, kind: LabStatus.warn);
    } else if (color == Theme.of(context).colorScheme.error ||
        color == Colors.red) {
      showLabToast(context, title: msg, kind: LabStatus.error);
    } else {
      showLabToast(context, title: msg, kind: LabStatus.info);
    }
  }

  // --- Dialogs ---

  void _showUnifiedPreviewDialog(BuildContext context,
      Map<String, dynamic> data, VoidCallback? onConfirm) async {
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
      extraWidget: isConfirmMode
          ? StatefulBuilder(builder: (context, setState) {
              final controller =
                  Provider.of<MqttController>(context, listen: false);
              bool isPerformanceMode = !controller.enableDetailedLogs;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.speed_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.performanceMode,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary)),
                          Text('Disables detailed logs for speed',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6))),
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
            })
          : null,
    );

    if (result == true) {
      onConfirm?.call();
    }
  }

  bool _showProfileSidebar = false; // Default hidden

  @override
  Widget build(BuildContext context) {
    // Inject MqttViewModel here.
    final mqttController = Provider.of<MqttController>(context);

    return ChangeNotifierProvider(
      create: (_) => MqttViewModel(),
      child: Consumer<MqttViewModel>(builder: (context, vm, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sidebar
            ProfileSidebar(
              isVisible: _showProfileSidebar,
              onClose: () => setState(() => _showProfileSidebar = false),
            ),

            // Main Content
            Expanded(
              child: _buildContent(context, vm, mqttController),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildContent(
      BuildContext context, MqttViewModel vm, MqttController mqttController) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final effect = theme.extension<AppThemeEffect>() ??
        const AppThemeEffect(
            animationCurve: Curves.easeInOut,
            layoutDensity: 1.0,
            borderRadius: 8.0,
            icons: AppIcons.standard);
    final isRunning = mqttController.isRunning;

    return Stack(
      children: [
        Positioned.fill(
          bottom: SimulatorLogDock.collapsedHeight,
          child: Column(
            children: [
              // Top Bar with Toggle
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 12.0 * effect.layoutDensity,
                    vertical: 10.0 * effect.layoutDensity),
                child: SimulatorHeader(
                  isProfileSidebarVisible: _showProfileSidebar,
                  currentProfileId: vm.currentProfileId,
                  onToggleProfileSidebar: () => setState(
                      () => _showProfileSidebar = !_showProfileSidebar),
                  onClearProfile: vm.clearCurrentProfile,
                ),
              ),

              // MQTT Section
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 12.0 * effect.layoutDensity),
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

              // Config Tabs or Performance Monitor (Collapsible)
              Expanded(
                child: (isRunning && _showMonitor)
                    ? Stack(
                        children: [
                          const PerformanceMonitor(),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton.filledTonal(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  setState(() => _showMonitor = false),
                              tooltip: l10n.close,
                            ),
                          ),
                        ],
                      )
                    : IgnorePointer(
                        ignoring: mqttController
                            .isBusy, // Only ignore when starting/stopping, not just running
                        child: Opacity(
                          opacity: mqttController.isBusy ? 0.7 : 1.0,
                          child: Column(
                            children: [
                              _buildModeSelector(context, l10n, theme, effect),
                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  physics: const BouncingScrollPhysics(),
                                  children: [
                                    KeepAliveWrapper(
                                        child: _buildBasicTab(
                                            context, vm, isRunning, l10n)),
                                    KeepAliveWrapper(
                                        child: _buildAdvancedTab(
                                            context, vm, isRunning, l10n)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  12.0 * effect.layoutDensity,
                  0,
                  12.0 * effect.layoutDensity,
                  8.0 * effect.layoutDensity,
                ),
                child: _buildSimulationStatusStrip(context, l10n),
              ),
              Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.primary.withValues(alpha: 0.08)),

              // Action Buttons
              Padding(
                padding: EdgeInsets.fromLTRB(
                  12.0 * effect.layoutDensity,
                  10.0 * effect.layoutDensity,
                  12.0 * effect.layoutDensity,
                  12.0 * effect.layoutDensity,
                ),
                child: _buildActionButtons(
                    context, vm, mqttController, l10n, effect),
              ),
            ],
          ),
        ),
        SimulatorLogDock(
          logs: widget.logs,
          isExpanded: widget.isLogExpanded,
          isMaximized: _isLogMaximized,
          onToggle: widget.onToggleLog,
          onClear: widget.onClearLog,
          onMaximize: () => setState(() => _isLogMaximized = !_isLogMaximized),
          effect: effect,
        ),
      ],
    );
  }

  Widget _buildBasicTab(BuildContext context, MqttViewModel vm, bool isRunning,
      AppLocalizations l10n) {
    // Need to parse count for UI display
    int start = int.tryParse(vm.startIdxController.text) ?? 1;
    int end = int.tryParse(vm.endIdxController.text) ?? 10;
    int count = (end - start + 1).clamp(0, 99999);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Form(
        key: vm.formKeyBasic,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSection(
              title: l10n.deviceConfig,
              icon: Icons.devices_other,
              trailing: MetricChip(
                label: l10n.unitDevices,
                value: count.toString(),
              ),
              child: Column(
                children: [
                  FormGrid(
                    children: [
                      _buildTextField(
                        l10n.startIndex,
                        vm.startIdxController,
                        isRunning,
                        isNumber: true,
                        onChanged: (_) => setState(() {}),
                      ),
                      _buildTextField(
                        l10n.endIndex,
                        vm.endIdxController,
                        isRunning,
                        isNumber: true,
                        onChanged: (_) => setState(() {}),
                      ),
                      _buildTextField(
                        l10n.deviceName,
                        vm.devicePrefixController,
                        isRunning,
                      ),
                      _buildTextField(
                        l10n.clientId,
                        vm.clientIdPrefixController,
                        isRunning,
                      ),
                      _buildTextField(
                        l10n.username,
                        vm.usernamePrefixController,
                        isRunning,
                      ),
                      _buildTextField(
                        l10n.password,
                        vm.passwordPrefixController,
                        isRunning,
                      ),
                      _buildTextField(
                        l10n.interval,
                        vm.intervalController,
                        isRunning,
                        isNumber: true,
                      ),
                      _buildTextField(
                        l10n.dataPointCount,
                        vm.dataPointController,
                        isRunning,
                        isNumber: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    borderRadius: BorderRadius.circular(8),
                    dropdownColor: theme.colorScheme.surface,
                    decoration: AppInputDecoration.filled(context,
                        label: l10n.dataFormat),
                    initialValue: vm.format,
                    items: [
                      DropdownMenuItem(
                          value: 'default', child: Text(l10n.formatDefault)),
                      DropdownMenuItem(
                          value: 'tn', child: Text(l10n.formatTieNiu)),
                      DropdownMenuItem(
                          value: 'tn-empty',
                          child: Text(l10n.formatTieNiuEmpty)),
                    ],
                    onChanged: isRunning
                        ? null
                        : (v) {
                            if (v != null) vm.setFormat(v);
                          },
                  ),
                ],
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

  Widget _buildAdvancedTab(BuildContext context, MqttViewModel vm,
      bool isRunning, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
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

  bool _showMonitor = false;

  @override
  void didUpdateWidget(SimulatorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-show monitor disabled by user request. Default false.
    // User can toggle via Dashboard button.
  }

  // ... (existing helper methods)

  Widget _buildModeSelector(BuildContext context, AppLocalizations l10n,
      ThemeData theme, AppThemeEffect effect) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12.0 * effect.layoutDensity,
        10,
        12.0 * effect.layoutDensity,
        6,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          segments: [
            ButtonSegment(
              value: 0,
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: Text(l10n.basicMode),
            ),
            ButtonSegment(
              value: 1,
              icon: const Icon(Icons.account_tree_outlined),
              label: Text(l10n.advancedMode),
            ),
          ],
          selected: {_tabController.index},
          showSelectedIcon: true,
          onSelectionChanged: (selection) {
            final next = selection.first;
            if (next != _tabController.index) {
              _tabController.animateTo(next);
            }
          },
          style: SegmentedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            selectedBackgroundColor: theme.colorScheme.primary,
            selectedForegroundColor: theme.colorScheme.onPrimary,
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            backgroundColor: theme.colorScheme.surfaceContainerLowest,
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, MqttViewModel vm,
      MqttController controller, AppLocalizations l10n, AppThemeEffect effect) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    final primaryColor = theme.colorScheme.primary;
    final isBusy = controller.isBusy;
    final isStarting = controller.isStarting;
    final isStopping = controller.isStopping;
    final isRunning = controller.isRunning;
    final isBasic = _tabController.index == 0;
    final showProgress = isStarting || isStopping;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final startButton = SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: isStopping
                ? null
                : (isRunning
                    ? () async {
                        await controller.stop();
                        _showMonitor = false; // Reset on stop
                      }
                    : () {
                        if (isBasic) {
                          bool valid =
                              vm.startBasicSimulation(context, (config, basic) {
                            _showUnifiedPreviewDialog(
                                context, vm.generatePreviewData(isBasic: true)!,
                                () {
                              controller.start(config);
                              // Auto-show disabled
                              widget.onSimulationStarted?.call();
                            });
                          });
                          if (!valid) {
                            _setStatus(
                                vm.lastValidationError ??
                                    l10n.formValidationFailed,
                                theme.colorScheme.error);
                          }
                        } else {
                          bool valid = vm.startAdvancedSimulation(context,
                              (config, basic) {
                            final data = vm.generatePreviewData(isBasic: false);
                            if (data == null) {
                              _setStatus('No groups configured', Colors.orange);
                              return;
                            }
                            _showUnifiedPreviewDialog(context, data, () {
                              controller.start(config);
                              // Auto-show disabled
                              widget.onSimulationStarted?.call();
                            });
                          });
                          if (!valid) {
                            _setStatus(
                                vm.lastValidationError ??
                                    l10n.formValidationFailed,
                                theme.colorScheme.error);
                          }
                        }
                      }),
            icon: showProgress
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: theme.colorScheme.onPrimary))
                : Icon(isRunning ? Icons.stop : Icons.play_arrow),
            label: Text(
              showProgress
                  ? (isStopping ? l10n.stopping : l10n.starting)
                  : (isRunning ? l10n.stopSimulation : l10n.startSimulation),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: isRunning ? errorColor : primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        );

        final previewButton = SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            onPressed: isBusy
                ? null
                : isRunning
                    ? () => setState(
                        () => _showMonitor = !_showMonitor) // Toggle Dashboard
                    : () {
                        final data = vm.generatePreviewData(isBasic: isBasic);
                        if (data != null) {
                          _showUnifiedPreviewDialog(context, data, null);
                        } else {
                          _setStatus('Cannot generate preview', Colors.orange);
                        }
                      },
            icon: Icon(isRunning
                ? (_showMonitor ? Icons.visibility_off : Icons.dashboard)
                : Icons.remove_red_eye_outlined),
            label: Text(isRunning
                ? (_showMonitor ? l10n.close : l10n.statistics)
                : l10n.previewPayload),
          ),
        );
        final importButton = SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            onPressed: (isRunning || isBusy)
                ? null
                : () async {
                    final res = await ConfigService.importFromFile();
                    if (res.config != null) {
                      await ConfigService.saveToLocalStorage(res.config!);
                      await vm.loadConfig();
                      _setStatus(l10n.configImported, Colors.green);
                    } else if (res.error != null) {
                      _setStatus(res.error!, theme.colorScheme.error);
                    }
                  },
            icon: const Icon(Icons.upload),
            label: Text(l10n.importConfig),
          ),
        );
        final exportButton = SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            onPressed: (isRunning || isBusy)
                ? null
                : () async {
                    final res = await ConfigService.exportToFile(
                        vm.getCompleteConfig());
                    if (res.success) {
                      _setStatus(l10n.configExported, Colors.green);
                    } else if (res.error != null) {
                      _setStatus(res.error!, theme.colorScheme.error);
                    }
                  },
            icon: const Icon(Icons.download),
            label: Text(l10n.exportConfig),
          ),
        );

        if (compact) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: startButton),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: previewButton),
                  const SizedBox(width: 8),
                  Expanded(child: importButton),
                  const SizedBox(width: 8),
                  Expanded(child: exportButton),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 2, child: startButton),
            const SizedBox(width: 10),
            Expanded(child: previewButton),
            const SizedBox(width: 10),
            Expanded(child: importButton),
            const SizedBox(width: 10),
            Expanded(child: exportButton),
          ],
        );
      },
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, bool isLocked,
      {bool isNumber = false, Function(String)? onChanged}) {
    return TextFormField(
      controller: controller,
      enabled: !isLocked,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
      onChanged: onChanged,
      decoration: AppInputDecoration.filled(context, label: label),
      validator: (v) => (v == null || v.isEmpty)
          ? AppLocalizations.of(context)!.fieldRequired
          : null,
    );
  }

  Widget _buildSimulationStatusStrip(
      BuildContext context, AppLocalizations l10n) {
    final mqttController = Provider.of<MqttController>(context, listen: false);
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final colors = theme.colorScheme;

    return ListenableBuilder(
      listenable: Listenable.merge([
        mqttController,
        mqttController.statisticsCollector,
      ]),
      builder: (context, _) {
        final stats = mqttController.statisticsCollector;
        final showRunState = mqttController.runState != SimulationRunState.idle;
        final stateLabel = _runStateLabel(context, mqttController.runState);
        return Container(
          height: 42,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ClipRect(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (!isSmallScreen) ...[
                      if (showRunState) ...[
                        MetricChip(
                          label: _localized(context, zh: '状态', en: 'State'),
                          value: stateLabel,
                          color: _runStateColor(theme, mqttController.runState),
                        ),
                        const SizedBox(width: 10),
                      ],
                      MetricChip(
                          label: l10n.totalDevices,
                          value: stats.totalDevices.toString(),
                          color: Colors.blue),
                      const SizedBox(width: 10),
                      MetricChip(
                          label: l10n.online,
                          value: stats.onlineDevices.toString(),
                          color: Colors.green),
                      const SizedBox(width: 10),
                      MetricChip(
                          label: l10n.statSent,
                          value: stats.totalMessages.toString(),
                          color: theme.colorScheme.onSurface),
                      const SizedBox(width: 10),
                      MetricChip(
                          label: l10n.statSuccess,
                          value: stats.successCount.toString(),
                          color: Colors.green),
                      const SizedBox(width: 10),
                      MetricChip(
                          label: l10n.statFailed,
                          value: stats.failureCount.toString(),
                          color: theme.colorScheme.error),
                      const SizedBox(width: 10),
                      MetricChip(
                          label: l10n.cpuUsage,
                          value: '${stats.cpuUsage.toStringAsFixed(1)}%',
                          color: Colors.purple),
                      const SizedBox(width: 10),
                      MetricChip(
                          label: l10n.memoryUsage,
                          value:
                              '${(stats.memoryUsage / 1024 / 1024).toStringAsFixed(0)} MB',
                          color: Colors.indigo),
                    ] else
                      Text(
                        '${showRunState ? '$stateLabel · ' : ''}D:${stats.onlineDevices}/${stats.totalDevices} S:${stats.successCount} F:${stats.failureCount}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _runStateLabel(BuildContext context, SimulationRunState state) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return switch (state) {
      SimulationRunState.idle => isZh ? '就绪' : 'Ready',
      SimulationRunState.starting => isZh ? '准备中' : 'Starting',
      SimulationRunState.connecting => isZh ? '连接中' : 'Connecting',
      SimulationRunState.running => isZh ? '运行中' : 'Running',
      SimulationRunState.reconnecting => isZh ? '重连中' : 'Reconnecting',
      SimulationRunState.partialRunning => isZh ? '部分在线' : 'Partial',
      SimulationRunState.stopping => isZh ? '停止中' : 'Stopping',
      SimulationRunState.failed => isZh ? '失败' : 'Failed',
    };
  }

  Color _runStateColor(ThemeData theme, SimulationRunState state) {
    return switch (state) {
      SimulationRunState.idle => theme.colorScheme.onSurfaceVariant,
      SimulationRunState.starting ||
      SimulationRunState.connecting =>
        theme.colorScheme.primary,
      SimulationRunState.running => Colors.green,
      SimulationRunState.reconnecting ||
      SimulationRunState.partialRunning =>
        Colors.orange,
      SimulationRunState.stopping => theme.colorScheme.error,
      SimulationRunState.failed => theme.colorScheme.error,
    };
  }

  String _localized(
    BuildContext context, {
    required String zh,
    required String en,
  }) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }
}
