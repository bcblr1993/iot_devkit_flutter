import 'group_config.dart';
import 'custom_key_config.dart';

abstract class SimulationContext {
  String get topic;
  String get mode;
  int get qos;
}

class BasicSimulationContext extends SimulationContext {
  @override
  final String topic;
  @override
  final String mode = 'basic';
  @override
  final int qos;
  
  final int intervalSeconds;
  final String format;
  final int dataPointCount;
  final List<CustomKeyConfig> customKeys;

  BasicSimulationContext({
    required this.topic,
    this.qos = 0,
    required this.intervalSeconds,
    required this.format,
    required this.dataPointCount,
    required this.customKeys,
  });
}

class AdvancedSimulationContext extends SimulationContext {
  @override
  final String topic;
  @override
  final String mode = 'advanced';
  @override
  final int qos;
  
  final GroupConfig group;

  AdvancedSimulationContext({
    required this.topic,
    this.qos = 0,
    required this.group,
  });
}
