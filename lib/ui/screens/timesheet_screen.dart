import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/work_log_entry.dart';
import '../../viewmodels/timesheet_provider.dart';
import '../components/app_empty_state.dart';
import '../lab/lab.dart';

class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key});

  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _hoursController =
      TextEditingController(text: '1');

  WorkLogEntry? _editingLog;
  Timer? _feedbackTimer;
  String? _feedbackMessage;
  bool _feedbackIsError = false;

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _contentController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimesheetProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context, provider),
                  const SizedBox(height: 12),
                  _buildQuickEditor(context, provider),
                  const SizedBox(height: 12),
                  if (provider.isLoading)
                    Padding(
                      padding: const EdgeInsets.all(48),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )
                  else
                    _buildDailyLogs(context, provider),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TimesheetProvider provider) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final selectedDate = provider.selectedDate;
    final isToday = _isSameDay(selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final title = Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit_note, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.toolTimesheet,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dateLabel(context, selectedDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              _TotalHoursPill(hours: provider.totalHours),
              IconButton.outlined(
                tooltip: _t(context, zh: '前一天', en: 'Previous day'),
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _selectDate(
                  context,
                  provider.selectedDate.subtract(const Duration(days: 1)),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(isToday
                    ? _t(context, zh: '今天', en: 'Today')
                    : DateFormat('MM-dd').format(selectedDate)),
                onPressed: () => _pickDate(context, provider),
              ),
              IconButton.outlined(
                tooltip: _t(context, zh: '后一天', en: 'Next day'),
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _selectDate(
                  context,
                  provider.selectedDate.add(const Duration(days: 1)),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_all, size: 18),
                label: Text(l10n.tsCopyReport),
                onPressed: () => _copyWeeklyReport(context, provider),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 12),
                actions,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              Flexible(child: actions),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickEditor(BuildContext context, TimesheetProvider provider) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isEditing = _editingLog != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEditing
                      ? _t(context, zh: '编辑这条记录', en: 'Edit entry')
                      : _t(context, zh: '今天做了什么', en: 'What did you do today'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isEditing)
                TextButton.icon(
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(l10n.cancel),
                  onPressed: _resetEditor,
                ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: _feedbackMessage == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _InlineFeedback(
                      message: _feedbackMessage!,
                      isError: _feedbackIsError,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          LabField(
            controller: _contentController,
            label: l10n.tsTaskContent,
            minLines: 4,
            maxLines: 8,
            hintText: _t(
              context,
              zh: '例如：修复设备数据上送停止卡住问题；优化日志控制台布局',
              en: 'Example: fixed upload stop issue; refined log console',
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final hoursField = LabField(
                controller: _hoursController,
                label: _t(context, zh: '几个小时', en: 'Hours'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              );
              final saveButton = FilledButton.icon(
                icon: Icon(isEditing ? Icons.check : Icons.add),
                label: Text(
                    isEditing ? l10n.save : _t(context, zh: '记一笔', en: 'Add')),
                onPressed: () => _saveEntry(context, provider),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    hoursField,
                    const SizedBox(height: 10),
                    SizedBox(height: 44, child: saveButton),
                  ],
                );
              }

              return Row(
                children: [
                  SizedBox(width: 180, child: hoursField),
                  const Spacer(),
                  SizedBox(width: 150, height: 44, child: saveButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDailyLogs(BuildContext context, TimesheetProvider provider) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final logs = provider.currentLogs;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t(context, zh: '当天记录', en: 'Daily entries'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _t(
                  context,
                  zh: '${logs.length} 条 / ${_formatHours(provider.totalHours)} 小时',
                  en: '${logs.length} entries / ${_formatHours(provider.totalHours)} h',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 42),
              child: AppEmptyState(
                icon: Icons.note_add_outlined,
                message: l10n.tsNoTasks,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _buildLogItem(context, logs[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLogItem(BuildContext context, WorkLogEntry log) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerLow.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _startEdit(log),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatHours(log.durationHours),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      _t(context, zh: '小时', en: 'hours'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  log.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _t(context, zh: '编辑', en: 'Edit'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _startEdit(log),
              ),
              IconButton(
                tooltip: _t(context, zh: '删除', en: 'Delete'),
                icon: Icon(Icons.delete_outline, size: 18, color: colors.error),
                onPressed: () => _confirmDelete(context, log),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration(BuildContext context) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.035),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    TimesheetProvider provider,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (!context.mounted || picked == null) return;
    _selectDate(context, picked);
  }

  void _selectDate(BuildContext context, DateTime date) {
    _resetEditor();
    context.read<TimesheetProvider>().selectDate(date);
  }

  Future<void> _copyWeeklyReport(
    BuildContext context,
    TimesheetProvider provider,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final report = await provider.generateWeeklyReport(provider.selectedDate);
    await Clipboard.setData(ClipboardData(text: report));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.tsExportHint)));
  }

  Future<void> _saveEntry(
    BuildContext context,
    TimesheetProvider provider,
  ) async {
    final content = _contentController.text.trim();
    final hours =
        double.tryParse(_hoursController.text.trim().replaceAll(',', '.')) ?? 0;

    if (content.isEmpty) {
      _showMessage(
        context,
        _t(context, zh: '先写一下今天干了什么', en: 'Add a note first'),
        isError: true,
      );
      return;
    }

    if (hours <= 0 || hours > 24) {
      _showMessage(
        context,
        _t(
          context,
          zh: '小时数需要在 0 到 24 之间',
          en: 'Hours must be between 0 and 24',
        ),
        isError: true,
      );
      return;
    }

    await provider.saveSimpleLog(
      existing: _editingLog,
      date: provider.selectedDate,
      content: content,
      hours: hours,
    );
    if (!context.mounted) return;
    _resetEditor();
    _showMessage(context, _t(context, zh: '已保存', en: 'Saved'));
  }

  void _startEdit(WorkLogEntry log) {
    setState(() {
      _editingLog = log;
      _contentController.text = log.content;
      _hoursController.text = _formatHours(log.durationHours);
    });
  }

  void _resetEditor() {
    setState(() {
      _editingLog = null;
      _contentController.clear();
      _hoursController.text = '1';
    });
  }

  Future<void> _confirmDelete(BuildContext context, WorkLogEntry log) async {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final confirmed = await showLabConfirm(
      context,
      destructive: true,
      title: isZh ? '删除这条记录？' : 'Delete this entry?',
      summary: log.content,
      body: isZh ? '删除后无法恢复。' : 'This cannot be undone.',
      primaryLabel: isZh ? '删除' : 'Delete',
      secondaryLabel: isZh ? '取消' : 'Cancel',
    );

    if (!context.mounted || !confirmed) return;
    await context.read<TimesheetProvider>().deleteLog(log);
    if (_editingLog?.id == log.id) {
      _resetEditor();
    }
  }

  void _showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    _feedbackTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _feedbackMessage = message;
      _feedbackIsError = isError;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() => _feedbackMessage = null);
    });
  }

  String _dateLabel(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'zh') {
      final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return '${date.year}年${date.month}月${date.day}日 ${weekdays[date.weekday - 1]}';
    }
    return DateFormat.yMMMMEEEEd(locale.toLanguageTag()).format(date);
  }

  String _formatHours(double hours) {
    final text = hours.toStringAsFixed(2);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _t(BuildContext context, {required String zh, required String en}) {
    return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  }
}

class _TotalHoursPill extends StatelessWidget {
  final double hours;

  const _TotalHoursPill({required this.hours});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final text = hours.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Text(
            isZh ? '合计 $text 小时' : 'Total $text h',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineFeedback extends StatelessWidget {
  final String message;
  final bool isError;

  const _InlineFeedback({
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = isError ? colors.error : colors.primary;

    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: Container(
          key: ValueKey('$message-$isError'),
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
