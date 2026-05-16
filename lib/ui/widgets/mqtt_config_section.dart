import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../l10n/generated/app_localizations.dart';
import '../styles/app_constants.dart';
import '../lab/lab.dart';
import '../components/form_grid.dart';
import '../components/app_input_decoration.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LabSection(
      title: l10n.mqttBroker,
      trailing: Container(
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
            color:
                enableSsl ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormGrid(
            minItemWidth: 180,
            children: [
              _buildTextField(context, l10n.host, hostController, isRunning),
              _buildTextField(context, l10n.port, portController, isRunning,
                  isNumber: true),
              _buildQosField(context, l10n, theme),
            ],
          ),
          const SizedBox(height: 10),
          _buildTextField(context, l10n.topic, topicController, isRunning),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            value: enableSsl,
            onChanged: isRunning ? null : (v) => onSslChanged(v),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              l10n.enableSsl,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            secondary: Icon(
              enableSsl ? Icons.lock_outline : Icons.lock_open_outlined,
              size: 20,
              color: enableSsl
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          if (enableSsl) ...[
            const SizedBox(height: 8),
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
        ],
      ),
    );
  }

  Widget _buildQosField(
      BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return DropdownButtonFormField<int>(
      decoration: AppInputDecoration.filled(context, label: l10n.qosLabel),
      dropdownColor: theme.colorScheme.surface,
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      initialValue: qos,
      items: [
        DropdownMenuItem(
          value: 0,
          child: Tooltip(message: l10n.qosTooltip0, child: Text(l10n.qos0)),
        ),
        DropdownMenuItem(
          value: 1,
          child: Tooltip(message: l10n.qosTooltip1, child: Text(l10n.qos1)),
        ),
        DropdownMenuItem(
          value: 2,
          child: Tooltip(message: l10n.qosTooltip2, child: Text(l10n.qos2)),
        ),
      ],
      onChanged: isRunning ? null : (v) => onQosChanged(v ?? 0),
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
            // height: 40, // Height is now controlled by isDense/contentPadding in _buildTextField
            child: _buildTextField(context, label, controller, isLocked,
                customColor: customColor),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: isLocked ? null : () => _pickFile(controller),
          icon: Icon(Icons.folder_open,
              size: AppIconSize.md,
              color: customColor ?? Theme.of(context).colorScheme.primary),
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
      controller.text = result.files.single.path!;
    }
  }

  // Replicating _buildTextField from SimulatorPanel but as a pure function
  Widget _buildTextField(BuildContext context, String label,
      TextEditingController controller, bool isLocked,
      {bool isNumber = false, Color? customColor}) {
    // Note: Validation is done by Form at parent level or we can move validator here if passed
    // For now, simple text field. The original had a validator.
    // We should keep it as TextFormField for Form integration.

    return TextFormField(
      controller: controller,
      enabled: !isLocked,
      style: customColor != null ? TextStyle(color: customColor) : null,
      decoration: AppInputDecoration.filled(context, label: label).copyWith(
        labelStyle: customColor != null
            ? TextStyle(color: customColor.withValues(alpha: 0.7))
            : null,
        floatingLabelStyle: customColor != null
            ? TextStyle(color: customColor, fontWeight: FontWeight.bold)
            : null,
      ),
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
