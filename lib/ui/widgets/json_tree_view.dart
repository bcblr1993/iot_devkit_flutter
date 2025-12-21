import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

class TreeControlState {
  final int version;
  final bool expand;
  TreeControlState(this.version, this.expand);
}

class JsonTreeView extends StatefulWidget {
  final dynamic data;
  final String? keyName;
  final bool isRoot;
  final String? searchQuery;
  final bool isArrayItem;
  
  // New props for navigation and control
  final List<dynamic> currentParamsPath; // Path from root to here
  final List<dynamic>? activeMatchPath; // The path that should be focused
  final ValueNotifier<TreeControlState>? expandAllNotifier; // Signal to expand/collapse
  
  const JsonTreeView({
    super.key,
    required this.data,
    this.keyName,
    this.isRoot = false,
    this.searchQuery,
    this.isArrayItem = false,
    this.currentParamsPath = const [],
    this.activeMatchPath,
    this.expandAllNotifier,
  });

  @override
  State<JsonTreeView> createState() => _JsonTreeViewState();
}

class _JsonTreeViewState extends State<JsonTreeView> {
  bool _isExpanded = false;
  int _localControlVersion = 0;
  int _searchExpandVersion = 0; // Forces rebuild when search triggers expansion

  static const double _iconSize = 20.0; 
  static const double _tileHPad = 4.0;
  static const double _lineMargin = 13.5; 

  @override
  void initState() {
    super.initState();
    if (widget.isRoot) {
      _isExpanded = true;
    }
    _checkSearchExpansion();
    if (widget.expandAllNotifier != null) {
      _applyGlobalState(widget.expandAllNotifier!.value);
      widget.expandAllNotifier!.addListener(_handleExpandAll);
    }
  }

  @override
  void didUpdateWidget(JsonTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      _checkSearchExpansion();
    }
    if (widget.activeMatchPath != oldWidget.activeMatchPath) {
      _checkActivePathExpansion();
    }
    
    if (widget.expandAllNotifier != oldWidget.expandAllNotifier) {
      oldWidget.expandAllNotifier?.removeListener(_handleExpandAll);
      if (widget.expandAllNotifier != null) {
         _applyGlobalState(widget.expandAllNotifier!.value);
         widget.expandAllNotifier!.addListener(_handleExpandAll);
      }
    }
    
    _checkSelfActiveScroll();
  }
  
  @override
  void dispose() {
    widget.expandAllNotifier?.removeListener(_handleExpandAll);
    super.dispose();
  }
  
  void _handleExpandAll() {
    if (widget.expandAllNotifier != null) {
      _applyGlobalState(widget.expandAllNotifier!.value);
    }
  }
  
  void _applyGlobalState(TreeControlState state) {
    // Only apply if version is newer
    if (state.version > _localControlVersion) {
      if (mounted) {
        setState(() {
          _isExpanded = state.expand;
          _localControlVersion = state.version;
        });
      } else {
        _isExpanded = state.expand;
        _localControlVersion = state.version;
      }
    }
  }

  void _checkSearchExpansion() {
    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      if (_hasMatch(widget.data)) {
        // If match found and NOT expanded, force expand and rebuild
        if (!_isExpanded) {
          setState(() {
            _isExpanded = true;
            _searchExpandVersion++;
          });
        }
      }
    }
  }
  
  void _checkActivePathExpansion() {
    if (widget.activeMatchPath != null && widget.activeMatchPath!.length > widget.currentParamsPath.length) {
       bool match = true;
       for (int i=0; i<widget.currentParamsPath.length; i++) {
         if (widget.activeMatchPath![i] != widget.currentParamsPath[i]) {
           match = false;
           break;
         }
       }
       if (match) {
         if (!_isExpanded) {
           setState(() {
             _isExpanded = true;
             _searchExpandVersion++;
           });
         }
       }
    }
  }
  
  void _checkSelfActiveScroll() {
    if (_isSelfActive()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 300));
        }
      });
    }
  }
  
  bool _isSelfActive() {
    if (widget.activeMatchPath == null) return false;
    if (widget.activeMatchPath!.length != widget.currentParamsPath.length) return false;
    for (int i=0; i<widget.activeMatchPath!.length; i++) {
      if (widget.activeMatchPath![i] != widget.currentParamsPath[i]) return false;
    }
    return true;
  }

  bool _hasMatch(dynamic data) {
    final query = widget.searchQuery?.toLowerCase() ?? '';
    if (query.isEmpty) return false;
    
    if (widget.keyName != null && widget.keyName!.toLowerCase().contains(query)) return true;
    
    if (data is! Map && data is! List) {
       return data.toString().toLowerCase().contains(query);
    }
    
    return _deepCheck(data, query);
  }
  
  bool _deepCheck(dynamic data, String query) {
    if (data is Map) {
      for (var entry in data.entries) {
        if (entry.key.toLowerCase().contains(query)) return true;
        if (_deepCheck(entry.value, query)) return true;
      }
    } else if (data is List) {
      for (var item in data) {
        if (_deepCheck(item, query)) return true;
      }
    } else {
      return data.toString().toLowerCase().contains(query);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data == null) {
      return _buildRow(context, 'null', Colors.purple, isNull: true);
    } else if (widget.data is Map) {
      return _buildObject(context, widget.data as Map<String, dynamic>);
    } else if (widget.data is List) {
      return _buildArray(context, widget.data as List<dynamic>);
    } else {
      return _buildPrimitive(context, widget.data);
    }
  }

  Widget _buildObject(BuildContext context, Map<String, dynamic> map) {
    final count = map.length;
    final l10n = AppLocalizations.of(context);
    final itemsLabel = l10n != null ? l10n.itemsLabel : 'items';
    final theme = Theme.of(context);
    
    return Theme(
      data: theme.copyWith(
        dividerColor: Colors.transparent, 
        iconTheme: theme.iconTheme.copyWith(size: _iconSize, color: theme.colorScheme.onSurface),
        listTileTheme: const ListTileThemeData(
          minLeadingWidth: 20, 
          horizontalTitleGap: 4.0,
          dense: true,
        ),
      ),
      child: ExpansionTile(
        // Include Search Version in Key to force rebuild when auto-expanding
        key: PageStorageKey('${widget.keyName}_${map.hashCode}_${_localControlVersion}_$_searchExpandVersion'),
        initiallyExpanded: _isExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: _tileHPad),
        dense: true,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        shape: const Border(),
        collapsedShape: const Border(),
        expandedAlignment: Alignment.centerLeft,
        childrenPadding: EdgeInsets.zero,
        leading: Icon(Icons.arrow_right),
        controlAffinity: ListTileControlAffinity.leading,
        title: _buildTitle(context, '{', '}', count, itemsLabel),
        onExpansionChanged: (val) {
          setState(() => _isExpanded = val);
        },
        children: [
           Container(
             decoration: BoxDecoration(
               border: Border(left: BorderSide(color: theme.colorScheme.outline, width: 1.0)),
             ),
             margin: const EdgeInsets.only(left: _lineMargin), 
             padding: const EdgeInsets.only(left: 14.5),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: map.entries.map((e) {
                 final newPath = [...widget.currentParamsPath, e.key]; 
                 return JsonTreeView(
                   data: e.value, 
                   keyName: e.key, 
                   searchQuery: widget.searchQuery,
                   isArrayItem: false,
                   currentParamsPath: newPath,
                   activeMatchPath: widget.activeMatchPath,
                   expandAllNotifier: widget.expandAllNotifier,
                 );
               }).toList(),
             ),
           )
        ],
      ),
    );
  }

  Widget _buildArray(BuildContext context, List<dynamic> list) {
    final count = list.length;
    final l10n = AppLocalizations.of(context);
    final itemsLabel = l10n != null ? l10n.itemsLabel : 'items';
    final theme = Theme.of(context);
    
    return Theme(
      data: theme.copyWith(
        dividerColor: Colors.transparent,
        iconTheme: theme.iconTheme.copyWith(size: _iconSize, color: theme.colorScheme.onSurface),
        listTileTheme: const ListTileThemeData(
          minLeadingWidth: 20, 
          horizontalTitleGap: 4.0,
          dense: true,
        ),
      ),
      child: ExpansionTile(
        // Include Search Version in Key to force rebuild when auto-expanding
        key: PageStorageKey('${widget.keyName}_${list.hashCode}_${_localControlVersion}_$_searchExpandVersion'),
        initiallyExpanded: _isExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: _tileHPad),
        dense: true,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        shape: const Border(),
        collapsedShape: const Border(),
        expandedAlignment: Alignment.centerLeft,
        childrenPadding: EdgeInsets.zero,
        leading: Icon(Icons.arrow_right),
        controlAffinity: ListTileControlAffinity.leading,
        title: _buildTitle(context, '[', ']', count, itemsLabel),
        onExpansionChanged: (val) {
           setState(() => _isExpanded = val);
        },
        children: [
           Container(
             decoration: BoxDecoration(
               border: Border(left: BorderSide(color: theme.colorScheme.outline, width: 1.0)),
             ),
             margin: const EdgeInsets.only(left: _lineMargin),
             padding: const EdgeInsets.only(left: 14.5),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: list.asMap().entries.map((e) {
                 final newPath = [...widget.currentParamsPath, e.key];
                 return JsonTreeView(
                   data: e.value, 
                   keyName: e.key.toString(), 
                   searchQuery: widget.searchQuery,
                   isArrayItem: true,
                   currentParamsPath: newPath,
                   activeMatchPath: widget.activeMatchPath,
                   expandAllNotifier: widget.expandAllNotifier,
                 );
               }).toList(),
             ),
           )
        ],
      ),
    );
  }
  
  Widget _buildTitle(BuildContext context, String open, String close, int count, String itemsLabel) {
    final theme = Theme.of(context);
    final isMatch = _checkMatch(widget.keyName);
    final isActive = _isSelfActive();
    
    final highColor = theme.colorScheme.tertiary;
    final highBg = theme.colorScheme.tertiaryContainer;
    
    final activeBg = theme.colorScheme.primaryContainer;
    final activeColor = theme.colorScheme.onPrimaryContainer;

    return RichText(
      text: TextSpan(
        style: TextStyle(fontFamily: 'Courier', fontSize: 13, color: theme.colorScheme.onSurface),
        children: [
          if (widget.keyName != null) 
             TextSpan(
               text: widget.isArrayItem ? '${widget.keyName}: ' : '"${widget.keyName}": ', 
               style: TextStyle(
                 color: isActive ? activeColor : (isMatch 
                   ? theme.colorScheme.onTertiaryContainer 
                   : (widget.isArrayItem ? theme.colorScheme.secondary : Colors.purple[800])), 
                 fontWeight: widget.isArrayItem ? FontWeight.normal : FontWeight.bold,
                 backgroundColor: isActive ? activeBg : (isMatch ? highBg : null),
               )
             ),
          TextSpan(text: open, style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: ' $count $itemsLabel ', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
          TextSpan(text: close, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPrimitive(BuildContext context, dynamic value) {
    Color color;
    String valueStr = value.toString();
    final theme = Theme.of(context);
    final isKeyMatch = _checkMatch(widget.keyName);
    final isValueMatch = _checkMatch(valueStr);
    final isActive = _isSelfActive();
    
    final highBg = theme.colorScheme.tertiaryContainer;
    final highColor = theme.colorScheme.onTertiaryContainer;
    
    final activeBg = theme.colorScheme.primaryContainer;
    final activeColor = theme.colorScheme.onPrimaryContainer;
    
    if (value is String) {
      color = Colors.green[800]!;
      if (theme.brightness == Brightness.dark) color = Colors.greenAccent[400]!;
      valueStr = '"$value"';
    } else if (value is num) {
      color = Colors.blue[800]!;
      if (theme.brightness == Brightness.dark) color = Colors.blueAccent[200]!;
    } else if (value is bool) {
      color = Colors.orange[800]!;
      if (theme.brightness == Brightness.dark) color = Colors.orangeAccent[200]!;
    } else {
      color = theme.colorScheme.onSurface;
    }

    return Theme(
       data: theme.copyWith(
        listTileTheme: const ListTileThemeData(
          minLeadingWidth: 20, 
          horizontalTitleGap: 4.0,
          dense: true,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: _tileHPad),
        dense: true,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        leading: const SizedBox(
           width: 20, 
           height: 20, 
           child: Visibility(
             visible: false, 
             child: Icon(Icons.arrow_right)
           )
        ),
        title: RichText(
          text: TextSpan(
            style: TextStyle(fontFamily: 'Courier', fontSize: 13, color: theme.colorScheme.onSurface),
            children: [
               if (widget.keyName != null) 
                  TextSpan(
                    text: widget.isArrayItem ? '${widget.keyName}: ' : '"${widget.keyName}": ', 
                    style: TextStyle(
                      color: isActive ? activeColor : (isKeyMatch 
                        ? highColor 
                        : (widget.isArrayItem ? theme.colorScheme.secondary : Colors.purple[800])),
                      fontWeight: widget.isArrayItem ? FontWeight.normal : FontWeight.bold,
                      backgroundColor: isActive ? activeBg : (isKeyMatch ? highBg : null),
                    )
                  ),
               TextSpan(
                 text: valueStr, 
                 style: TextStyle(
                   color: isActive ? activeColor : (isValueMatch && !isKeyMatch ? highColor : (widget.data == null ? Colors.grey : color)),
                   backgroundColor: isActive ? activeBg : (isValueMatch ? highBg : null),
                 )
               ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildRow(BuildContext context, String valueStr, Color valueColor, {bool isNull = false}) {
     return _buildPrimitive(context, widget.data);
  }
  
  bool _checkMatch(String? text) {
    if (widget.searchQuery == null || widget.searchQuery!.isEmpty || text == null) return false;
    return text.toLowerCase().contains(widget.searchQuery!.toLowerCase());
  }
}
