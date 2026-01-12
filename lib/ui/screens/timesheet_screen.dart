import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../viewmodels/timesheet_provider.dart';
import '../../models/work_log_entry.dart';
import 'package:intl/intl.dart';
import '../../config/timesheet_constants.dart';

class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key});

  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<TimesheetProvider>(context);
    final theme = Theme.of(context);

    // Format Date: "Mon, Jan 12"
    final dateStr = DateFormat.MMMMEEEEd().format(provider.selectedDate);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          // Sidebar: Calendar / Date Picker (Simplified to a vertical list of days for now or just a date picker button in header)
          // For now, let's keep it simple: Single column layout with Header.
          Expanded(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: provider.selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            provider.selectDate(picked);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateStr,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        icon: const Icon(Icons.copy),
                        label: Text(l10n.tsWeeklyReport),
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
                      FloatingActionButton.small(
                        heroTag: 'add_task',
                        onPressed: () => _showEditDialog(context, null),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                
                // Content
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
                              return _buildLogCard(context, log);
                            },
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, WorkLogEntry log) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final start = DateFormat.Hm().format(log.startTime);
    final end = DateFormat.Hm().format(log.endTime);
    final duration = log.durationHours.toStringAsFixed(1);

    Color catColor = theme.colorScheme.primary;
    String catLabel = log.category;
    
    // Map category to color/label
    if (log.category == 'dev') { catColor = Colors.blue; catLabel = l10n.tsCatDev; }
    else if (log.category == 'meeting') { catColor = Colors.orange; catLabel = l10n.tsCatMeeting; }
    else if (log.category == 'review') { catColor = Colors.purple; catLabel = l10n.tsCatReview; }
    else { catColor = Colors.grey; catLabel = l10n.tsCatOther; }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showEditDialog(context, log),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Time Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Text(start, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Container(height: 12, width: 1, color: theme.colorScheme.outlineVariant, margin: const EdgeInsets.symmetric(vertical: 2)),
                    Text(end, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Row(
                       children: [
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                           decoration: BoxDecoration(
                             color: catColor.withOpacity(0.1),
                             borderRadius: BorderRadius.circular(4),
                           ),
                           child: Text(catLabel, style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.bold)),
                         ),
                         const SizedBox(width: 8),
                         Text('${duration}h', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                       ],
                     ),
                     const SizedBox(height: 4),
                     Text(log.content, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              
              // Actions
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => _confirmDelete(context, log),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WorkLogEntry log) {
    // Show confirm dialog
     final l10n = AppLocalizations.of(context)!;
     showDialog(context: context, builder: (ctx) => AlertDialog(
       title: Text(l10n.deleteConfirm),
       content: Text(l10n.tsDeleteConfirm),
       actions: [
         TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
         TextButton(onPressed: () {
            Navigator.pop(ctx);
            Provider.of<TimesheetProvider>(context, listen: false).deleteLog(log);
         }, child: Text(l10n.deleteProfile, style: TextStyle(color: Theme.of(context).colorScheme.error))),
       ],
     ));
  }

  void _showEditDialog(BuildContext context, WorkLogEntry? log) {
    showDialog(
      context: context,
      builder: (context) => _LogEditorDialog(log: log, selectedDate: Provider.of<TimesheetProvider>(context, listen: false).selectedDate),
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
    
    return AlertDialog(
      title: Text(widget.log == null ? 'New Work Log' : 'Edit Work Log'),
      content: SizedBox(
        width: 500, // Wider for scope text
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Category Selector
              DropdownButtonFormField<TaskCategoryDefinition>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Task Category (任务类型)', border: OutlineInputBorder()),
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
                decoration: const InputDecoration(labelText: 'Standard Task (标准任务)', border: OutlineInputBorder()),
                items: _selectedCategory?.tasks.map((task) {
                  return DropdownMenuItem(value: task, child: Text(task.name, overflow: TextOverflow.ellipsis));
                }).toList() ?? [],
                onChanged: (v) => setState(() => _selectedTask = v),
                disabledHint: const Text('Select a category first'),
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
                          Text('Task Code: ${_selectedTask!.code}', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Goal: ${_selectedTask!.goal}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Scope: ${_selectedTask!.scope}', style: const TextStyle(fontSize: 12)),
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
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _selectedTask == null ? null : _save, child: Text(l10n.save)), // Validated
      ],
    );
  }
  
  Widget _buildTimePicker(String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
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
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(time.format(context), style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  void _save() {
    if (_selectedTask == null) return;
    
    final date = widget.selectedDate;
    final startDt = DateTime(date.year, date.month, date.day, _startTime.hour, _startTime.minute);
    final endDt = DateTime(date.year, date.month, date.day, _endTime.hour, _endTime.minute);
    
    final newLog = WorkLogEntry(
      id: widget.log?.id,
      startTime: startDt,
      endTime: endDt,
      content: _contentCtrl.text,
      category: _selectedCategory?.name ?? 'Other', // Store category name
      projectCode: _selectedTask?.code,
      taskName: _selectedTask?.name,
      taskScope: _selectedTask?.scope,
    );
    
    if (widget.log == null) {
      Provider.of<TimesheetProvider>(context, listen: false).addLog(newLog);
    } else {
       Provider.of<TimesheetProvider>(context, listen: false).updateLog(newLog);
    }
    
    Navigator.pop(context);
  }
}
