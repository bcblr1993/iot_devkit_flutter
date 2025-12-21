import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iot_devkit/services/theme_manager.dart';
import '../../models/group_config.dart';
import '../../models/custom_key_config.dart';
import 'custom_keys_manager.dart';
import '../../l10n/generated/app_localizations.dart';

class GroupsManager extends StatefulWidget {
  final List<GroupConfig> groups;
  final Function(List<GroupConfig>) onGroupsChanged;
  final bool isLocked;

  const GroupsManager({
    super.key,
    required this.groups,
    required this.onGroupsChanged,
    this.isLocked = false,
  });

  @override
  State<GroupsManager> createState() => _GroupsManagerState();
}

class _GroupsManagerState extends State<GroupsManager> {
  // We keep a local copy to edit, then emit changes up
  late List<GroupConfig> _localGroups;

  @override
  void initState() {
    super.initState();
    _localGroups = List.from(widget.groups);
    if (_localGroups.isEmpty) {
      _addGroup();
    }
  }

  @override
  void didUpdateWidget(covariant GroupsManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.groups != oldWidget.groups) {
      setState(() {
        _localGroups = List.from(widget.groups);
      });
    }
  }

  void _addGroup() {
    setState(() {
      _localGroups.add(GroupConfig(name: 'Group ${String.fromCharCode(65 + _localGroups.length)}'));
      widget.onGroupsChanged(_localGroups);
    });
  }

  void _removeGroup(int index) {
    if (_localGroups.length <= 1) return; // Keep at least one
    setState(() {
      _localGroups.removeAt(index);
      widget.onGroupsChanged(_localGroups);
    });
  }

  void _updateGroup(int index, GroupConfig newConfig) {
    setState(() {
      _localGroups[index] = newConfig;
      // Debounce this potentially if it causes too many rebuilds, but for now simple callback is fine
      widget.onGroupsChanged(_localGroups);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.groupManagement, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary)),
            if (!widget.isLocked)
              FilledButton.icon(
                onPressed: _addGroup,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addGroup),
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _localGroups.length,
          itemBuilder: (context, index) {
            return _buildGroupCard(index, _localGroups[index], l10n);
          },
        ),
      ],
    );
  }

  Widget _buildGroupCard(int index, GroupConfig group, AppLocalizations l10n) {
    final theme = Theme.of(context);
    
    final themeManager = Provider.of<ThemeManager>(context);
    final isGlass = themeManager.currentThemeName.contains('glass');
    
    return Card(
      elevation: isGlass ? 0 : 1,
      color: isGlass ? theme.cardColor : null, // Use transparent color from theme
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16), // Match theme radius if possible
        child: BackdropFilter(
          filter: isGlass 
              ? ImageFilter.blur(sigmaX: 10, sigmaY: 10) 
              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: ExpansionTile(
        key: ValueKey(group.id),
        initiallyExpanded: group.isExpanded,
        onExpansionChanged: (expanded) {
          _updateGroup(index, group.copyWith(isExpanded: expanded));
        },
        title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Devices: ${group.startDeviceNumber} - ${group.endDeviceNumber}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        trailing: widget.isLocked 
          ? null 
          : IconButton(
              icon: Icon(Icons.delete, color: theme.colorScheme.error),
              onPressed: () => _removeGroup(index),
            ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: widget.isLocked 
                ? Text('Settings locked while running.', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)))
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildTextField(l10n.groupName, group.name, (v) => _updateGroup(index, group.copyWith(name: v)))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTextField(l10n.startIndex, group.startDeviceNumber.toString(), (v) => _updateGroup(index, group.copyWith(startDeviceNumber: int.tryParse(v) ?? 1)), isNumber: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTextField(l10n.endIndex, group.endDeviceNumber.toString(), (v) => _updateGroup(index, group.copyWith(endDeviceNumber: int.tryParse(v) ?? 10)), isNumber: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTextField(l10n.deviceName, group.devicePrefix, (v) => _updateGroup(index, group.copyWith(devicePrefix: v)))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildTextField(l10n.clientId, group.clientIdPrefix, (v) => _updateGroup(index, group.copyWith(clientIdPrefix: v)))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTextField(l10n.username, group.usernamePrefix, (v) => _updateGroup(index, group.copyWith(usernamePrefix: v)))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTextField(l10n.password, group.passwordPrefix, (v) => _updateGroup(index, group.copyWith(passwordPrefix: v)))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: group.format,
                        decoration: InputDecoration(
                          labelText: l10n.format,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(value: 'default', child: Text(l10n.formatDefault, style: const TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'tn', child: Text(l10n.formatTieNiu, style: const TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'tn-empty', child: Text(l10n.formatTieNiuEmpty, style: const TextStyle(fontSize: 12))),
                        ],
                        onChanged: widget.isLocked ? null : (v) => _updateGroup(index, group.copyWith(format: v!)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildTextField(l10n.totalKeys, group.totalKeyCount.toString(), (v) => _updateGroup(index, group.copyWith(totalKeyCount: int.tryParse(v) ?? 10)), isNumber: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTextField(l10n.changeRatio, group.changeRatio.toString(), (v) => _updateGroup(index, group.copyWith(changeRatio: double.tryParse(v) ?? 0.3)), isNumber: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTextField(l10n.changeInterval, group.changeIntervalSeconds.toString(), (v) => _updateGroup(index, group.copyWith(changeIntervalSeconds: int.tryParse(v) ?? 1)), isNumber: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTextField(l10n.fullInterval, group.fullIntervalSeconds.toString(), (v) => _updateGroup(index, group.copyWith(fullIntervalSeconds: int.tryParse(v) ?? 300)), isNumber: true)),
                  ],
                ),
                const SizedBox(height: 10),
                const SizedBox(height: 15),
                const Divider(),
                CustomKeysManager(
                  keys: group.customKeys,
                  isLocked: widget.isLocked,
                  maxKeys: group.totalKeyCount,
                  onKeysChanged: (newKeys) {
                    _updateGroup(index, group.copyWith(customKeys: newKeys));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String value, Function(String) onChanged, {bool isNumber = false}) {
    return TextFormField(
      initialValue: value,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        // Borders are defined in Theme
      ),
      onChanged: onChanged,
    );
  }
}
