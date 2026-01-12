import 'package:uuid/uuid.dart';

class WorkLogEntry {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final String content;
  final String category;
  final String projectId;

  WorkLogEntry({
    String? id,
    required this.startTime,
    required this.endTime,
    required this.content,
    this.category = 'dev',
    this.projectId = 'default',
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
    );
  }
  
  WorkLogEntry copyWith({
    DateTime? startTime,
    DateTime? endTime,
    String? content,
    String? category,
  }) {
    return WorkLogEntry(
      id: id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      content: content ?? this.content,
      category: category ?? this.category,
      projectId: projectId,
    );
  }
}
