import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/work_log_entry.dart';
import '../../../viewmodels/timesheet_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'work_log_card.dart';

class TimesheetReportView extends StatefulWidget {
  const TimesheetReportView({super.key});

  @override
  State<TimesheetReportView> createState() => _TimesheetReportViewState();
}

class _TimesheetReportViewState extends State<TimesheetReportView> {
  DateTimeRange? _selectedRange;
  Map<DateTime, List<WorkLogEntry>> _groupedLogs = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default to This Week
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    _selectedRange = DateTimeRange(start: startOfWeek, end: endOfWeek);
    _loadData();
  }

  Future<void> _loadData() async {
    if (_selectedRange == null) return;
    
    setState(() => _isLoading = true);
    final provider = Provider.of<TimesheetProvider>(context, listen: false);
    
    // Ensure end date includes the full day (23:59:59)
    final end = DateTime(_selectedRange!.end.year, _selectedRange!.end.month, _selectedRange!.end.day, 23, 59, 59);
    final logs = await provider.getLogsInRange(_selectedRange!.start, end);
    
    // Group logs by Date (Day precision)
    final Map<DateTime, List<WorkLogEntry>> grouped = {};
    for (var log in logs) {
      final date = DateTime(log.startTime.year, log.startTime.month, log.startTime.day);
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(log);
    }

    if (mounted) {
      setState(() {
        _groupedLogs = grouped;
        _isLoading = false;
      });
    }
  }

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _selectedRange,
      locale: Localizations.localeOf(context),
    );
    if (picked != null) {
      setState(() {
        _selectedRange = picked;
      });
      _loadData();
    }
  }

  void _onEditorCallback() {
      // Reload specific day logic if needed, but for simplicity reloading all range
      _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    // Convert map to sorted list of entries
    final sortedDates = _groupedLogs.keys.toList()
      ..sort((a, b) => a.compareTo(b)); // Ascending order (Mon -> Sun)

    return Column(
      children: [
        // 1. Filter Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
               Icon(Icons.date_range, color: theme.colorScheme.primary),
               const SizedBox(width: 8),
               if (_selectedRange != null)
               Expanded(
                 child: Text(
                   "${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(_selectedRange!.start)} - ${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(_selectedRange!.end)}",
                   style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                   overflow: TextOverflow.ellipsis,
                 ),
               ),
               const SizedBox(width: 16),
               TextButton.icon(
                 icon: const Icon(Icons.edit_calendar, size: 16),
                 onPressed: _pickDateRange, 
                 label: Text(l10n.tsSelectRange)
               ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 2. Grouped List
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : sortedDates.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_view_week, size: 64, color: theme.colorScheme.surfaceContainerHighest),
                      const SizedBox(height: 16),
                      Text(l10n.tsNoRecords, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.secondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedDates.length,
                  itemBuilder: (context, index) {
                    final date = sortedDates[index];
                    final dayLogs = _groupedLogs[date]!..sort((a,b) => a.startTime.compareTo(b.startTime));
                    final dailyTotal = dayLogs.fold(0.0, (sum, log) => sum + log.durationHours);
                    final isToday = DateUtils.isSameDay(date, DateTime.now());

                    // Logic for Overtime and Undertime
                    double regularHours = dailyTotal;
                    double overtimeHours = 0;
                    bool isOvertime = dailyTotal > 8.0;
                    bool isLowParams = dailyTotal < 8.0 && !isToday && dailyTotal > 0; // Don't warn for today or empty days (usually empty days are filtered or just 0)
                    
                    if (isOvertime) {
                      regularHours = 8.0;
                      overtimeHours = dailyTotal - 8.0;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      color: isToday ? theme.colorScheme.primaryContainer.withValues(alpha: 0.1) : theme.colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: ExpansionTile(
                         initiallyExpanded: true,
                         shape: const Border(), // Remove internal borders
                         collapsedShape: const Border(),
                         tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                         leading: Container(
                           padding: const EdgeInsets.all(8),
                           decoration: BoxDecoration(
                             color: isLowParams ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer,
                             borderRadius: BorderRadius.circular(8),
                           ),
                           child: Text(
                             DateFormat.d().format(date),
                             style: TextStyle(
                               fontWeight: FontWeight.bold, 
                               color: isLowParams ? theme.colorScheme.onErrorContainer : theme.colorScheme.onPrimaryContainer
                             ),
                           ),
                         ),
                         title: Text(
                           DateFormat.MMMMEEEEd(Localizations.localeOf(context).toString()).format(date),
                           style: const TextStyle(fontWeight: FontWeight.bold),
                         ),
                         subtitle: isLowParams 
                            ? Row(children: [
                                Icon(Icons.warning_amber_rounded, size: 14, color: theme.colorScheme.error),
                                const SizedBox(width: 4),
                                Text(l10n.tsLowHours, style: TextStyle(color: theme.colorScheme.error, fontSize: 12))
                              ])
                            : null,
                         trailing: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Column(
                               mainAxisAlignment: MainAxisAlignment.center,
                               crossAxisAlignment: CrossAxisAlignment.end,
                               children: [
                                 Text(
                                   "${dailyTotal.toStringAsFixed(1)}h",
                                   style: TextStyle(
                                     fontWeight: FontWeight.w900, 
                                     fontSize: 16, 
                                     color: isOvertime ? Colors.green : (isLowParams ? theme.colorScheme.error : theme.colorScheme.primary)
                                   ),
                                 ),
                                 if (isOvertime)
                                  Text(
                                    "${l10n.tsOvertime}: +${overtimeHours.toStringAsFixed(1)}h",
                                    style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                               ],
                             ),
                             const SizedBox(width: 8),
                             Icon(Icons.expand_more, color: theme.colorScheme.secondary),
                           ],
                         ),
                         children: [
                           Divider(height: 1, indent: 16, endIndent: 16, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
                           Padding(
                             padding: const EdgeInsets.all(12.0),
                             child: Column(
                               children: dayLogs.map((log) => WorkLogCard(
                                 log: log,
                                 // Note: Editing here might be tricky if we don't have access to the full edit dialog logic
                                 // But usually we can expect the Provider or Parent to handle it, or we duplicate.
                                 // Since we are in a sub-widget, we need to pass the edit action or duplicate it.
                                 // For now, let's just leave onEdit empty or implement a simple edit callback if possible
                                 // Actually, WorkLogCard expects a callback.
                                 // We don't have the _showEditDialog here easily unless we lift it up or duplicate.
                                 // Let's assume for now read-only or we simply don't pass the callback.
                                 // User requirement: "List records... collapse". Didn't explicitly ask for edit support in this view, 
                                 // but it's implied for a "Timesheet".
                                 // I'll leave callbacks null for safety for this iteration OR import the dialog if it's public.
                                 // _showEditDialog in TimesheetScreen is private.
                                 // I should probably move _showEditDialog to a mixin or public utility, or just not support edit in this view yet.
                                 // Safe bet: No edit in this view for this specific turn, to avoid complex refactoring.
                                 // Wait, user provided an image of a list. Typically lists are editable.
                                 // I will leave them null and maybe add a TODO or a simple note. 
                                 // actually, let's keep it read-only to avoid breaking things, as the user specific request was "Display...".
                                 onEdit: null,
                                 onDelete: null, 
                               )).toList(),
                             ),
                           )
                         ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
