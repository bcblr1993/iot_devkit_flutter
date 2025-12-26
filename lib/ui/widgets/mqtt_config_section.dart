import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../l10n/generated/app_localizations.dart';
import '../styles/app_theme_effect.dart';
import '../styles/app_constants.dart';

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
    final effect = theme.extension<AppThemeEffect>() ?? 
                   const AppThemeEffect(animationCurve: Curves.easeInOut, layoutDensity: 1.0, borderRadius: 8.0, icons: AppIcons.standard);

    // Check if we should use the "Featured Highlight" style
    final bool useFeaturedStyle = colorScheme.primaryContainer != colorScheme.surface && 
                                 colorScheme.primaryContainer != colorScheme.surface; // Check against surface not background in Flutter 3

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          l10n.mqttBroker, 
          context,
          color: useFeaturedStyle ? colorScheme.onPrimaryContainer : null,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Host (Flex 4), Port (Flex 1), QoS (Flex 2)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildTextField(context, l10n.host, hostController, isRunning, customColor: useFeaturedStyle ? colorScheme.onPrimaryContainer : null),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: _buildTextField(context, l10n.port, portController, isRunning, isNumber: true, customColor: useFeaturedStyle ? colorScheme.onPrimaryContainer : null),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: l10n.qosLabel,
                        labelStyle: TextStyle(
                          color: useFeaturedStyle 
                            ? colorScheme.onPrimaryContainer.withOpacity(0.8) 
                            : theme.colorScheme.onSurfaceVariant,
                        ),
                        floatingLabelStyle: TextStyle(
                          color: useFeaturedStyle 
                            ? colorScheme.onPrimaryContainer 
                            : theme.colorScheme.primary,
                        ),
                        border: const OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: useFeaturedStyle 
                              ? colorScheme.onPrimaryContainer.withOpacity(0.5) 
                              : theme.colorScheme.outline.withOpacity(0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: useFeaturedStyle 
                              ? colorScheme.onPrimaryContainer 
                              : theme.colorScheme.primary, 
                            width: 2
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        isDense: true,
                      ),
                      // Use Surface color for popup to ensure standard contrast for text
                      dropdownColor: theme.colorScheme.surface,
                      style: TextStyle(
                        // Selected item text color in the input field
                        color: useFeaturedStyle ? colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      icon: Icon(Icons.arrow_drop_down, 
                        color: useFeaturedStyle ? colorScheme.onPrimaryContainer : null
                      ),
                      value: qos,
                      items: [
                        DropdownMenuItem(
                          value: 0, 
                          child: Tooltip(
                            message: l10n.qosTooltip0 ?? '', 
                            child: Text(l10n.qos0 ?? 'QoS 0', style: TextStyle(color: theme.colorScheme.onSurface))
                          )
                        ),
                        DropdownMenuItem(
                          value: 1, 
                          child: Tooltip(
                            message: l10n.qosTooltip1 ?? '', 
                            child: Text(l10n.qos1 ?? 'QoS 1', style: TextStyle(color: theme.colorScheme.onSurface))
                          )
                        ),
                        DropdownMenuItem(
                          value: 2, 
                          child: Tooltip(
                            message: l10n.qosTooltip2 ?? '', 
                            child: Text(l10n.qos2 ?? 'QoS 2', style: TextStyle(color: theme.colorScheme.onSurface))
                          )
                        ),
                      ],
                      onChanged: isRunning ? null : (v) => onQosChanged(v ?? 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Row 2: Topic (Full Width)
              _buildTextField(context, l10n.topic, topicController, isRunning, customColor: useFeaturedStyle ? colorScheme.onPrimaryContainer : null),
              const SizedBox(height: 12),
              
              // Row 3: SSL Switch
              Row(
                children: [
                   SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: enableSsl,
                      side: BorderSide(
                        color: useFeaturedStyle 
                          ? colorScheme.onPrimaryContainer.withOpacity(0.8) 
                          : colorScheme.onSurfaceVariant
                      ),
                      checkColor: useFeaturedStyle ? colorScheme.surface : colorScheme.onPrimary,
                      activeColor: useFeaturedStyle ? colorScheme.onPrimaryContainer : colorScheme.primary,
                      onChanged: isRunning ? null : (v) => onSslChanged(v ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.enableSsl,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: useFeaturedStyle ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                    ),
                  ),
                ],
              ),

              // Row 4: SSL Files (Conditional)
              if (enableSsl) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildSslField(context, l10n.caCertificate, caPathController, isRunning, useFeaturedStyle ? colorScheme.onPrimaryContainer : null, l10n)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSslField(context, l10n.clientCertificate, certPathController, isRunning, useFeaturedStyle ? colorScheme.onPrimaryContainer : null, l10n)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSslField(context, l10n.privateKey, keyPathController, isRunning, useFeaturedStyle ? colorScheme.onPrimaryContainer : null, l10n)),
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

  Widget _buildSslField(BuildContext context, String label, TextEditingController controller, bool isLocked, Color? customColor, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            // height: 40, // Height is now controlled by isDense/contentPadding in _buildTextField
            child: _buildTextField(context, label, controller, isLocked, customColor: customColor),
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
        controller.text = result.files.single.path!;
    }
  }
  
  // Replicating _buildTextField from SimulatorPanel but as a pure function
  Widget _buildTextField(BuildContext context, String label, TextEditingController controller, bool isLocked, {bool isNumber = false, Color? customColor}) {
    // Note: Validation is done by Form at parent level or we can move validator here if passed
    // For now, simple text field. The original had a validator. 
    // We should keep it as TextFormField for Form integration.
    
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        if (isNumber && int.tryParse(value) == null) return 'Invalid number';
        return null;
      },
    );
  }
  
  Widget _buildSectionHeader(String title, BuildContext context, {Color? color}) {
     // This was using _buildSectionHeader in SimulatorPanel.
     // We can just recreate a simple Text or use the same style.
     final theme = Theme.of(context);
     return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color ?? theme.colorScheme.primary,
        ),
      ),
    );
  }
}
