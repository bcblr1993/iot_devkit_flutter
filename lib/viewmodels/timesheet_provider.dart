import 'package:flutter/material.dart';
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

  TimesheetProvider() {
    _loadLogs();
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
  
  Future<void> deleteLog(WorkLogEntry log) async {
    await _service.deleteLog(log);
    await _loadLogs();
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
        
        buffer.writeln("- [${log.category}] $start-$end ${log.content} (${duration}h)");
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
