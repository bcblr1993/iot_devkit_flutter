import 'package:flutter/material.dart';
import '../../models/group_config.dart';
import 'custom_keys_manager.dart';
import '../../l10n/generated/app_localizations.dart';
import '../lab/lab.dart';
import '../components/app_input_decoration.dart';
import '../components/form_grid.dart';

class GroupsManager extends StatefulWidget {
  final List<GroupConfig> groups;
  final Function(List<GroupConfig>) onGroupsChanged;
  final bool isLocked;
  final Color? headerColor;

  const GroupsManager({
    super.key,
    required this.groups,
    required this.onGroupsChanged,
    this.isLocked = false,
    this.headerColor,
  });

  @override
  State<GroupsManager> createState() => _GroupsManagerState();
}

class _GroupsManagerState extends State<GroupsManager> {
  // We keep a local copy to edit, then emit changes up
  late List<GroupConfig> _localGroups;

  bool _initialCheckDone = false;

  @override
  void initState() {
    super.initState();
    _localGroups = List.from(widget.groups);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialCheckDone) {
      if (_localGroups.isEmpty) {
        _addGroup();
      }
      _initialCheckDone = true;
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
    final l10n = AppLocalizations.of(context)!;
    if (_localGroups.length >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.maxGroupsReached)),
      );
      return;
    }
    setState(() {
      _localGroups.add(GroupConfig(
          name:
              '${l10n.groupLabel} ${String.fromCharCode(65 + _localGroups.length)}'));
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

  void _toggleAll(bool expand) {
    // If we're expanding, we iterate and set isExpanded = true
    // If collapsing, isExpanded = false
    final newGroups =
        _localGroups.map((g) => g.copyWith(isExpanded: expand)).toList();
    setState(() {
      _localGroups = newGroups;
      widget.onGroupsChanged(_localGroups);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool allExpanded = _localGroups.every((g) => g.isExpanded);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                      width: 4,
                      height: 16,
                      color: widget.headerColor ??
                          Theme.of(context).colorScheme.primary,
                      margin: const EdgeInsets.only(right: 8)),
                  Text(l10n.groupManagement,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: widget.headerColor ??
                              Theme.of(context).colorScheme.primary)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => _toggleAll(!allExpanded),
                    icon: Icon(
                        allExpanded ? Icons.unfold_less : Icons.unfold_more,
                        size: 18),
                    label: Text(allExpanded ? l10n.collapseAll : l10n.expandAll,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: widget.headerColor ??
                          Theme.of(context).colorScheme.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  if (!widget.isLocked) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _localGroups.length >= 12 ? null : _addGroup,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.addGroup),
                      style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
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

    final cardContent = ExpansionTile(
      key: ValueKey("${group.id}_${group.isExpanded}"),
      initiallyExpanded: group.isExpanded,
      onExpansionChanged: (expanded) {
        _updateGroup(index, group.copyWith(isExpanded: expanded));
      },
      title:
          Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
          '${l10n.unitDevices}: ${group.startDeviceNumber} - ${group.endDeviceNumber}',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      trailing: widget.isLocked
          ? null
          : IconButton(
              icon: Icon(Icons.delete, color: theme.colorScheme.error),
              onPressed: () => _removeGroup(index),
            ),
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FormGrid(
                minItemWidth: 210,
                children: [
                  _buildTextField(l10n.groupName, group.name,
                      (v) => _updateGroup(index, group.copyWith(name: v)),
                      enabled: !widget.isLocked),
                  _buildTextField(
                      l10n.startIndex,
                      group.startDeviceNumber.toString(),
                      (v) => _updateGroup(
                          index,
                          group.copyWith(
                              startDeviceNumber: int.tryParse(v) ?? 1)),
                      isNumber: true,
                      enabled: !widget.isLocked),
                  _buildTextField(
                      l10n.endIndex,
                      group.endDeviceNumber.toString(),
                      (v) => _updateGroup(
                          index,
                          group.copyWith(
                              endDeviceNumber: int.tryParse(v) ?? 10)),
                      isNumber: true,
                      enabled: !widget.isLocked),
                  _buildTextField(
                      l10n.deviceName,
                      group.devicePrefix,
                      (v) =>
                          _updateGroup(index, group.copyWith(devicePrefix: v)),
                      enabled: !widget.isLocked),
                  _buildTextField(
                      l10n.clientId,
                      group.clientIdPrefix,
                      (v) => _updateGroup(
                          index, group.copyWith(clientIdPrefix: v)),
                      enabled: !widget.isLocked),
                  _buildTextField(
                      l10n.username,
                      group.usernamePrefix,
                      (v) => _updateGroup(
                          index, group.copyWith(usernamePrefix: v)),
                      enabled: !widget.isLocked),
                  _buildTextField(
                      l10n.password,
                      group.passwordPrefix,
                      (v) => _updateGroup(
                          index, group.copyWith(passwordPrefix: v)),
                      enabled: !widget.isLocked),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: group.format,
                    decoration:
                        AppInputDecoration.filled(context, label: l10n.format),
                    items: [
                      DropdownMenuItem(
                          value: 'default',
                          child: Text(l10n.formatDefault,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12))),
                      DropdownMenuItem(
                          value: 'tn',
                          child: Text(l10n.formatTieNiu,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12))),
                      DropdownMenuItem(
                          value: 'tn-empty',
                          child: Text(l10n.formatTieNiuEmpty,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12))),
                    ],
                    onChanged: widget.isLocked
                        ? null
                        : (v) =>
                            _updateGroup(index, group.copyWith(format: v!)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FormGrid(
                minItemWidth: 210,
                children: [
                  _buildTextField(
                      l10n.totalKeys,
                      group.totalKeyCount.toString(),
                      (v) => _updateGroup(index,
                          group.copyWith(totalKeyCount: int.tryParse(v) ?? 10)),
                      isNumber: true,
                      enabled: !widget.isLocked),
                  _buildTextField(
                      l10n.changeRatio,
                      group.changeRatio.toString(),
                      (v) => _updateGroup(
                          index,
                          group.copyWith(
                              changeRatio: double.tryParse(v) ?? 0.3)),
                      isNumber: true,
                      enabled: !widget.isLocked),
                  _buildTextField(
                      l10n.changeInterval,
                      group.changeIntervalSeconds.toString(),
                      (v) => _updateGroup(
                          index,
                          group.copyWith(
                              changeIntervalSeconds: int.tryParse(v) ?? 1)),
                      isNumber: true,
                      enabled: !widget.isLocked),
                  _buildTextField(
                      l10n.fullInterval,
                      group.fullIntervalSeconds.toString(),
                      (v) => _updateGroup(
                          index,
                          group.copyWith(
                              fullIntervalSeconds: int.tryParse(v) ?? 300)),
                      isNumber: true,
                      enabled: !widget.isLocked),
                ],
              ),
              const SizedBox(height: 12),
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
    );

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      // No ClipRRect or BackdropFilter for non-glass
      child: cardContent,
    );
  }

  Widget _buildTextField(String label, String value, Function(String) onChanged,
      {bool isNumber = false, bool enabled = true}) {
    return LabField(
      label: label,
      initialValue: value,
      enabled: enabled,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: enabled ? onChanged : null,
      validator: (value) {
        if (!enabled) return null;
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context)!.fieldRequired;
        }
        if (isNumber && num.tryParse(value) == null) {
          return AppLocalizations.of(context)!.invalidNumber;
        }
        return null;
      },
    );
  }
}
