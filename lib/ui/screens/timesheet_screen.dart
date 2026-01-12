import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../viewmodels/timesheet_provider.dart';
import '../../models/work_log_entry.dart';
import 'package:intl/intl.dart';

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
  late String _category;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(text: widget.log?.content ?? '');
    
    if (widget.log != null) {
      _startTime = TimeOfDay.fromDateTime(widget.log!.startTime);
      _endTime = TimeOfDay.fromDateTime(widget.log!.endTime);
      _category = widget.log!.category;
    } else {
      // Default: Now -> Now+1h
      final now = TimeOfDay.now();
      _startTime = now;
      _endTime = _addHour(now);
      _category = 'dev';
    }
  }
  
  TimeOfDay _addHour(TimeOfDay time) {
    int hour = time.hour + 1;
    if (hour > 23) hour = 23;
    return TimeOfDay(hour: hour, minute: time.minute);
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AlertDialog(
      title: Text(widget.log == null ? l10n.tsDailyLog : l10n.tsDailyLog), // Reuse title "Daily Log" or "Edit Task"
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _contentCtrl,
              decoration: InputDecoration(
                labelText: l10n.tsTaskContent,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
            const SizedBox(height: 16),
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
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(labelText: l10n.tsCategory, border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: 'dev', child: Text(l10n.tsCatDev)),
                DropdownMenuItem(value: 'meeting', child: Text(l10n.tsCatMeeting)),
                DropdownMenuItem(value: 'review', child: Text(l10n.tsCatReview)),
                DropdownMenuItem(value: 'other', child: Text(l10n.tsCatOther)),
              ],
              onChanged: (v) => setState(() => _category = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
  
  Widget _buildTimePicker(String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(time.format(context), style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  void _save() {
    // Convert TimeOfDay to DateTime on the selected date
    final date = widget.selectedDate;
    final startDt = DateTime(date.year, date.month, date.day, _startTime.hour, _startTime.minute);
    final endDt = DateTime(date.year, date.month, date.day, _endTime.hour, _endTime.minute);
    
    // Validate end > start? Not strictly required but good UX.
    
    final newLog = WorkLogEntry(
      id: widget.log?.id, // Keeps ID if editing
      startTime: startDt,
      endTime: endDt,
      content: _contentCtrl.text,
      category: _category,
    );
    
    if (widget.log == null) {
      Provider.of<TimesheetProvider>(context, listen: false).addLog(newLog);
    } else {
       Provider.of<TimesheetProvider>(context, listen: false).updateLog(newLog);
    }
    
    Navigator.pop(context);
  }
}
