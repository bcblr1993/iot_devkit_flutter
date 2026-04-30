import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/work_log_entry.dart';
import '../services/timesheet_service.dart';

class TimesheetProvider extends ChangeNotifier {
  final TimesheetService _service = TimesheetService.instance;

  DateTime _selectedDate = DateTime.now();
  List<WorkLogEntry> _currentLogs = [];
  bool _isLoading = false;

  DateTime get selectedDate => _selectedDate;
  List<WorkLogEntry> get currentLogs => _currentLogs;
  bool get isLoading => _isLoading;
  double get totalHours =>
      _currentLogs.fold<double>(0, (sum, log) => sum + log.durationHours);

  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  TimesheetProvider() {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('ts_enabled') ?? false;
    if (_isEnabled) {
      _loadLogs();
    } else {
      notifyListeners();
    }
  }

  Future<void> toggleEnabled(bool value) async {
    _isEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ts_enabled', value);
    if (_isEnabled) {
      _loadLogs();
    } else {
      notifyListeners();
    }
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    _isLoading = true;
    notifyListeners();

    _currentLogs = await _service.getLogs(_selectedDate);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addLog(WorkLogEntry log) async {
    await _service.saveLog(log);
    await _loadLogs();
  }

  Future<void> updateLog(WorkLogEntry log) async {
    await _service.saveLog(log);
    await _loadLogs();
  }

  Future<void> saveSimpleLog({
    WorkLogEntry? existing,
    required DateTime date,
    required String content,
    required double hours,
  }) async {
    final now = DateTime.now();
    final startTime = existing?.startTime ??
        DateTime(
          date.year,
          date.month,
          date.day,
          now.hour,
          now.minute,
          now.second,
          now.millisecond,
        );
    final normalizedStart = DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
      startTime.second,
      startTime.millisecond,
    );
    final minutes = (hours * 60).round().clamp(1, 24 * 60).toInt();
    final log = WorkLogEntry(
      id: existing?.id,
      startTime: normalizedStart,
      endTime: normalizedStart.add(Duration(minutes: minutes)),
      content: content.trim(),
      hours: hours,
      category: 'note',
      projectId: 'simple',
    );

    await _service.saveLog(log);
    await _loadLogs();
  }

  Future<void> deleteLog(WorkLogEntry log) async {
    await _service.deleteLog(log);
    await _loadLogs();
  }

  Future<String> generateWeeklyReport(DateTime date) async {
    final logs = await _service.getWeekLogs(date);

    // Group by Day
    final Map<String, List<WorkLogEntry>> grouped = {};
    for (var log in logs) {
      final key = [
        log.startTime.year.toString(),
        log.startTime.month.toString().padLeft(2, '0'),
        log.startTime.day.toString().padLeft(2, '0'),
      ].join('-');
      grouped.putIfAbsent(key, () => []).add(log);
    }

    final buffer = StringBuffer();
    final keys = grouped.keys.toList()..sort();

    for (var key in keys) {
      final dayLogs = grouped[key]!;
      if (dayLogs.isEmpty) continue;

      final dateObj = dayLogs.first.startTime;
      final weekday = _getWeekdayName(dateObj.weekday);
      final totalHours =
          dayLogs.fold<double>(0, (sum, log) => sum + log.durationHours);

      buffer.writeln("$key ($weekday) ${totalHours.toStringAsFixed(1)}h");
      for (var log in dayLogs) {
        final duration = log.durationHours.toStringAsFixed(1);
        buffer.writeln("- ${duration}h ${log.content}");
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  String _getWeekdayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}
