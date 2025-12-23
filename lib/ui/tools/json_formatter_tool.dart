import 'dart:convert';
import 'dart:async'; // For Timer
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import
import '../widgets/json_tree_view.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../utils/app_toast.dart';

class JsonFormatterTool extends StatefulWidget {
  const JsonFormatterTool({super.key});

  @override
  State<JsonFormatterTool> createState() => _JsonFormatterToolState();
}

class _JsonFormatterToolState extends State<JsonFormatterTool> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  
  // Search Navigation
  List<List<dynamic>> _matches = [];
  int _currentMatchIndex = -1;
  dynamic _parsedData;
  
  // Expand Control
  final ValueNotifier<TreeControlState> _treeControlNotifier = ValueNotifier(TreeControlState(0, false));
  int _controlVersion = 0;
  bool _isTreeExpanded = false;
  
  // Persistence
  Timer? _saveTimer;
  static const String _storageKey = 'json_formatter_content';

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }
  
  @override
  void dispose() {
    _saveTimer?.cancel();
    _treeControlNotifier.dispose();
    super.dispose();
  }
  
  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final content = prefs.getString(_storageKey);
    if (content != null && content.isNotEmpty) {
      if (mounted) {
        setState(() {
          _inputController.text = content;
        });
        // Parse it
        try {
           final obj = json.decode(content);
           _updateParsedData(obj, save: false); // Don't save again immediately
        } catch (_) {}
      }
    }
  }
  
  void _saveDelayed() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () {
      _saveState();
    });
  }
  
  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _inputController.text);
  }

  void _formatJson() {
    final text = _inputController.text;
    if (text.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;

    try {
      final object = json.decode(text);
      final prettyString = const JsonEncoder.withIndent('    ').convert(object);
      _inputController.text = prettyString;
      _setStatus(l10n.formatSuccess, Colors.green);
      _updateParsedData(object);
    } catch (e) {
      _setStatus('${l10n.invalidJson}: $e', Theme.of(context).colorScheme.error);
    }
  }

  void _minifyJson() {
    final text = _inputController.text;
    if (text.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;

    try {
      final object = json.decode(text);
      final miniString = json.encode(object);
      _inputController.text = miniString;
      _setStatus(l10n.minifySuccess, Colors.green);
      _updateParsedData(object);
    } catch (e) {
      _setStatus('${l10n.invalidJson}: $e', Theme.of(context).colorScheme.error);
    }
  }

  void _clear() {
    _inputController.clear();
    setState(() {
      _parsedData = null;
      _matches = [];
      _currentMatchIndex = -1;
      _searchQuery = '';
      _searchController.clear();
    });
    _saveState(); // Save empty
    _setStatus(AppLocalizations.of(context)!.ready, Colors.grey);
  }

  void _copyInput() {
    final l10n = AppLocalizations.of(context)!;
    if (_inputController.text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _inputController.text));
    _setStatus(l10n.copySuccess, Colors.green);
  }

  void _copyTree() {
     _copyInput();
  }
  
  void _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _inputController.text = data!.text!;
      _saveState(); // Save immediately on paste
      // Try parse
      try {
        final obj = json.decode(data!.text!);
        _updateParsedData(obj, save: false);
      } catch (e) {
        // ignore
      }
    }
  }
  
  void _updateParsedData(dynamic data, {bool save = true}) {
    setState(() {
      _parsedData = data;
      _isTreeExpanded = false;
    });
    if (save) {
      _saveDelayed();
    }
    // If search active, re-search
    if (_searchQuery.isNotEmpty) {
      _performSearch(_searchQuery);
    }
  }
  
  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _matches = [];
        _currentMatchIndex = -1;
      });
      return;
    }
    
    // Find all paths
    final newMatches = <List<dynamic>>[];
    if (_parsedData != null) {
      _findMatchesRecursive(_parsedData, query.toLowerCase(), [], newMatches);
    }
    
    setState(() {
      _matches = newMatches;
      _currentMatchIndex = newMatches.isNotEmpty ? 0 : -1;
    });
  }
  
  void _findMatchesRecursive(dynamic matchData, String query, List<dynamic> currentPath, List<List<dynamic>> results) {
    // Check self (value)
    if (matchData is! Map && matchData is! List) {
      if (matchData.toString().toLowerCase().contains(query)) {
        results.add(List.from(currentPath));
      }
      return;
    }
    
    if (matchData is Map) {
      for (var entry in matchData.entries) {
        final keyName = entry.key;
        final nextPath = [...currentPath, keyName];
        
        // Check Key match
        if (keyName.toLowerCase().contains(query)) {
           // If key matches, we highlight this node.
           results.add(nextPath);
        }
        
        // Recurse Value
        _findMatchesRecursive(entry.value, query, nextPath, results);
      }
    } else if (matchData is List) {
      for (int i=0; i<matchData.length; i++) {
        final nextPath = [...currentPath, i];
        // List index isn't usually matched against text query, but recursion continues
        _findMatchesRecursive(matchData[i], query, nextPath, results);
      }
    }
  }
  
  void _nextMatch() {
    if (_matches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matches.length;
    });
  }
  
  void _prevMatch() {
    if (_matches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _matches.length) % _matches.length;
    });
  }

  // 使用AppToast显示消息通知
  void _setStatus(String msg, Color color) {
    if (color == Colors.green) {
      AppToast.success(context, msg);
    } else if (color == Colors.orange) {
      AppToast.warning(context, msg);
    } else if (color == Theme.of(context).colorScheme.error || color == Colors.red) {
      AppToast.error(context, msg);
    } else if (color != Colors.grey) {
      AppToast.info(context, msg);
    }
  }
  
  void _toggleExpansion() {
    setState(() {
      _isTreeExpanded = !_isTreeExpanded;
    });
    _controlVersion++;
    _treeControlNotifier.value = TreeControlState(_controlVersion, _isTreeExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Common Button Style
    final ButtonStyle textButtonStyle = TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
        foregroundColor: colorScheme.primary, // Use primary color for better theme adaptation
        textStyle: const TextStyle(fontWeight: FontWeight.w600), // Make text slightly bolder
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT CONTAINER: Input
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                      boxShadow: [
                         BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                      ]
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Left Toolbar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          color: colorScheme.surfaceContainerHighest,
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 8, right: 12),
                                child: Text(l10n.inputLabel, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton.icon(onPressed: _copyInput, icon: const Icon(Icons.copy, size: 16), label: Text(l10n.copyAction), style: textButtonStyle),
                                        TextButton.icon(onPressed: _paste, icon: const Icon(Icons.paste, size: 16), label: Text(l10n.pasteAction), style: textButtonStyle),
                                        TextButton.icon(onPressed: _clear, icon: const Icon(Icons.clear, size: 16), label: Text(l10n.clearAction), style: textButtonStyle),
                                        
                                        const SizedBox(width: 4),
                                        Container(width: 1, height: 20, color: theme.dividerColor),
                                        const SizedBox(width: 4),
                                        
                                        TextButton.icon(onPressed: _formatJson, icon: const Icon(Icons.format_align_left, size: 16), label: Text(l10n.formatAction), style: textButtonStyle),
                                        TextButton.icon(onPressed: _minifyJson, icon: const Icon(Icons.compress, size: 16), label: Text(l10n.minifyAction), style: textButtonStyle),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            scrollController: _scrollController,
                            expands: true, 
                            maxLines: null,
                            minLines: null,
                            keyboardType: TextInputType.multiline,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(fontFamily: 'Courier', fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Paste or type JSON here...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                            onChanged: (val) {
                              _saveDelayed(); // Debounce save
                              try {
                                final obj = json.decode(val);
                                _updateParsedData(obj, save: false); // Already saving
                              } catch(e) { /* user format */ }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // RIGHT CONTAINER: Tree View
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                      boxShadow: [
                         BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                      ]
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Right Toolbar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          color: colorScheme.surfaceContainerHighest,
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 8, right: 12),
                                child: Text(l10n.treeViewLabel, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton.icon(
                                          onPressed: _toggleExpansion,
                                          icon: Icon(_isTreeExpanded ? Icons.unfold_less : Icons.unfold_more, size: 16),
                                          label: Text(_isTreeExpanded ? l10n.collapseAll : l10n.expandAll),
                                          style: textButtonStyle,
                                        ),
                                        
                                        const SizedBox(width: 8),
                                        Container(width: 1, height: 20, color: theme.dividerColor),
                                        const SizedBox(width: 8),
                                        
                                        SizedBox(
                                          width: 200, 
                                          height: 32,
                                          child: TextField(
                                            controller: _searchController,
                                            decoration: InputDecoration(
                                              hintText: l10n.searchHint,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                              filled: true,
                                              fillColor: colorScheme.surface,
                                              prefixIcon: const Icon(Icons.search, size: 16),
                                              suffixIcon: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (_matches.isNotEmpty)
                                                     Text(
                                                       '${_currentMatchIndex + 1}/${_matches.length}', 
                                                       style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)
                                                     ),
                                                  if (_searchQuery.isNotEmpty)
                                                    GestureDetector(
                                                      onTap: () { 
                                                        _searchController.clear(); 
                                                        setState(() { _searchQuery = ''; _matches = []; _currentMatchIndex = -1; }); 
                                                      }, 
                                                      child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.close, size: 14))
                                                    ),
                                                  if (_matches.isNotEmpty) ...[
                                                      const VerticalDivider(width: 1, indent: 4, endIndent: 4),
                                                      GestureDetector(onTap: _prevMatch, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.keyboard_arrow_up, size: 16))),
                                                      GestureDetector(onTap: _nextMatch, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.keyboard_arrow_down, size: 16))),
                                                  ]
                                                ],
                                              ),
                                            ),
                                            style: const TextStyle(fontSize: 12),
                                            onChanged: (val) {
                                              setState(() => _searchQuery = val);
                                              _performSearch(val);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Tree Area
                        Expanded(
                          child: Container(
                            color: colorScheme.surface,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16.0),
                              child: _buildTreeContent(l10n, theme),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeContent(AppLocalizations l10n, ThemeData theme) {
    if (_parsedData == null) {
      if (_inputController.text.trim().isEmpty) {
        return Center(child: Text(l10n.enterJsonHint, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)));
      } else {
        // Try to parse once if not parsed
        try {
          final obj = json.decode(_inputController.text);
          WidgetsBinding.instance.addPostFrameCallback((_) {
             _updateParsedData(obj, save: false);
          });
        } catch (_) {}
      }
    }
    
    if (_parsedData != null) {
      return JsonTreeView(
        data: _parsedData, 
        isRoot: true, 
        searchQuery: _searchQuery,
        activeMatchPath: _matches.isNotEmpty && _currentMatchIndex >= 0 ? _matches[_currentMatchIndex] : null,
        expandAllNotifier: _treeControlNotifier,
      );
    }
    
    return Center(child: Text('${l10n.invalidJson}', style: TextStyle(color: theme.colorScheme.error)));
  }
}
