import 'package:flutter/material.dart';
import '../models/work_log_entry.dart';
import '../services/timesheet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimesheetProvider extends ChangeNotifier {
  final TimesheetService _service = TimesheetService.instance;
  
  DateTime _selectedDate = DateTime.now();
  List<WorkLogEntry> _currentLogs = [];
  bool _isLoading = false;
  
  // Weekly Summary Data: Date -> Total Hours
  Map<DateTime, double> _weekDailyTotals = {};
  Map<DateTime, double> get weekDailyTotals => _weekDailyTotals;

  DateTime get selectedDate => _selectedDate;
  List<WorkLogEntry> get currentLogs => _currentLogs;
  bool get isLoading => _isLoading;

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
      _loadWeekSummary();
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
      _loadWeekSummary();
    } else {
      notifyListeners();
    }
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    _loadLogs();
    _loadWeekSummary(); // Refresh week view if week changed (or just always refresh)
  }

  Future<void> _loadLogs() async {
    _isLoading = true;
    notifyListeners();
    
    _currentLogs = await _service.getLogs(_selectedDate);
    
    _isLoading = false;
    notifyListeners(); // This triggers UI update for daily list
  }
  
  Future<void> _loadWeekSummary() async {
     // Fetch logs for fixed window (past 10 days + future 4 days)
     final now = DateTime.now();
     final today = TsDateUtils.dateOnly(now);
     final start = today.subtract(const Duration(days: 9));
     final end = today.add(const Duration(days: 5)).subtract(const Duration(seconds: 1));
     
     final logs = await _service.getLogsInRange(start, end);
     
     final Map<DateTime, double> totals = {};
     // Initialize 0 for 14 days
     for (int i = 0; i < 14; i++) {
        final day = start.add(Duration(days: i));
        totals[TsDateUtils.dateOnly(day)] = 0.0;
     }
     
     for (var log in logs) {
       final key = TsDateUtils.dateOnly(log.startTime);
       if (totals.containsKey(key)) {
         totals[key] = (totals[key] ?? 0) + log.durationHours;
       }
     }
     
     _weekDailyTotals = totals;
     notifyListeners();
  }
  
  bool validateLog(WorkLogEntry newLog) {
    if (newLog.endTime.isBefore(newLog.startTime) || newLog.endTime.isAtSameMomentAs(newLog.startTime)) {
        return false;
    }
    
    for (var existing in _currentLogs) {
      if (existing.id == newLog.id) continue;
      
      // Overlap logic: (StartA < EndB) && (EndA > StartB)
      if (newLog.startTime.isBefore(existing.endTime) && newLog.endTime.isAfter(existing.startTime)) {
        return false;
      }
    }
    return true;
  }

  Future<void> addLog(WorkLogEntry log) async {
    await _service.saveLog(log);
    await _loadLogs();
    await _loadWeekSummary();
  }
  
  Future<void> updateLog(WorkLogEntry log) async {
    await _service.saveLog(log);
    await _loadLogs();
    await _loadWeekSummary();
  }
  
  Future<void> deleteLog(WorkLogEntry log) async {
    await _service.deleteLog(log);
    await _loadLogs();
    await _loadWeekSummary();
  }
  
  Future<String> generateWeeklyReport(DateTime date) async {
    final logs = await _service.getWeekLogs(date);
    
    // Group by Day
    final Map<String, List<WorkLogEntry>> grouped = {};
    for (var log in logs) {
      final key = "${log.startTime.year}-${log.startTime.month}-${log.startTime.day}";
      grouped.putIfAbsent(key, () => []).add(log);
    }
    
    final buffer = StringBuffer();
    final keys = grouped.keys.toList()..sort();
    
    for (var key in keys) {
      final dayLogs = grouped[key]!;
      if (dayLogs.isEmpty) continue;
      
      final dateObj = dayLogs.first.startTime;
      final weekday = _getWeekdayName(dateObj.weekday);
      
      buffer.writeln("$key ($weekday)");
      for (var log in dayLogs) {
        final start = "${log.startTime.hour.toString().padLeft(2,'0')}:${log.startTime.minute.toString().padLeft(2,'0')}";
        final end = "${log.endTime.hour.toString().padLeft(2,'0')}:${log.endTime.minute.toString().padLeft(2,'0')}";
        final duration = log.durationHours.toStringAsFixed(1);
        
        String prefix = "[${log.category}]";
        if (log.projectCode != null && log.projectCode!.isNotEmpty) {
          prefix = "[${log.projectCode}] ${log.taskName}";
        }
        
        buffer.writeln("- $prefix $start-$end ${log.content} (${duration}h)");
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  Future<List<WorkLogEntry>> getLogsInRange(DateTime start, DateTime end) async {
    return _service.getLogsInRange(start, end);
  }
  
  Map<String, double> getAggregatedReport(List<WorkLogEntry> logs) {
    // Key: "ProjectCode::Content" or just "Content"
    final Map<String, double> report = {};
    
    for (var log in logs) {
      // Use Project Code + Task Content as unique key, or fallback to content
      // e.g. "[PRJ-001] Fix bug"
      String key = log.content;
      if (log.projectCode != null && log.projectCode!.isNotEmpty) {
        key = "[${log.projectCode}] ${log.content}";
      }
      
      report[key] = (report[key] ?? 0) + log.durationHours;
    }
    
    // Sort logic can be done in UI (convert map to list and sort)
    return report;
  }
  
  String _getWeekdayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}
