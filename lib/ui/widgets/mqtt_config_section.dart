import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../l10n/generated/app_localizations.dart';
import '../lab/lab.dart';
import '../components/form_grid.dart';

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

  // Replicating _buildTextField from SimulatorPanel but as a pure function
  Widget _buildTextField(BuildContext context, String label,
      TextEditingController controller, bool isLocked,
      {bool isNumber = false, Color? customColor}) {
    // Note: Validation is done by Form at parent level or we can move validator here if passed
    // For now, simple text field. The original had a validator.
    // We should keep it as TextFormField for Form integration.

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
