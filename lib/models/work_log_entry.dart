import 'package:uuid/uuid.dart';

class WorkLogEntry {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final String content;
  final String category;
  final String projectId;
  final String? projectCode;
  final String? taskName;
  final String? taskScope;

  WorkLogEntry({
    String? id,
    required this.startTime,
    required this.endTime,
    required this.content,
    this.category = 'dev',
    this.projectId = 'default',
    this.projectCode,
    this.taskName,
    this.taskScope,
  }) : id = id ?? const Uuid().v4();

  double get durationHours => endTime.difference(startTime).inMinutes / 60.0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'content': content,
      'category': category,
      'projectId': projectId,
      'projectCode': projectCode,
      'taskName': taskName,
      'taskScope': taskScope,
    };
  }

  factory WorkLogEntry.fromJson(Map<String, dynamic> json) {
    return WorkLogEntry(
      id: json['id'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      content: json['content'] ?? '',
      category: json['category'] ?? 'dev',
      projectId: json['projectId'] ?? 'default',
      projectCode: json['projectCode'],
      taskName: json['taskName'],
      taskScope: json['taskScope'],
    );
  }
  
  WorkLogEntry copyWith({
    DateTime? startTime,
    DateTime? endTime,
    String? content,
    String? category,
    String? projectCode,
    String? taskName,
    String? taskScope,
  }) {
    return WorkLogEntry(
      id: id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      content: content ?? this.content,
      category: category ?? this.category,
      projectId: projectId,
      projectCode: projectCode ?? this.projectCode,
      taskName: taskName ?? this.taskName,
      taskScope: taskScope ?? this.taskScope,
    );
  }
}
