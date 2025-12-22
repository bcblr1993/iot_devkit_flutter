import 'group_config.dart';
import 'custom_key_config.dart';

abstract class SimulationContext {
  String get topic;
  String get mode;
}

class BasicSimulationContext extends SimulationContext {
  @override
  final String topic;
  @override
  final String mode = 'basic';
  
  final int intervalSeconds;
  final String format;
  final int dataPointCount;
  final List<CustomKeyConfig> customKeys;

  BasicSimulationContext({
    required this.topic,
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
  
  final GroupConfig group;

  AdvancedSimulationContext({
    required this.topic,
    required this.group,
  });
}
