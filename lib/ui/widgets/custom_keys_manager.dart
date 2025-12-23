import 'package:flutter/material.dart';
import '../../models/custom_key_config.dart';
import '../../l10n/generated/app_localizations.dart';

class CustomKeysManager extends StatefulWidget {
  final List<CustomKeyConfig> keys;
  final Function(List<CustomKeyConfig>) onKeysChanged;
  final bool isLocked;
  final int maxKeys;
  final Color? headerColor;
  final bool enableExpandedLayout;

  const CustomKeysManager({
    super.key,
    required this.keys,
    required this.onKeysChanged,
    this.isLocked = false,
    this.maxKeys = 100,
    this.headerColor,
    this.enableExpandedLayout = false,
  });

  @override
  State<CustomKeysManager> createState() => _CustomKeysManagerState();
}

class _CustomKeysManagerState extends State<CustomKeysManager> {
  late List<CustomKeyConfig> _localKeys;
  final ScrollController _scrollController = ScrollController();
  
  // Search State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _localKeys = List.from(widget.keys);
  }
  
  @override
  void didUpdateWidget(covariant CustomKeysManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.keys != oldWidget.keys) {
        _localKeys = List.from(widget.keys);
    }
  }

  List<CustomKeyConfig> get _filteredKeys {
    if (_searchQuery.isEmpty) return _localKeys;
    return _localKeys.where((k) => k.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  void _addKey() {
    if (_localKeys.length >= widget.maxKeys) return;
    setState(() {
      _localKeys.add(CustomKeyConfig(name: 'key_custom_${_localKeys.length + 1}'));
      _clearSearch(); // Clear search to show new key
      widget.onKeysChanged(_localKeys);
    });
  }

  void _removeKey(CustomKeyConfig key) {
    setState(() {
      _localKeys.removeWhere((k) => k.id == key.id);
      widget.onKeysChanged(_localKeys);
    });
  }

  void _updateKey(CustomKeyConfig newKey) {
    final index = _localKeys.indexWhere((k) => k.id == newKey.id);
    if (index != -1) {
      setState(() {
        _localKeys[index] = newKey;
        widget.onKeysChanged(_localKeys);
      });
    }
  }

  void _createSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }
  
  void _clearSearch() {
    if (_searchQuery.isNotEmpty) {
      setState(() {
        _searchQuery = '';
        _searchController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.customKeys, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: widget.headerColor ?? theme.colorScheme.primary)),
                if (_localKeys.length > widget.maxKeys)
                  Text(
                    '${l10n.limitExceeded} (${_localKeys.length}/${widget.maxKeys})',
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                  )
                else
                  Text(
                    '${_localKeys.length}/${widget.maxKeys}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                  ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(_isSearchVisible ? Icons.search_off : Icons.search, size: 20),
                  onPressed: _createSearch,
                  tooltip: l10n.searchLabel,
                  visualDensity: VisualDensity.compact,
                ),
                if (!widget.isLocked) ...[
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: _localKeys.length >= widget.maxKeys ? null : _addKey,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(l10n.add),
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ],
            ),
          ],
        ),
        if (_isSearchVisible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: _clearSearch,
                    )
                  : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        const SizedBox(height: 6),
        widget.enableExpandedLayout 
          ? Expanded(child: _buildListContainer())
          : _buildListContainer(),
      ],
    );
  }

  Widget _buildListContainer() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    if (!widget.enableExpandedLayout) {
      // Natural flow layout (part of parent scroll)
      return ListView.builder(
        // remove controller to avoid "no Client" errors when disposed in ExpansionTile
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: _filteredKeys.length,
        itemBuilder: (context, index) {
          final key = _filteredKeys[index];
          final originalIndex = _localKeys.indexOf(key);
          final isIgnored = originalIndex >= widget.maxKeys;
          return KeyedSubtree(
            key: ValueKey(key.id),
            child: _buildKeyCard(key, l10n, theme, isIgnored),
          );
        },
      );
    }

    // Expanded/Scrollable layout independent of parent
    return Container(
      constraints: null,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: ListView.builder(
          controller: _scrollController,
          shrinkWrap: false,
          itemCount: _filteredKeys.length,
          itemBuilder: (context, index) {
            final key = _filteredKeys[index];
            final originalIndex = _localKeys.indexOf(key);
            final isIgnored = originalIndex >= widget.maxKeys;
            return KeyedSubtree(
              key: ValueKey(key.id),
              child: _buildKeyCard(key, l10n, theme, isIgnored),
            );
          },
        ),
      ),
    );
  }

  Widget _buildKeyCard(CustomKeyConfig key, AppLocalizations l10n, ThemeData theme, bool isIgnored) {
    return Opacity(
      opacity: isIgnored ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isIgnored 
              ? theme.colorScheme.surfaceVariant.withOpacity(0.3)
              : theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(4),
          border: isIgnored ? Border.all(color: theme.colorScheme.outline.withOpacity(0.2)) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isIgnored)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    l10n.ignored, 
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold, 
                      color: theme.colorScheme.onErrorContainer
                    )
                  ),
                ),
              ),
            // Name Input
            Expanded(
              flex: 3,
              child: TextFormField(
                initialValue: key.name,
                decoration: InputDecoration(
                  labelText: l10n.keyName, 
                  isDense: true,
                  border: const UnderlineInputBorder(),
                ),
                onChanged: (v) => _updateKey(key.copyWith(name: v)),
                enabled: !widget.isLocked,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            // Type Dropdown
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<CustomKeyType>(
                value: key.type,
                decoration: InputDecoration(
                  labelText: l10n.type, 
                  isDense: true,
                  border: const UnderlineInputBorder(),
                ),
                items: CustomKeyType.values.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(_getTypeLabel(type, l10n), style: const TextStyle(fontSize: 12)),
                )).toList(),
                onChanged: widget.isLocked ? null : (v) => _updateKey(key.copyWith(type: v!)),
              ),
            ),
            const SizedBox(width: 8),
            // Mode Dropdown
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<CustomKeyMode>(
                value: key.mode,
                decoration: InputDecoration(
                  labelText: l10n.mode, 
                  isDense: true,
                  border: const UnderlineInputBorder(),
                ),
                items: CustomKeyMode.values.map((mode) => DropdownMenuItem(
                  value: mode,
                  child: Text(_getModeLabel(mode, l10n), style: const TextStyle(fontSize: 12)),
                )).toList(),
                onChanged: widget.isLocked ? null : (v) => _updateKey(key.copyWith(mode: v!)),
              ),
            ),
            const SizedBox(width: 8),
            // Mode specific params
            Expanded(
               flex: 4,
               child: _buildModeParams(key, l10n),
            ),
            
            if (!widget.isLocked) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                onPressed: () => _removeKey(key),
                visualDensity: VisualDensity.compact,
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildModeParams(CustomKeyConfig key, AppLocalizations l10n) {
    if (key.mode == CustomKeyMode.random) {
      return Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: key.min?.toString(),
              decoration: InputDecoration(
                labelText: l10n.min, 
                isDense: true,
                border: const UnderlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => _updateKey(key.copyWith(min: double.tryParse(v) ?? 0)),
              enabled: !widget.isLocked,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
             child: TextFormField(
              initialValue: key.max?.toString(),
              decoration: InputDecoration(
                labelText: l10n.max, 
                isDense: true,
                border: const UnderlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => _updateKey(key.copyWith(max: double.tryParse(v) ?? 100)),
              enabled: !widget.isLocked,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      );
    } else if (key.mode == CustomKeyMode.static) {
      return TextFormField(
        initialValue: key.staticValue,
        decoration: InputDecoration(
          labelText: l10n.staticValue, 
          isDense: true,
          border: const UnderlineInputBorder(),
        ),
        onChanged: (v) => _updateKey(key.copyWith(staticValue: v)),
        enabled: !widget.isLocked,
        style: const TextStyle(fontSize: 13),
      );
    }
    return const SizedBox.shrink();
  }

  String _getTypeLabel(CustomKeyType type, AppLocalizations l10n) {
    switch (type) {
      case CustomKeyType.integer: return l10n.typeInteger;
      case CustomKeyType.float: return l10n.typeFloat;
      case CustomKeyType.string: return l10n.typeString;
      case CustomKeyType.boolean: return l10n.typeBoolean;
    }
  }

  String _getModeLabel(CustomKeyMode mode, AppLocalizations l10n) {
    switch (mode) {
      case CustomKeyMode.static: return l10n.modeStatic;
      case CustomKeyMode.increment: return l10n.modeIncrement;
      case CustomKeyMode.random: return l10n.modeRandom;
      case CustomKeyMode.toggle: return l10n.modeToggle;
    }
  }
}
