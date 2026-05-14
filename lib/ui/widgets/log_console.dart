import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  static const _allTypes = 'all';

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _autoScroll = true;
  bool _isSearchVisible = false;
  int _lastLogCount = 0;
  String _activeType = _allTypes;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _lastLogCount = widget.logs.length;
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

  List<LogEntry> get _visibleLogs {
    final query = _searchQuery.trim().toLowerCase();
    return widget.logs.where((log) {
      final matchesType = _activeType == _allTypes || log.type == _activeType;
      if (!matchesType) return false;
      if (query.isEmpty) return true;

      final tag = log.tag ?? '';
      return log.message.toLowerCase().contains(query) ||
          log.time.toLowerCase().contains(query) ||
          tag.toLowerCase().contains(query) ||
          log.type.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  int _typeCount(String type) {
    if (type == _allTypes) return widget.logs.length;
    return widget.logs.where((log) => log.type == type).length;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _copyVisibleLogs() async {
    final content = _visibleLogs.map(_formatLog).join('\n');
    if (content.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _localized(context, zh: '日志已复制到剪贴板', en: 'Logs copied'),
            ),
            duration: const Duration(milliseconds: 1200),
          ),
        );
    }
  }

  String _formatLog(LogEntry log) {
    final tag = log.tag == null ? '' : ' [${log.tag}]';
    return '[${log.time}] [${log.type}]$tag ${log.message}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visibleLogs = _visibleLogs;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.7)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context, l10n, visibleLogs),
          if (widget.isExpanded) ...[
            if (widget.headerContent != null) _buildStatsStrip(context),
            _buildFilterStrip(context),
            if (_isSearchVisible) _buildSearchStrip(context, l10n, visibleLogs),
            Expanded(child: _buildLogBody(context, l10n, visibleLogs)),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations? l10n,
    List<LogEntry> visibleLogs,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final errorCount = _typeCount('error');
    final warningCount = _typeCount('warning');
    final lastLog = widget.logs.isEmpty ? null : widget.logs.last;

    return GestureDetector(
      onTap: widget.isMaximized ? null : widget.onToggle,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.terminal,
                  size: 17,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n?.logs ?? 'Logs',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(
                label: widget.logs.isEmpty
                    ? (l10n?.ready ?? 'Ready')
                    : '${visibleLogs.length}/${widget.logs.length}',
                color: colors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: widget.isExpanded || lastLog == null
                    ? const SizedBox.shrink()
                    : _LastLogPreview(
                        log: lastLog,
                      ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!widget.isExpanded) ...[
                          if (warningCount > 0)
                            _StatusPill(
                              label: 'W $warningCount',
                              color: _typeColor(context, 'warning'),
                            ),
                          if (errorCount > 0) ...[
                            const SizedBox(width: 6),
                            _StatusPill(
                              label: 'E $errorCount',
                              color: colors.error,
                            ),
                          ],
                          const SizedBox(width: 6),
                        ],
                        if (widget.isExpanded) ...[
                          _ToolbarIconButton(
                            icon: _isSearchVisible
                                ? Icons.search_off
                                : Icons.search,
                            tooltip: l10n?.searchHint ?? 'Search',
                            onPressed: () {
                              setState(() {
                                _isSearchVisible = !_isSearchVisible;
                                if (!_isSearchVisible) {
                                  _searchQuery = '';
                                  _searchController.clear();
                                }
                              });
                            },
                          ),
                          _ToolbarIconButton(
                            icon: _autoScroll
                                ? Icons.vertical_align_bottom
                                : Icons.pause_circle_outline,
                            tooltip: _autoScroll
                                ? (l10n?.autoScrollOn ?? 'Auto-scroll ON')
                                : (l10n?.autoScrollOff ?? 'Auto-scroll OFF'),
                            isActive: _autoScroll,
                            onPressed: () {
                              setState(() => _autoScroll = !_autoScroll);
                              if (_autoScroll) _scrollToBottom();
                            },
                          ),
                          _ToolbarIconButton(
                            icon: Icons.copy_all,
                            tooltip: _localized(context,
                                zh: '复制日志', en: 'Copy logs'),
                            onPressed: _copyVisibleLogs,
                          ),
                          _ToolbarIconButton(
                            icon: Icons.delete_sweep,
                            tooltip: l10n?.clearLogs ?? 'Clear Logs',
                            onPressed: widget.onClear,
                          ),
                          _ToolbarIconButton(
                            icon: widget.isMaximized
                                ? Icons.close_fullscreen
                                : Icons.open_in_full,
                            tooltip: widget.isMaximized
                                ? (l10n?.logRestore ?? 'Restore Logs')
                                : (l10n?.logMaximize ?? 'Maximize Logs'),
                            onPressed: widget.onMaximize,
                          ),
                        ],
                        if (!widget.isMaximized)
                          _ToolbarIconButton(
                            icon: widget.isExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            tooltip: widget.isExpanded
                                ? (l10n?.collapseLogs ?? 'Collapse Logs')
                                : (l10n?.expandLogs ?? 'Expand Logs'),
                            emphasized: !widget.isExpanded,
                            onPressed: widget.onToggle,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsStrip(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 40,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.74),
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.45)),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ClipRect(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: widget.headerContent!,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterStrip(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final items = <(String, IconData, String)>[
      (_allTypes, Icons.all_inbox, isZh ? '全部' : 'All'),
      ('info', Icons.info_outline, isZh ? '信息' : 'Info'),
      ('success', Icons.check_circle_outline, isZh ? '成功' : 'Success'),
      ('warning', Icons.warning_amber_rounded, isZh ? '警告' : 'Warning'),
      ('error', Icons.error_outline, isZh ? '错误' : 'Error'),
    ];

    return Container(
      height: 46,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.35)),
          bottom:
              BorderSide(color: colors.outlineVariant.withValues(alpha: 0.45)),
        ),
      ),
      child: ClipRect(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in items) ...[
                _LogFilterButton(
                  icon: item.$2,
                  label: item.$3,
                  count: _typeCount(item.$1),
                  color: item.$1 == _allTypes
                      ? colors.primary
                      : _typeColor(context, item.$1),
                  selected: _activeType == item.$1,
                  onPressed: () => setState(() => _activeType = item.$1),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchStrip(
    BuildContext context,
    AppLocalizations? l10n,
    List<LogEntry> visibleLogs,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      height: 44,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.55),
        border: Border(
          bottom:
              BorderSide(color: colors.outlineVariant.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: l10n?.searchHint ?? 'Search...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: colors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.outlineVariant),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(width: 10),
          _StatusPill(
            label: '${visibleLogs.length}/${widget.logs.length}',
            color: colors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildLogBody(
    BuildContext context,
    AppLocalizations? l10n,
    List<LogEntry> visibleLogs,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (visibleLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _searchQuery.isEmpty && _activeType == _allTypes
                  ? Icons.receipt_long_outlined
                  : Icons.filter_alt_off_outlined,
              color: colors.onSurfaceVariant.withValues(alpha: 0.72),
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isEmpty && _activeType == _allTypes
                  ? (l10n?.ready ?? 'Ready')
                  : _localized(context, zh: '没有匹配日志', en: 'No matching logs'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
      ),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        itemCount: visibleLogs.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 1,
          color: colors.outlineVariant.withValues(alpha: 0.22),
        ),
        itemBuilder: (context, index) {
          final log = visibleLogs[index];
          return _LogLine(
            log: log,
            query: _searchQuery,
            messageColor: _typeColor(context, log.type),
            tagColor: _tagColor(context, log.tag ?? ''),
          );
        },
      ),
    );
  }

  List<TextSpan> _highlightedText(String text, String query, Color baseColor) {
    final baseStyle = TextStyle(
      color: baseColor,
      fontSize: 12,
      fontFamily: 'Courier',
      height: 1.3,
      fontWeight: FontWeight.w600,
    );

    if (query.trim().isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.trim().toLowerCase();
    var start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) break;
      if (index > start) {
        spans.add(
            TextSpan(text: text.substring(start, index), style: baseStyle));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + lowerQuery.length),
          style: baseStyle.copyWith(
            color: Colors.black,
            backgroundColor: Colors.amberAccent,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
      start = index + lowerQuery.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return spans.isEmpty ? [TextSpan(text: text, style: baseStyle)] : spans;
  }

  Color _typeColor(BuildContext context, String type) {
    final colors = Theme.of(context).colorScheme;
    switch (type) {
      case 'error':
        return colors.error;
      case 'warning':
        return Colors.orange.shade700;
      case 'success':
        return Colors.green.shade600;
      case 'info':
        return colors.primary;
      default:
        return colors.onSurface;
    }
  }

  Color _tagColor(BuildContext context, String tag) {
    if (tag.isEmpty) return Theme.of(context).colorScheme.onSurfaceVariant;
    final hash = tag.hashCode;
    final r = (hash & 0xFF0000) >> 16;
    final g = (hash & 0x00FF00) >> 8;
    final b = hash & 0x0000FF;
    final brightness = Theme.of(context).brightness;
    final offset = brightness == Brightness.dark ? 132 : 72;
    final range = brightness == Brightness.dark ? 124 : 112;
    return Color.fromARGB(
      255,
      offset + (r % range),
      offset + (g % range),
      offset + (b % range),
    );
  }

  String _localized(
    BuildContext context, {
    required String zh,
    required String en,
  }) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }
}

class _LastLogPreview extends StatelessWidget {
  final LogEntry? log;

  const _LastLogPreview({
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Text(
          log!.time,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            log!.message,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LogLine extends StatelessWidget {
  final LogEntry log;
  final String query;
  final Color messageColor;
  final Color tagColor;

  const _LogLine({
    required this.log,
    required this.query,
    required this.messageColor,
    required this.tagColor,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_LogConsoleState>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              log.time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                fontFamily: 'Courier',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _LogLevelBadge(type: log.type, color: messageColor),
          if (log.tag != null) ...[
            const SizedBox(width: 10),
            Flexible(
              flex: 0,
              child: Text(
                log.tag!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tagColor,
                  fontSize: 12,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: state?._highlightedText(
                      log.message,
                      query,
                      messageColor,
                    ) ??
                    [TextSpan(text: log.message)],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogLevelBadge extends StatelessWidget {
  final String type;
  final Color color;

  const _LogLevelBadge({
    required this.type,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        type.toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _LogFilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  const _LogFilterButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: selected ? color : colors.onSurfaceVariant,
        backgroundColor: selected ? color.withValues(alpha: 0.1) : null,
        side: BorderSide(
          color: selected
              ? color.withValues(alpha: 0.6)
              : colors.outlineVariant.withValues(alpha: 0.8),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(
        '$label $count',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool emphasized;
  final bool isActive;

  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.emphasized = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = emphasized || isActive;

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: IconButton(
          iconSize: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          style: IconButton.styleFrom(
            backgroundColor:
                active ? colors.primary.withValues(alpha: 0.12) : null,
            foregroundColor: active ? colors.primary : colors.onSurfaceVariant,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: Icon(icon),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
