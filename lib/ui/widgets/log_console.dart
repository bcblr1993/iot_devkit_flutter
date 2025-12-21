import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

class LogEntry {
  final String message;
  final String type;
  final String time;

  LogEntry(this.message, this.type, this.time);
}

class LogConsole extends StatefulWidget {
  final List<LogEntry> logs;
  final VoidCallback onClear;
  final bool isExpanded;
  final VoidCallback onToggle;

  const LogConsole({
    super.key,
    required this.logs,
    required this.onClear,
    this.isExpanded = true,
    required this.onToggle,
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
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: Theme.of(context).cardColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(logTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
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
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.35 - (_isSearchVisible ? 72 : 40),
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
              ),
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
}
