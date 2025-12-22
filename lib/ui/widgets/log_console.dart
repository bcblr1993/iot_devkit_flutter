import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

class LogEntry {
  final String message;
  final String type;
  final String time;
  final String? tag;

  LogEntry(this.message, this.type, this.time, {this.tag});
}

class LogConsole extends StatefulWidget {
  final List<LogEntry> logs;
  final VoidCallback onClear;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool isMaximized;
  final VoidCallback onMaximize;

  final Widget? headerContent;

  const LogConsole({
    super.key,
    required this.logs,
    required this.onClear,
    this.isExpanded = true,
    required this.onToggle,
    this.isMaximized = false,
    required this.onMaximize,
    this.headerContent,
  });

  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _autoScroll = true;
  int _lastLogCount = 0;
  String _searchQuery = '';
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _lastLogCount = widget.logs.length;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LogConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll && widget.logs.length > _lastLogCount) {
      _scrollToBottom();
    }
    _lastLogCount = widget.logs.length;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  List<LogEntry> get _filteredLogs {
    if (_searchQuery.isEmpty) return widget.logs;
    return widget.logs.where((log) => 
      log.message.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      log.time.contains(_searchQuery)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    // Fallback if context not valid yet (should denote execute anyway)
    final logTitle = l10n?.logs ?? 'Logs';
    final autoScrollOn = l10n?.autoScrollOn ?? 'Auto-scroll ON';
    final autoScrollOff = l10n?.autoScrollOff ?? 'Auto-scroll OFF';
    final clear = l10n?.clearLogs ?? 'Clear Logs';
    final expandTooltip = l10n?.expandLogs ?? 'Expand Logs';
    final collapseTooltip = l10n?.collapseLogs ?? 'Collapse Logs';

    return Column(
      children: [
        // Toolbar
        GestureDetector(
          onTap: widget.onToggle,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(logTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (widget.headerContent != null) ...[
                      const SizedBox(width: 12),
                      Container(
                        width: 1, 
                        height: 16, 
                        color: Theme.of(context).dividerColor
                      ),
                      const SizedBox(width: 12),
                      widget.headerContent!,
                    ],
                  ],
                ),
                Row(
                  children: [
                    if (widget.isExpanded) ...[
                      // Search toggle
                      IconButton(
                        iconSize: 18,
                        icon: Icon(_isSearchVisible ? Icons.search_off : Icons.search),
                        onPressed: () {
                          setState(() {
                            _isSearchVisible = !_isSearchVisible;
                            if (!_isSearchVisible) {
                              _searchQuery = '';
                              _searchController.clear();
                            }
                          });
                        },
                        tooltip: 'Search',
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          setState(() {
                            _autoScroll = !_autoScroll;
                            if (_autoScroll) _scrollToBottom();
                          });
                        },
                        icon: Icon(_autoScroll ? Icons.lock_clock : Icons.lock_open, size: 16),
                        label: Text(_autoScroll ? autoScrollOn : autoScrollOff, style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        iconSize: 18,
                        icon: const Icon(Icons.delete_sweep),
                        onPressed: widget.onClear,
                        tooltip: clear,
                      ),
                      const SizedBox(width: 4),
                      const SizedBox(width: 4),
                      IconButton(
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(widget.isMaximized ? Icons.close_fullscreen : Icons.open_in_full),
                        onPressed: widget.onMaximize,
                        tooltip: widget.isMaximized 
                            ? (l10n?.logRestore ?? 'Restore Logs') 
                            : (l10n?.logMaximize ?? 'Maximize Logs'),
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: AnimatedRotation(
                        turns: widget.isExpanded ? 0 : -0.25,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down),
                      ),
                      onPressed: widget.onToggle,
                      tooltip: widget.isExpanded ? collapseTooltip : expandTooltip,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Search input row
        if (widget.isExpanded && _isSearchVisible)
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: l10n?.searchHint ?? 'Search...',
                      hintStyle: const TextStyle(fontSize: 12),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${_filteredLogs.length}/${widget.logs.length}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        if (widget.isExpanded)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Prevent overflow during animation when constraints.maxHeight is very small
                if (constraints.maxHeight < 20) return const SizedBox.shrink();
                
                return ClipRect(
                  child: Column(
                    children: [
                      const Divider(height: 1),
                      Expanded(
                        child: Container(
                          color: Colors.black87,
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _filteredLogs.length,
                            itemBuilder: (context, index) {
                              final log = _filteredLogs[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '[${log.time}] ',
                                        style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'Courier', height: 1.2),
                                      ),
                                      if (log.tag != null)
                                        TextSpan(
                                          text: '[${log.tag}] ',
                                          style: TextStyle(
                                              color: _getHashColor(log.tag!),
                                              fontSize: 11,
                                              fontFamily: 'Courier',
                                              fontWeight: FontWeight.bold,
                                              height: 1.2),
                                        ),
                                      ..._buildHighlightedText(log.message, _searchQuery, _getColor(log.type)),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  List<TextSpan> _buildHighlightedText(String text, String query, Color baseColor) {
    if (query.isEmpty) {
      return [TextSpan(text: text, style: TextStyle(color: baseColor, fontSize: 11, fontFamily: 'Courier', height: 1.2))];
    }
    
    final List<TextSpan> spans = [];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;
    int index;
    
    while ((index = lowerText.indexOf(lowerQuery, start)) != -1) {
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: TextStyle(color: baseColor, fontSize: 11, fontFamily: 'Courier', height: 1.2)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(color: Colors.black, backgroundColor: Colors.yellow, fontSize: 11, fontFamily: 'Courier', height: 1.2, fontWeight: FontWeight.bold),
      ));
      start = index + query.length;
    }
    
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: TextStyle(color: baseColor, fontSize: 11, fontFamily: 'Courier', height: 1.2)));
    }
    
    return spans.isEmpty ? [TextSpan(text: text, style: TextStyle(color: baseColor, fontSize: 11, fontFamily: 'Courier', height: 1.2))] : spans;
  }

  Color _getColor(String type) {
    switch (type) {
      case 'info': return Colors.greenAccent;
      case 'error': return Colors.redAccent;
      case 'warning': return Colors.orangeAccent;
      case 'success': return Colors.lightBlueAccent;
      default: return Colors.white;
    }
  }

  Color _getHashColor(String tag) {
    final int hash = tag.hashCode;
    final int r = (hash & 0xFF0000) >> 16;
    final int g = (hash & 0x00FF00) >> 8;
    final int b = (hash & 0x0000FF);
    // Ensure high brightness for dark background (150-255 range)
    return Color.fromARGB(255, 150 + (r % 106), 150 + (g % 106), 150 + (b % 106));
  }
}
