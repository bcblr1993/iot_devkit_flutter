import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/work_log_entry.dart';

class TimesheetService {
  static const String _keyPrefix = 'ts_logs_';
  
  TimesheetService._();
  static final TimesheetService instance = TimesheetService._();
  
  String _getMonthKey(DateTime date) {
    return '$_keyPrefix${date.year}_${date.month}';
  }

  Future<List<WorkLogEntry>> getLogs(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getMonthKey(date);
    final jsonList = prefs.getStringList(key) ?? [];
    
    final allLogs = jsonList.map((e) => WorkLogEntry.fromJson(jsonDecode(e))).toList();
    
    // Filter for specific day and sort by start time
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    
    final dayLogs = allLogs.where((log) {
      return log.startTime.isAfter(dayStart) && log.startTime.isBefore(dayEnd);
    }).toList();
    
    dayLogs.sort((a, b) => a.startTime.compareTo(b.startTime));
    return dayLogs;
  }
  
  Future<List<WorkLogEntry>> getWeekLogs(DateTime date) async {
     // Find Monday
    int daysToMonday = date.weekday - 1;
    DateTime monday = TsDateUtils.dateOnly(date).subtract(Duration(days: daysToMonday));
    // End of Sunday
    DateTime endOfWeek = monday.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
    return getLogsInRange(monday, endOfWeek);
  }

  Future<List<WorkLogEntry>> getLogsInRange(DateTime start, DateTime end) async {
    List<WorkLogEntry> rangeLogs = [];
    
    // Normalize range to iterate months
    // We iterate from start month to end month
    DateTime currentMonth = DateTime(start.year, start.month);
    DateTime lastMonth = DateTime(end.year, end.month);
    
    while (currentMonth.isBefore(lastMonth) || currentMonth.isAtSameMomentAs(lastMonth)) {
       // Load logs for this month
       final allLogs = await _loadMonthLogs(currentMonth);
       
       // Filter logs clearly within range
       rangeLogs.addAll(allLogs.where((log) {
         return log.startTime.isAfter(start.subtract(const Duration(seconds: 1))) && 
                log.startTime.isBefore(end.add(const Duration(seconds: 1)));
       }));
       
       // Move to next month
       currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
    }
    
    rangeLogs.sort((a, b) => a.startTime.compareTo(b.startTime));
    return rangeLogs;
  }
  
  Future<List<WorkLogEntry>> _loadMonthLogs(DateTime monthDate) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getMonthKey(monthDate);
    final jsonList = prefs.getStringList(key) ?? [];
    return jsonList.map((e) => WorkLogEntry.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveLog(WorkLogEntry log) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getMonthKey(log.startTime);
    
    // Load existing
    final jsonList = prefs.getStringList(key) ?? [];
    List<WorkLogEntry> logs = jsonList.map((e) => WorkLogEntry.fromJson(jsonDecode(e))).toList();
    
    // Update or Add
    final index = logs.indexWhere((e) => e.id == log.id);
    if (index != -1) {
      logs[index] = log;
    } else {
      logs.add(log);
    }
    
    // Save back
    final newJsonList = logs.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(key, newJsonList);
  }

  Future<void> deleteLog(WorkLogEntry log) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getMonthKey(log.startTime);
    
    final jsonList = prefs.getStringList(key) ?? [];
    List<WorkLogEntry> logs = jsonList.map((e) => WorkLogEntry.fromJson(jsonDecode(e))).toList();
    
    logs.removeWhere((e) => e.id == log.id);
    
    final newJsonList = logs.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(key, newJsonList);
  }
}

class TsDateUtils {
  static DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
