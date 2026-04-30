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

    final allLogs =
        jsonList.map((e) => WorkLogEntry.fromJson(jsonDecode(e))).toList();

    // Filter for specific day and sort by start time
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final dayLogs = allLogs.where((log) {
      return !log.startTime.isBefore(dayStart) &&
          log.startTime.isBefore(dayEnd);
    }).toList();

    dayLogs.sort((a, b) => a.startTime.compareTo(b.startTime));
    return dayLogs;
  }

  Future<List<WorkLogEntry>> getWeekLogs(DateTime date) async {
    // Find Monday
    int daysToMonday = date.weekday - 1;
    DateTime monday =
        DateUtils.dateOnly(date).subtract(Duration(days: daysToMonday));
    List<WorkLogEntry> weekLogs = [];

    // Iterate 7 days (might cross month boundary, so load carefully)
    for (int i = 0; i < 7; i++) {
      DateTime current = monday.add(Duration(days: i));
      weekLogs.addAll(await getLogs(current));
    }
    return weekLogs;
  }

  Future<void> saveLog(WorkLogEntry log) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getMonthKey(log.startTime);

    // Load existing
    final jsonList = prefs.getStringList(key) ?? [];
    List<WorkLogEntry> logs =
        jsonList.map((e) => WorkLogEntry.fromJson(jsonDecode(e))).toList();

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
    List<WorkLogEntry> logs =
        jsonList.map((e) => WorkLogEntry.fromJson(jsonDecode(e))).toList();

    logs.removeWhere((e) => e.id == log.id);

    final newJsonList = logs.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(key, newJsonList);
  }
}

class DateUtils {
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
