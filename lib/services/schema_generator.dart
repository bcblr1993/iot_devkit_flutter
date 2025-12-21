import '../models/schema_item.dart';

class SchemaGenerator {
  /// Generate a simplified schema based on ratios
  /// [keyCount] Total number of keys
  /// [typeRatio] Map of type ratios, e.g., {'float': 0.5, 'int': 0.5}
  static List<SchemaItem> generate(int keyCount, Map<String, double> typeRatio) {
    List<SchemaItem> schema = [];
    
    // Normalize ratios
    double totalRatio = typeRatio.values.fold(0.0, (a, b) => a + b);
    if (totalRatio == 0) {
      typeRatio = {'float': 1.0};
      totalRatio = 1.0;
    } else {
      typeRatio.updateAll((key, value) => value / totalRatio);
    }

    // Calculate counts
    Map<String, int> counts = {
      'float': (keyCount * (typeRatio['float'] ?? 0)).floor(),
      'int': (keyCount * (typeRatio['int'] ?? 0)).floor(),
      'string': (keyCount * (typeRatio['string'] ?? 0)).floor(),
      'bool': (keyCount * (typeRatio['bool'] ?? 0)).floor(),
    };

    // Fill remainder
    int currentCount = counts.values.fold(0, (a, b) => a + b);
    while (currentCount < keyCount) {
      counts['float'] = (counts['float'] ?? 0) + 1;
      currentCount++;
    }

    int keyIndex = 1;
    
    // 1. Float
    for (int i = 0; i < (counts['float'] ?? 0); i++) {
      schema.add(SchemaItem(name: 'key_${keyIndex++}', type: 'float'));
    }
    // 2. Int
    for (int i = 0; i < (counts['int'] ?? 0); i++) {
      schema.add(SchemaItem(name: 'key_${keyIndex++}', type: 'int'));
    }
    // 3. String
    for (int i = 0; i < (counts['string'] ?? 0); i++) {
      schema.add(SchemaItem(name: 'key_${keyIndex++}', type: 'string'));
    }
    // 4. Bool
    for (int i = 0; i < (counts['bool'] ?? 0); i++) {
      schema.add(SchemaItem(name: 'key_${keyIndex++}', type: 'bool'));
    }

    return schema;
  }
}
