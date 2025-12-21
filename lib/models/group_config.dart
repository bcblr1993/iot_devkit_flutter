import 'package:uuid/uuid.dart';
import 'custom_key_config.dart';

class GroupConfig {
  final String id;
  String name;
  bool isExpanded;

  // Device Range
  int startDeviceNumber;
  int endDeviceNumber;

  // Prefixes
  String devicePrefix;
  String clientIdPrefix;
  String usernamePrefix;
  String passwordPrefix;

  // Simulation Settings
  int totalKeyCount;
  int fullIntervalSeconds;
  int changeIntervalSeconds;
  double changeRatio;
  String format;
  
  // Custom Keys
  List<CustomKeyConfig> customKeys;

  GroupConfig({
    String? id,
    this.name = 'New Group',
    this.isExpanded = true,
    this.startDeviceNumber = 1,
    this.endDeviceNumber = 10,
    this.devicePrefix = 'device',
    this.clientIdPrefix = 'device',
    this.usernamePrefix = 'user',
    this.passwordPrefix = 'pass',
    this.totalKeyCount = 10,
    this.fullIntervalSeconds = 300,
    this.changeIntervalSeconds = 1,
    this.changeRatio = 0.3,
    this.format = 'default',
    this.customKeys = const [],
  }) : id = id ?? const Uuid().v4();

  // Copy with
  GroupConfig copyWith({
    String? name,
    bool? isExpanded,
    int? startDeviceNumber,
    int? endDeviceNumber,
    String? devicePrefix,
    String? clientIdPrefix,
    String? usernamePrefix,
    String? passwordPrefix,
    int? totalKeyCount,
    int? fullIntervalSeconds,
    int? changeIntervalSeconds,
    double? changeRatio,
    String? format,
    List<CustomKeyConfig>? customKeys,
  }) {
    return GroupConfig(
      id: id,
      name: name ?? this.name,
      isExpanded: isExpanded ?? this.isExpanded,
      startDeviceNumber: startDeviceNumber ?? this.startDeviceNumber,
      endDeviceNumber: endDeviceNumber ?? this.endDeviceNumber,
      devicePrefix: devicePrefix ?? this.devicePrefix,
      clientIdPrefix: clientIdPrefix ?? this.clientIdPrefix,
      usernamePrefix: usernamePrefix ?? this.usernamePrefix,
      passwordPrefix: passwordPrefix ?? this.passwordPrefix,
      totalKeyCount: totalKeyCount ?? this.totalKeyCount,
      fullIntervalSeconds: fullIntervalSeconds ?? this.fullIntervalSeconds,
      changeIntervalSeconds: changeIntervalSeconds ?? this.changeIntervalSeconds,
      changeRatio: changeRatio ?? this.changeRatio,
      format: format ?? this.format,
      customKeys: customKeys ?? this.customKeys,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startDeviceNumber': startDeviceNumber,
      'endDeviceNumber': endDeviceNumber,
      'devicePrefix': devicePrefix,
      'clientIdPrefix': clientIdPrefix,
      'usernamePrefix': usernamePrefix,
      'passwordPrefix': passwordPrefix,
      'totalKeyCount': totalKeyCount,
      'fullIntervalSeconds': fullIntervalSeconds,
      'changeIntervalSeconds': changeIntervalSeconds,
      'changeRatio': changeRatio,
      'format': format,
      'customKeys': customKeys.map((e) => e.toJson()).toList(),
    };
  }

  factory GroupConfig.fromJson(Map<String, dynamic> json) {
    return GroupConfig(
      id: json['id'],
      name: json['name'] ?? 'New Group',
      startDeviceNumber: json['startDeviceNumber'] ?? 1,
      endDeviceNumber: json['endDeviceNumber'] ?? 10,
      devicePrefix: json['devicePrefix'] ?? 'device',
      clientIdPrefix: json['clientIdPrefix'] ?? 'device',
      usernamePrefix: json['usernamePrefix'] ?? 'user',
      passwordPrefix: json['passwordPrefix'] ?? 'pass',
      totalKeyCount: json['totalKeyCount'] ?? 10,
      fullIntervalSeconds: json['fullIntervalSeconds'] ?? 300,
      changeIntervalSeconds: json['changeIntervalSeconds'] ?? 1,
      changeRatio: (json['changeRatio'] ?? 0.3).toDouble(),
      format: json['format'] ?? 'default',
      customKeys: (json['customKeys'] as List? ?? [])
          .map((e) => CustomKeyConfig.fromJson(e))
          .toList(),
    );
  }
}
