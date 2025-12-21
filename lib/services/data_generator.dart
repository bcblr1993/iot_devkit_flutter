import 'dart:math';
import '../models/schema_item.dart';
import '../models/custom_key_config.dart';

class DataGenerator {
  static final Random _random = Random();
  
  // ======================== key_1 Counter ========================
  static final Map<String, int> _key1Counters = {};
  static const int _key1MaxValue = 9007199254740991; // JS Safe Max Int

  static int getKey1Value(String? clientId) {
    String key = clientId ?? '__default__';
    int current = _key1Counters[key] ?? 1;
    
    int returnValue = current;
    
    current++;
    if (current > _key1MaxValue) {
      current = 1;
    }
    _key1Counters[key] = current;
    
    return returnValue;
  }

  static void resetKey1Counter() {
    _key1Counters.clear();
  }

  // ======================== Helpers ========================
  
  static double getRandomFloat(double min, double max, int decimalPlaces) {
    double val = _random.nextDouble() * (max - min) + min;
    return double.parse(val.toStringAsFixed(decimalPlaces));
  }

  static int getRandomInt(int min, int max) {
    return min + _random.nextInt(max - min + 1);
  }

  // ======================== Generators ========================

  static Map<String, dynamic> generateBatteryStatus(int count, {String? clientId, List<CustomKeyConfig>? customKeys}) {
    final Map<String, dynamic> data = {};
    
    // Custom keys are part of the total count
    final int customCount = customKeys?.length ?? 0;
    // We prioritize custom keys but only up to 'count'
    final int effectiveCustomCount = min(customCount, count);
    final int autoGenerateCount = count - effectiveCustomCount;
    
    // First, add auto-generated keys (if any space left)
    for (int i = 1; i <= autoGenerateCount; i++) {
      if (i == 1) {
        data['key_$i'] = getKey1Value(clientId);
      } else {
        int typeIndex = i % 4;
        switch (typeIndex) {
          case 1:
            data['key_$i'] = getRandomFloat(0, 100, 2);
            break;
          case 2:
            data['key_$i'] = getRandomInt(0, 1000);
            break;
          case 3:
            data['key_$i'] = 'str_val_${getRandomInt(0, 100)}';
            break;
          case 0:
            data['key_$i'] = getRandomInt(0, 1) == 1;
            break;
        }
      }
    }
    
    // Then, add custom keys (up to effective limit)
    if (customKeys != null && customKeys.isNotEmpty) {
      for (int i = 0; i < effectiveCustomCount; i++) {
        final key = customKeys[i];
        data[key.name] = _generateSingleCustomValue(key);
      }
    }

    return data;
  }

  static Map<String, dynamic> generateTnPayload(int count, {int? timestamp}) {
    List<Map<String, dynamic>> arr = [];
    for (int i = 0; i < count; i++) {
      arr.add({
        "id": "Tag${i + 1}",
        "desc": "C1_D1_Tag${i + 1}",
        "quality": 0,
        "value": _random.nextDouble()
      });
    }

    DateTime now = timestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp) 
        : DateTime.now();
        
    String timeStr = now.toIso8601String().replaceAll('T', ' ').substring(0, 19);

    return {
      "type": "real",
      "sn": "TN001",
      "sendStartTime": timeStr,
      "time": now.millisecondsSinceEpoch,
      "data": {
        "C24_D1": arr
      }
    };
  }
  
  static Map<String, dynamic> generateTnEmptyPayload({int? timestamp}) {
    DateTime now = timestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp) 
        : DateTime.now();
        
    String timeStr = now.toIso8601String().replaceAll('T', ' ').substring(0, 19);

    return {
      "type": "real",
      "sn": "TN001",
      "sendStartTime": timeStr,
      "time": now.millisecondsSinceEpoch,
      "data": {}
    };
  }

  static Map<String, dynamic> generateTypedData(List<SchemaItem> schema, int count, {String? clientId, int? timestamp}) {
    final Map<String, dynamic> data = {};
    int effectiveCount = min(count, schema.length);

    for (int i = 0; i < effectiveCount; i++) {
      final item = schema[i];

      if (item.name == 'key_1') {
        data[item.name] = getKey1Value(clientId);
        continue;
      }

      switch (item.type) {
        case 'float':
          data[item.name] = getRandomFloat(0, 100, 2);
          break;
        case 'int':
          data[item.name] = getRandomInt(0, 1000);
          break;
        case 'string':
          data[item.name] = 'str_val_${getRandomInt(0, 100)}';
          break;
        case 'bool':
          data[item.name] = getRandomInt(0, 1) == 1;
          break;
        default:
          data[item.name] = getRandomFloat(0, 100, 2);
      }
    }

    if (timestamp != null) {
      data['ts'] = timestamp;
    }

    return data;
  }
  
  // ======================== Custom Keys ========================
  static final Map<String, int> _customKeyCounters = {};
  static final Map<String, int> _customKeyToggleStates = {};
  static const int _customKeyMaxValue = 9007199254740991;

  static void resetCustomKeyCounters() {
    _customKeyCounters.clear();
    _customKeyToggleStates.clear();
  }

  static dynamic _getCustomKeyIncrementValue(String keyName) {
    int current = _customKeyCounters[keyName] ?? 0;
    current++;
    if (current > _customKeyMaxValue) {
      current = 1;
    }
    _customKeyCounters[keyName] = current;
    return current;
  }

  static int _getCustomKeyToggleValue(String keyName) {
    int current = _customKeyToggleStates[keyName] ?? 0;
    int newValue = current == 0 ? 1 : 0;
    _customKeyToggleStates[keyName] = newValue;
    return newValue;
  }

  static dynamic _generateSingleCustomValue(CustomKeyConfig key) {
    switch (key.mode) {
      case CustomKeyMode.static:
        return _parseStaticValue(key.staticValue, key.type);
      case CustomKeyMode.increment:
        return _getCustomKeyIncrementValue(key.name);
      case CustomKeyMode.toggle:
        return _getCustomKeyToggleValue(key.name);
      case CustomKeyMode.random:
      default:
        return _generateRandomValue(key);
    }
  }

  static dynamic _parseStaticValue(String? value, CustomKeyType type) {
    if (value == null || value.isEmpty) return null;
    switch (type) {
      case CustomKeyType.integer:
        return int.tryParse(value) ?? 0;
      case CustomKeyType.float:
        return double.tryParse(value) ?? 0.0;
      case CustomKeyType.boolean:
        return value.toLowerCase() == 'true' || value == '1';
      case CustomKeyType.string:
      default:
        return value;
    }
  }

  static dynamic _generateRandomValue(CustomKeyConfig key) {
    switch (key.type) {
      case CustomKeyType.integer:
        int min = key.min?.toInt() ?? 0;
        int max = key.max?.toInt() ?? 100;
        return getRandomInt(min, max);
      case CustomKeyType.float:
         double min = key.min ?? 0;
         double max = key.max ?? 100;
         return getRandomFloat(min, max, 2);
      case CustomKeyType.string:
        return '${key.name}_${getRandomInt(0, 1000)}';
      case CustomKeyType.boolean:
        return getRandomInt(0, 1) == 1;
    }
  }

  static Map<String, dynamic> generateCustomKeys(List<CustomKeyConfig> customKeys) {
    final Map<String, dynamic> data = {};
    for (var key in customKeys) {
      data[key.name] = _generateSingleCustomValue(key);
    }
    return data;
  }

  static Map<String, dynamic> mergeCustomKeys(Map<String, dynamic> generatedData, List<CustomKeyConfig> customKeys) {
    if (customKeys.isEmpty) return generatedData;
    final customData = generateCustomKeys(customKeys);
    // Custom keys usually come first or override
    return {...customData, ...generatedData};
  }
}
