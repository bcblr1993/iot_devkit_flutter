// ignore_for_file: avoid_hardcoded_color, avoid_raw_edge_insets, prefer_lab_tokens
import 'dart:convert';
import 'dart:async'; // For Timer
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import
import '../../services/json_formatter_service.dart';
import 'json_virtualized_editor.dart';
import '../widgets/json_tree_view.dart';
import '../../l10n/generated/app_localizations.dart';
import '../lab/lab.dart';

class JsonFormatterTool extends StatefulWidget {
  const JsonFormatterTool({super.key});

  @override
  State<JsonFormatterTool> createState() => _JsonFormatterToolState();
}

class _JsonFormatterToolState extends State<JsonFormatterTool> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final VirtualizedTextController _largeInputController =
      VirtualizedTextController();

  String _searchQuery = '';

  // Search Navigation
  List<List<dynamic>> _matches = [];
  int _currentMatchIndex = -1;
  dynamic _parsedData;

  // Expand Control
  final ValueNotifier<TreeControlState> _treeControlNotifier =
      ValueNotifier(TreeControlState(0, false));
  int _controlVersion = 0;
  bool _isTreeExpanded = false;

  // Persistence
  Timer? _saveTimer;
  Timer? _parseTimer;
  static const String _storageKey = 'json_formatter_content';
  static const int _backgroundParseThreshold = 128 * 1024;
  static const int _largeDocumentThreshold = 512 * 1024;
  static const int _maxPersistedContentLength = 1024 * 1024;
  int _parseGeneration = 0;
  bool _isProcessing = false;
  bool _isLargeDocument = false;

  String get _documentText =>
      _isLargeDocument ? _largeInputController.text : _inputController.text;

  int get _documentLength => _isLargeDocument
      ? _largeInputController.length
      : _inputController.text.length;

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
    _parseTimer?.cancel();
    _inputController.dispose();
    _largeInputController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _treeControlNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final content = prefs.getString(_storageKey);
    if (content != null && content.isNotEmpty) {
      if (content.length > _maxPersistedContentLength) {
        await prefs.remove(_storageKey);
        return;
      }
      if (mounted) {
        _replaceDocumentText(content);
        _parseInput(content, immediate: true);
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
    if (_documentLength > _maxPersistedContentLength) {
      await prefs.remove(_storageKey);
      return;
    }
    final content = _documentText;
    await prefs.setString(_storageKey, content);
  }

  Future<void> _formatJson() async {
    await _transformJson(JsonOutputStyle.pretty);
  }

  Future<void> _minifyJson() async {
    await _transformJson(JsonOutputStyle.compact);
  }

  Future<void> _transformJson(JsonOutputStyle style) async {
    final text = _documentText;
    if (text.isEmpty || _isProcessing) return;
    final l10n = AppLocalizations.of(context)!;
    final generation = ++_parseGeneration;
    _parseTimer?.cancel();
    setState(() => _isProcessing = true);

    try {
      final result = await JsonFormatterService.transform(text, style);
      if (!mounted || generation != _parseGeneration) return;

      if (_documentText != result.output) {
        _replaceDocumentText(result.output);
      }
      _setStatus(
        style == JsonOutputStyle.pretty
            ? l10n.formatSuccess
            : l10n.minifySuccess,
        Colors.green,
      );
      _updateParsedData(result.data);
    } catch (e) {
      if (!mounted || generation != _parseGeneration) return;
      _setStatus(
          '${l10n.invalidJson}: $e', Theme.of(context).colorScheme.error);
    } finally {
      if (mounted && generation == _parseGeneration) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _clear() {
    _parseGeneration++;
    _parseTimer?.cancel();
    _inputController.clear();
    _largeInputController.replaceAll('');
    setState(() {
      _isLargeDocument = false;
      _parsedData = null;
      _matches = [];
      _currentMatchIndex = -1;
      _searchQuery = '';
      _searchController.clear();
      _isProcessing = false;
    });
    _saveState(); // Save empty
    _setStatus(AppLocalizations.of(context)!.ready, Colors.grey);
  }

  Future<void> _copyInput() async {
    final l10n = AppLocalizations.of(context)!;
    if (_documentText.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _documentText));
    if (!mounted) return;
    _setStatus(l10n.copySuccess, Colors.green);
  }

  void _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _replaceDocumentText(data!.text!);
      _saveState();
      _parseInput(data.text!, immediate: true);
    }
  }

  void _acceptLargeDocument(String source) {
    if (!mounted) return;
    _replaceDocumentText(source);
    _saveState();
    _parseInput(source, immediate: true);
  }

  void _replaceDocumentText(String source) {
    if (source.length > _largeDocumentThreshold) {
      _inputController.clear();
      _largeInputController.replaceAll(source);
      if (!_isLargeDocument) {
        setState(() => _isLargeDocument = true);
      }
      return;
    }

    if (_isLargeDocument) {
      setState(() => _isLargeDocument = false);
    }
    if (_inputController.text != source) {
      _inputController.value = TextEditingValue(
        text: source,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
  }

  void _onLargeDocumentChanged() {
    _saveDelayed();
    final generation = ++_parseGeneration;
    _parseTimer?.cancel();
    _parseTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || generation != _parseGeneration) {
        return;
      }
      _parseInput(_documentText, immediate: true);
    });
  }

  void _parseInput(String source, {bool immediate = false}) {
    final generation = ++_parseGeneration;
    _parseTimer?.cancel();

    if (source.trim().isEmpty) {
      setState(() {
        _parsedData = null;
        _isProcessing = false;
      });
      return;
    }

    if (source.length < _backgroundParseThreshold) {
      try {
        _updateParsedData(jsonDecode(source), save: false);
      } catch (_) {}
      if (_isProcessing) {
        setState(() => _isProcessing = false);
      }
      return;
    }

    setState(() {
      _parsedData = null;
      _isProcessing = true;
    });

    Future<void> parse() async {
      try {
        final data = await JsonFormatterService.parse(source);
        if (!mounted || generation != _parseGeneration) return;
        _updateParsedData(data, save: false);
      } catch (_) {
        // Invalid input is expected while the user is editing.
      } finally {
        if (mounted && generation == _parseGeneration) {
          setState(() => _isProcessing = false);
        }
      }
    }

    if (immediate) {
      parse();
    } else {
      _parseTimer = Timer(const Duration(milliseconds: 250), parse);
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

  void _findMatchesRecursive(dynamic matchData, String query,
      List<dynamic> currentPath, List<List<dynamic>> results) {
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
      for (int i = 0; i < matchData.length; i++) {
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
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _matches.length) % _matches.length;
    });
  }

  void _setStatus(String msg, Color color) {
    if (color == Colors.green) {
      showLabToast(context, title: msg, kind: LabStatus.ok);
    } else if (color == Colors.orange) {
      showLabToast(context, title: msg, kind: LabStatus.warn);
    } else if (color == Theme.of(context).colorScheme.error ||
        color == Colors.red) {
      showLabToast(context, title: msg, kind: LabStatus.error);
    } else if (color != Colors.grey) {
      showLabToast(context, title: msg, kind: LabStatus.info);
    }
  }

  void _toggleExpansion() {
    setState(() {
      _isTreeExpanded = !_isTreeExpanded;
    });
    _controlVersion++;
    _treeControlNotifier.value =
        TreeControlState(_controlVersion, _isTreeExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ]),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Left Toolbar
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          color: colorScheme.surfaceContainerHighest,
                          child: Row(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 8, right: 12),
                                child: Text(l10n.inputLabel,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurfaceVariant)),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        LabButton(
                                            label: l10n.copyAction,
                                            icon: Icons.copy,
                                            variant: LabButtonVariant.ghost,
                                            size: LabButtonSize.sm,
                                            onPressed: _copyInput),
                                        LabButton(
                                            label: l10n.pasteAction,
                                            icon: Icons.paste,
                                            variant: LabButtonVariant.ghost,
                                            size: LabButtonSize.sm,
                                            onPressed: _paste),
                                        LabButton(
                                            label: l10n.clearAction,
                                            icon: Icons.clear,
                                            variant: LabButtonVariant.ghost,
                                            size: LabButtonSize.sm,
                                            onPressed: _clear),
                                        const SizedBox(width: 4),
                                        Container(
                                            width: 1,
                                            height: 20,
                                            color: theme.dividerColor),
                                        const SizedBox(width: 4),
                                        LabButton(
                                            label: l10n.formatAction,
                                            icon: Icons.format_align_left,
                                            variant: LabButtonVariant.ghost,
                                            size: LabButtonSize.sm,
                                            loading: _isProcessing,
                                            onPressed: _isProcessing
                                                ? null
                                                : _formatJson),
                                        LabButton(
                                            label: l10n.minifyAction,
                                            icon: Icons.compress,
                                            variant: LabButtonVariant.ghost,
                                            size: LabButtonSize.sm,
                                            onPressed: _isProcessing
                                                ? null
                                                : _minifyJson),
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
                          child: _isLargeDocument
                              ? VirtualizedJsonEditor(
                                  controller: _largeInputController,
                                  onChanged: _onLargeDocumentChanged,
                                )
                              : TextField(
                                  controller: _inputController,
                                  scrollController: _scrollController,
                                  expands: true,
                                  maxLines: null,
                                  minLines: null,
                                  keyboardType: TextInputType.multiline,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: const TextStyle(
                                      fontFamily: 'Courier', fontSize: 13),
                                  decoration: const InputDecoration(
                                    hintText: 'Paste or type JSON here...',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(16),
                                  ),
                                  inputFormatters: [
                                    LargeJsonTextInputFormatter(
                                      maxEditableCharacters:
                                          _largeDocumentThreshold,
                                      onLargeText: _acceptLargeDocument,
                                    ),
                                  ],
                                  onChanged: (val) {
                                    _saveDelayed();
                                    _parseInput(val);
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
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ]),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Right Toolbar
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          color: colorScheme.surfaceContainerHighest,
                          child: Row(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 8, right: 12),
                                child: Text(l10n.treeViewLabel,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurfaceVariant)),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        LabButton(
                                          label: _isTreeExpanded
                                              ? l10n.collapseAll
                                              : l10n.expandAll,
                                          icon: _isTreeExpanded
                                              ? Icons.unfold_less
                                              : Icons.unfold_more,
                                          variant: LabButtonVariant.ghost,
                                          size: LabButtonSize.sm,
                                          onPressed: _toggleExpansion,
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                            width: 1,
                                            height: 20,
                                            color: theme.dividerColor),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 200,
                                          height: 32,
                                          child: TextField(
                                            controller: _searchController,
                                            decoration: InputDecoration(
                                              hintText: l10n.searchHint,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 0),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide.none),
                                              filled: true,
                                              fillColor: colorScheme.surface,
                                              prefixIcon: const Icon(
                                                  Icons.search,
                                                  size: 16),
                                              suffixIcon: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (_matches.isNotEmpty)
                                                    Text(
                                                        '${_currentMatchIndex + 1}/${_matches.length}',
                                                        style: TextStyle(
                                                            fontSize: 10,
                                                            color: colorScheme
                                                                .onSurfaceVariant)),
                                                  if (_searchQuery.isNotEmpty)
                                                    GestureDetector(
                                                        onTap: () {
                                                          _searchController
                                                              .clear();
                                                          setState(() {
                                                            _searchQuery = '';
                                                            _matches = [];
                                                            _currentMatchIndex =
                                                                -1;
                                                          });
                                                        },
                                                        child: const Padding(
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        4),
                                                            child: Icon(
                                                                Icons.close,
                                                                size: 14))),
                                                  if (_matches.isNotEmpty) ...[
                                                    const VerticalDivider(
                                                        width: 1,
                                                        indent: 4,
                                                        endIndent: 4),
                                                    GestureDetector(
                                                        onTap: _prevMatch,
                                                        child: const Padding(
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        4),
                                                            child: Icon(
                                                                Icons
                                                                    .keyboard_arrow_up,
                                                                size: 16))),
                                                    GestureDetector(
                                                        onTap: _nextMatch,
                                                        child: const Padding(
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        4),
                                                            child: Icon(
                                                                Icons
                                                                    .keyboard_arrow_down,
                                                                size: 16))),
                                                  ]
                                                ],
                                              ),
                                            ),
                                            style:
                                                const TextStyle(fontSize: 12),
                                            onChanged: (val) {
                                              setState(
                                                  () => _searchQuery = val);
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
    if (_isProcessing && _parsedData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_parsedData == null) {
      if (_documentText.trim().isEmpty) {
        return Center(
            child: Text(l10n.enterJsonHint,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)));
      }
    }

    if (_parsedData != null) {
      return JsonTreeView(
        data: _parsedData,
        isRoot: true,
        searchQuery: _searchQuery,
        activeMatchPath: _matches.isNotEmpty && _currentMatchIndex >= 0
            ? _matches[_currentMatchIndex]
            : null,
        expandAllNotifier: _treeControlNotifier,
      );
    }

    return Center(
        child: Text(l10n.invalidJson,
            style: TextStyle(color: theme.colorScheme.error)));
  }
}
