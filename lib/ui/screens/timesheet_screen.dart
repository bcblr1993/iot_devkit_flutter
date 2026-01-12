import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../viewmodels/timesheet_provider.dart';
import '../../models/work_log_entry.dart';
import 'package:intl/intl.dart';
import '../../config/timesheet_constants.dart';
import '../widgets/timesheet/weekly_calendar_header.dart'; // Import Custom Header
import '../widgets/timesheet/timesheet_report_view.dart'; // Import Report View
import '../widgets/timesheet/work_log_card.dart'; // Import WorkLogCard
import '../../utils/app_dialog_helper.dart';
import '../../utils/app_toast.dart';

class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key});

  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
  bool _isReportMode = false;
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<TimesheetProvider>(context);
    final theme = Theme.of(context);

    // Format Date: "Mon, Jan 12" -> "1月12日 星期一" (depending on locale)
    final locale = Localizations.localeOf(context).toString();
    final dateStr = DateFormat.MMMMEEEEd(locale).format(provider.selectedDate);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
         children: [
           // Main Toolbar (Global Actions)
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.end,
               children: [
                 // Toggle View Mode
                 SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: false, icon: Icon(Icons.list), label: Text(l10n.tsViewList)),
                      ButtonSegment(value: true, icon: Icon(Icons.analytics), label: Text(l10n.tsViewReport)),
                    ],
                    selected: {_isReportMode},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _isReportMode = newSelection.first;
                      });
                    },
                    style: ButtonStyle(
                       visualDensity: VisualDensity.compact,
                       tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                 ),
               ],
             ),
           ),
           
           Expanded(
             child: _isReportMode 
               ? const TimesheetReportView() 
               : _buildDailyView(context, provider, theme, dateStr, l10n),
           ),
         ],
      ),
    );
  }
  
  // Re-factored Daily View into separate method
  Widget _buildDailyView(
      BuildContext context, 
      TimesheetProvider provider, 
      ThemeData theme, 
      String dateStr, 
      AppLocalizations l10n
  ) {
    return Column(
      children: [
                // Weekly Visual Header
                const WeeklyCalendarHeader(),
                
                // Toolbar (Date Display & Actions)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                     children: [
                       Text(
                         dateStr,
                         style: theme.textTheme.titleMedium?.copyWith(
                           color: theme.colorScheme.primary,
                           fontWeight: FontWeight.bold
                         ),
                       ),
                       const Spacer(),
                       // Export Button
                       OutlinedButton.icon(
                         icon: const Icon(Icons.copy, size: 16),
                         label: Text(l10n.tsWeeklyReport),
                         style: OutlinedButton.styleFrom(
                           visualDensity: VisualDensity.compact,
                         ),
                         onPressed: () async {
                           final report = await provider.generateWeeklyReport(provider.selectedDate);
                           await Clipboard.setData(ClipboardData(text: report));
                           if (mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text(l10n.tsExportHint)),
                             );
                           }
                         },
                       ),
                       const SizedBox(width: 8),
                       // Add Task FAB (Small)
                       FloatingActionButton.small(
                         heroTag: 'add_task',
                         onPressed: () => _showEditDialog(context, null),
                         child: const Icon(Icons.add),
                       ),
                     ],
                  ),
                ),
                
                // Work Log List
                Expanded(
                  child: provider.isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : provider.currentLogs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bedtime_outlined, size: 64, color: theme.colorScheme.outline),
                              const SizedBox(height: 16),
                              Text(l10n.tsNoTasks, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.currentLogs.length,
                          itemBuilder: (context, index) {
                            final log = provider.currentLogs[index];
                            return WorkLogCard(
                              log: log,
                              onEdit: () => _showEditDialog(context, log),
                              onDelete: () => _confirmDelete(context, log),
                            );
                          },
                        ),
                ),
              ],
            );
  }

  void _confirmDelete(BuildContext context, WorkLogEntry log) {
    AppDialogHelper.showConfirm(
      context: context,
      title: AppLocalizations.of(context)!.deleteConfirm,
      message: AppLocalizations.of(context)!.tsDeleteConfirm,
      isDangerous: true,
    ).then((confirmed) {
      if (confirmed == true) {
        Provider.of<TimesheetProvider>(context, listen: false).deleteLog(log);
      }
    });
  }

  void _showEditDialog(BuildContext context, WorkLogEntry? log) {
    final l10n = AppLocalizations.of(context)!;
    AppDialogHelper.show(
      context: context,
      title: log == null ? l10n.tsNewLog : l10n.tsEditLog,
      icon: log == null ? Icons.add_task_rounded : Icons.edit_calendar_rounded,
      content: _LogEditorDialog(log: log, selectedDate: Provider.of<TimesheetProvider>(context, listen: false).selectedDate),
    );
  }
}

class _LogEditorDialog extends StatefulWidget {
  final WorkLogEntry? log;
  final DateTime selectedDate;

  const _LogEditorDialog({this.log, required this.selectedDate});

  @override
  State<_LogEditorDialog> createState() => _LogEditorDialogState();
}

class _LogEditorDialogState extends State<_LogEditorDialog> {
  late TextEditingController _contentCtrl;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  

  
  // Enterprise Standard Fields
  TaskCategoryDefinition? _selectedCategory;
  TaskDefinition? _selectedTask;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(text: widget.log?.content ?? '');
    
    if (widget.log != null) {
      _startTime = TimeOfDay.fromDateTime(widget.log!.startTime);
      _endTime = TimeOfDay.fromDateTime(widget.log!.endTime);
      
      // Attempt to restore selection from code
      if (widget.log!.projectCode != null) {
        for (var cat in TimesheetConstants.categories) {
          for (var task in cat.tasks) {
            if (task.code == widget.log!.projectCode) {
              _selectedCategory = cat;
              _selectedTask = task;
              break;
            }
          }
          if (_selectedTask != null) break;
        }
      }
      
      // Fallback if code lookup failed but category exists (Legacy support)
      if (_selectedCategory == null && widget.log!.category.isNotEmpty) {
         // Try to match category name loosely or just pick first default
         // For now, leave null to force user to re-select compliant standard
      }
    } else {
      // Default: Now -> Now+30m
      final now = TimeOfDay.now();
      _startTime = _roundTime(now);
      _endTime = _addMinute(_startTime, 30);
    }
  }
  
  TimeOfDay _roundTime(TimeOfDay t) {
    int m = t.minute;
    if (m < 15) m = 0;
    else if (m < 45) m = 30;
    else { m = 0; t = _addHour(t);}
    return TimeOfDay(hour: t.hour, minute: m);
  }
  
  TimeOfDay _addHour(TimeOfDay time) {
    int hour = time.hour + 1;
    if (hour > 23) hour = 23;
    return TimeOfDay(hour: hour, minute: time.minute);
  }
  
  TimeOfDay _addMinute(TimeOfDay time, int min) {
    int m = time.minute + min;
    int h = time.hour;
    while (m >= 60) {
      m -= 60;
      h++;
    }
    if (h > 23) h = 0;
    return TimeOfDay(hour: h, minute: m);
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    // Ensure dependencies are imported above
    // Refactoring _LogEditorDialog to return just the content widget
    // The previous implementation returned AlertDialog
    
    return SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<TaskCategoryDefinition>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: l10n.tsTaskCategory, 
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      ),
                      items: TimesheetConstants.categories.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat.name));
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedCategory = v;
                          _selectedTask = null; // Reset task when category changes
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // 2. Task Selector
                    DropdownButtonFormField<TaskDefinition>(
                      value: _selectedTask,
                      decoration: InputDecoration(
                        labelText: l10n.tsStandardTask, 
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      ),
                      items: _selectedCategory?.tasks.map((task) {
                        return DropdownMenuItem(value: task, child: Text(task.name, overflow: TextOverflow.ellipsis));
                      }).toList() ?? [],
                      onChanged: (v) => setState(() => _selectedTask = v),
                      disabledHint: Text(l10n.tsSelectCategoryFirst),
                    ),
                    
                    // 3. Scope Hint (Crucial for compliance)
                    if (_selectedTask != null) 
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text('${l10n.tsTaskCode}${_selectedTask!.code}', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('${l10n.tsGoal}${_selectedTask!.goal}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('${l10n.tsScope}${_selectedTask!.scope}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      
                    const SizedBox(height: 16),
                    
                    // 4. Time
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePicker(l10n.tsStartTime, _startTime, (t) => setState(() => _startTime = t)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTimePicker(l10n.tsEndTime, _endTime, (t) => setState(() => _endTime = t)),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 5. Specific Content
                    TextFormField(
                      controller: _contentCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.tsTaskContent,
                        hintText: 'Specific work details...',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
                const SizedBox(width: 8),
                FilledButton(onPressed: _selectedTask == null ? null : _save, child: Text(l10n.save)),
              ],
            )
        ],
      )
    );
  }


  
  Widget _buildTimePicker(String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context, 
          initialTime: time,
          helpText: 'Select Time (rounded to 30 min)',
        );
        if (picked != null) {
          int minute = picked.minute;
          int hour = picked.hour;
          
          if (minute < 15) { minute = 0; } 
          else if (minute < 45) { minute = 30; } 
          else { minute = 0; hour += 1; if (hour > 23) hour = 0; }
          
          onChanged(TimeOfDay(hour: hour, minute: minute));
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label, 
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        child: Text(time.format(context), style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  void _save() {
    if (_selectedTask == null) return;
    
    final date = widget.selectedDate;
    final startDt = DateTime(date.year, date.month, date.day, _startTime.hour, _startTime.minute);
    final endDt = DateTime(date.year, date.month, date.day, _endTime.hour, _endTime.minute);
    
    // 1. Basic Time Validation
    if (endDt.isBefore(startDt) || endDt.isAtSameMomentAs(startDt)) {
      AppToast.error(context, AppLocalizations.of(context)!.tsTimeError);
      return;
    }
    
    final newLog = WorkLogEntry(
      id: widget.log?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: startDt,
      endTime: endDt,
      category: _selectedCategory?.name ?? 'dev', // Fallback
      content: _contentCtrl.text,
      projectCode: _selectedTask!.code,
      projectId: 'PRJ-001', // Default
    );
    
    // 2. Overlap Validation
    final provider = Provider.of<TimesheetProvider>(context, listen: false);
    if (!provider.validateLog(newLog)) {
      AppToast.error(context, AppLocalizations.of(context)!.tsOverlapError);
      return;
    }

    if (widget.log == null) {
      provider.addLog(newLog);
      AppToast.success(context, AppLocalizations.of(context)!.tsLogAdded);
    } else {
      provider.updateLog(newLog);
      AppToast.success(context, AppLocalizations.of(context)!.tsLogUpdated);
    }
    
    Navigator.pop(context);
  }
}
