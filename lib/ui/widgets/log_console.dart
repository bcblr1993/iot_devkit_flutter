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
  bool _autoScroll = true;
  int _lastLogCount = 0;

  @override
  void initState() {
    super.initState();
    _lastLogCount = widget.logs.length;
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
              Row(
                children: [
                   IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: AnimatedRotation(
                      turns: widget.isExpanded ? 0 : -0.25, // Point down when expanded, right when collapsed
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                    onPressed: widget.onToggle,
                    tooltip: widget.isExpanded ? collapseTooltip : expandTooltip,
                  ),
                  const SizedBox(width: 8),
                  Text(logTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: widget.isExpanded
                    ? Row(
                        key: const ValueKey('expanded-actions'),
                        children: [
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
                          const SizedBox(width: 8),
                          IconButton(
                            iconSize: 18,
                            icon: const Icon(Icons.delete_sweep),
                            onPressed: widget.onClear,
                            tooltip: clear,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(key: ValueKey('collapsed-actions')),
              ),
            ],
          ),
        ),
        if (widget.isExpanded)
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(), // Only used to swallow overflow during animation
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.35 - 40,
                child: Column(
                  children: [
                    const Divider(height: 1),
                    Expanded(
                      child: Container(
                        color: Colors.black87,
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: widget.logs.length,
                          itemBuilder: (context, index) {
                            final log = widget.logs[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              child: SelectableText.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '[${log.time}] ',
                                      style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Courier'),
                                    ),
                                    TextSpan(
                                      text: '${log.message}\n',
                                      style: TextStyle(
                                        color: _getColor(log.type),
                                        fontSize: 13,
                                        fontFamily: 'Courier',
                                      ),
                                    ),
                                  ],
                                ),
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
