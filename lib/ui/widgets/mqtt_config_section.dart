// ignore_for_file: avoid_raw_edge_insets, prefer_lab_tokens
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/subscription_config.dart';
import '../components/form_grid.dart';
import '../lab/lab.dart';
import 'subscriptions_section.dart';

class MqttConfigSection extends StatelessWidget {
  final bool isRunning;
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController topicController;
  final TextEditingController caPathController;
  final TextEditingController certPathController;
  final TextEditingController keyPathController;

  final bool enableSsl;
  final ValueChanged<bool> onSslChanged;

  final int qos;
  final ValueChanged<int> onQosChanged;
  final String protocolVersion;
  final ValueChanged<String> onProtocolVersionChanged;

  /// Subscriptions applied to every connected client. Edited in-place by the
  /// embedded [SubscriptionsSection] that lives below the SSL toggle.
  final List<SubscriptionConfig> subscriptions;
  final ValueChanged<List<SubscriptionConfig>> onSubscriptionsChanged;

  /// Master switch — mirrors the SSL toggle. Drives both visibility of the
  /// embedded [SubscriptionsSection] and whether subscriptions apply at
  /// runtime (gated in the controller). Lifted to the view model so the state
  /// persists across profile switches / restarts.
  final bool subscriptionsEnabled;
  final ValueChanged<bool> onSubscriptionsEnabledChanged;

  const MqttConfigSection({
    super.key,
    required this.isRunning,
    required this.hostController,
    required this.portController,
    required this.topicController,
    required this.caPathController,
    required this.certPathController,
    required this.keyPathController,
    required this.enableSsl,
    required this.onSslChanged,
    required this.qos,
    required this.onQosChanged,
    required this.protocolVersion,
    required this.onProtocolVersionChanged,
    required this.subscriptions,
    required this.onSubscriptionsChanged,
    required this.subscriptionsEnabled,
    required this.onSubscriptionsEnabledChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final tlsBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: enableSsl
            ? colorScheme.primary.withValues(alpha: 0.08)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        enableSsl ? 'TLS' : 'TCP',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: enableSsl
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );

    final subscriptionCount = subscriptions.length;
    final subsCountBadge = subscriptionCount == 0
        ? null
        : Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$subscriptionCount',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          );

    return LabSection(
      title: l10n.mqttBroker,
      trailing: tlsBadge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormGrid(
            minItemWidth: 180,
            children: [
              _buildTextField(
                  context, l10n.host, hostController, isRunning),
              _buildTextField(
                  context, l10n.port, portController, isRunning,
                  isNumber: true),
              _buildQosField(context, l10n, theme),
              _buildProtocolField(context, l10n),
            ],
          ),
          const SizedBox(height: 10),
          _buildTextField(
              context, l10n.topic, topicController, isRunning),
          const SizedBox(height: 10),

          // — Two compact toggles on a single row: SSL/TLS + Subscriptions —
          // Combining them saves vertical space vs. two stacked SwitchListTiles.
          // Use the row's natural height (the adaptive Switch is taller than
          // 32 px on macOS — a fixed height clipped it and overlapped the SSL
          // labels below).
          LayoutBuilder(builder: (context, constraints) {
            final sslToggle = _CompactToggle(
              icon: enableSsl ? Icons.lock_outline : Icons.lock_open_outlined,
              label: l10n.enableSsl,
              value: enableSsl,
              onChanged: isRunning ? null : onSslChanged,
            );
            final subsToggle = _CompactToggle(
              key: const ValueKey('enable_subscriptions_toggle'),
              icon: subscriptionsEnabled ? Icons.sync_alt : Icons.sync_disabled,
              label: l10n.enableSubscriptions,
              value: subscriptionsEnabled,
              trailing: subsCountBadge,
              onChanged: isRunning ? null : onSubscriptionsEnabledChanged,
            );
            return Row(children: [
              Expanded(child: sslToggle),
              SizedBox(width: constraints.maxWidth < 460 ? 8 : 16),
              Expanded(child: subsToggle),
            ]);
          }),
          if (enableSsl) ...[
            const SizedBox(height: 12),
            FormGrid(
              minItemWidth: 260,
              children: [
                _buildSslField(context, l10n.caCertificate, caPathController,
                    isRunning, null, l10n),
                _buildSslField(context, l10n.clientCertificate,
                    certPathController, isRunning, null, l10n),
                _buildSslField(context, l10n.privateKey, keyPathController,
                    isRunning, null, l10n),
              ],
            ),
          ],
          if (subscriptionsEnabled) ...[
            // Clear separation from the toggle row / SSL fields above so the
            // subscription toolbar doesn't butt against them.
            const SizedBox(height: 12),
            Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            SubscriptionsSection(
              subscriptions: subscriptions,
              isLocked: isRunning,
              onChanged: onSubscriptionsChanged,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQosField(
      BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return LabSelect<int>(
      label: l10n.qosLabel,
      value: qos,
      items: [
        LabSelectItem(0, l10n.qos0),
        LabSelectItem(1, l10n.qos1),
        LabSelectItem(2, l10n.qos2),
      ],
      onChanged: isRunning ? null : (v) => onQosChanged(v ?? 0),
    );
  }

  Widget _buildProtocolField(BuildContext context, AppLocalizations l10n) {
    return LabSelect<String>(
      label: l10n.mqttProtocolVersion,
      value: protocolVersion,
      items: [
        LabSelectItem('mqtt_3_1_1', l10n.mqttProtocolV311),
        LabSelectItem('mqtt_3_1', l10n.mqttProtocolV31),
      ],
      onChanged: isRunning
          ? null
          : (v) => onProtocolVersionChanged(v ?? 'mqtt_3_1_1'),
    );
  }

  Widget _buildSslField(
      BuildContext context,
      String label,
      TextEditingController controller,
      bool isLocked,
      Color? customColor,
      AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            child: _buildTextField(context, label, controller, isLocked,
                customColor: customColor),
          ),
        ),
        const SizedBox(width: 8),
        LabIconButton(
          icon: Icons.folder_open,
          tooltip: l10n.selectFile,
          onPressed: isLocked ? null : () => _pickFile(controller),
        ),
      ],
    );
  }

  Future<void> _pickFile(TextEditingController controller) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      controller.text = result.files.single.path!;
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // _buildTextField — kept below as a helper.
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildTextField(BuildContext context, String label,
      TextEditingController controller, bool isLocked,
      {bool isNumber = false, Color? customColor}) {
    return LabField(
      label: label,
      controller: controller,
      enabled: !isLocked,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context)!.fieldRequired;
        }
        if (isNumber && int.tryParse(value) == null) {
          return AppLocalizations.of(context)!.invalidNumber;
        }
        return null;
      },
    );
  }
}

/// Compact toggle row used twice in the MQTT broker section: SSL/TLS and
/// Enable subscriptions. Renders an icon + label + optional trailing badge +
/// scaled switch in roughly 28-32 px of vertical space.
class _CompactToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? trailing;

  const _CompactToggle({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onChanged != null;
    final activeColor = enabled
        ? (value ? scheme.primary : scheme.onSurfaceVariant)
        : scheme.onSurfaceVariant.withValues(alpha: 0.5);

    return Row(
      children: [
        Icon(icon, size: 18, color: activeColor),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: enabled ? null : scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        if (trailing != null) trailing!,
        const Spacer(),
        Transform.scale(
          scale: 0.85,
          child: Switch.adaptive(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}
