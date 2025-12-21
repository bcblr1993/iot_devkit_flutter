import 'package:uuid/uuid.dart';

enum CustomKeyType { integer, float, string, boolean }
enum CustomKeyMode { random, static, increment, toggle }

class CustomKeyConfig {
  final String id;
  String name;
  CustomKeyType type;
  CustomKeyMode mode;
  
  // Random Mode
  double? min;
  double? max;
  
  // Static Mode
  String? staticValue;

  CustomKeyConfig({
    String? id,
    this.name = 'key_custom',
    this.type = CustomKeyType.integer,
    this.mode = CustomKeyMode.random,
    this.min = 0,
    this.max = 100,
    this.staticValue = '',
  }) : id = id ?? const Uuid().v4();

  CustomKeyConfig copyWith({
    String? name,
    CustomKeyType? type,
    CustomKeyMode? mode,
    double? min,
    double? max,
    String? staticValue,
  }) {
    return CustomKeyConfig(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      mode: mode ?? this.mode,
      min: min ?? this.min,
      max: max ?? this.max,
      staticValue: staticValue ?? this.staticValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'mode': mode.name,
      'min': min,
      'max': max,
      'static_value': staticValue,
    };
  }

  factory CustomKeyConfig.fromJson(Map<String, dynamic> json) {
    return CustomKeyConfig(
      id: json['id'],
      name: json['name'] ?? 'key_custom',
      type: CustomKeyType.values.firstWhere((e) => e.name == json['type'], orElse: () => CustomKeyType.integer),
      mode: CustomKeyMode.values.firstWhere((e) => e.name == json['mode'], orElse: () => CustomKeyMode.random),
      min: json['min']?.toDouble(),
      max: json['max']?.toDouble(),
      staticValue: json['static_value'],
    );
  }
}
