import 'dart:convert';
import 'dart:math';

/// Input Data for the Worker
class WorkerInput {
  final int count;
  final String? clientId;
  final int timestamp;
  final int key1Value;
  final Map<String, dynamic> customKeyValues; // Pre-calculated custom keys
  
  WorkerInput({
    required this.count,
    required this.timestamp, 
    required this.key1Value,
    required this.customKeyValues,
    this.clientId,
  });
}

/// The entry point for the background isolate.
/// MUST be a top-level function or static method.
String generatePayloadJson(WorkerInput input) {
  final Random random = Random();
  final Map<String, dynamic> data = {};
  
  // 1. Add key_1 (Pre-calculated from main thread)
  data['key_1'] = input.key1Value;

  // 2. Add Pre-calculated Custom Keys
  data.addAll(input.customKeyValues);
  
  // 3. Generate Random Keys (The heavy lifting)
  // Determine how many random keys we need to fill the 'count'
  // Strategy: autoGenerateCount = count - customKeys.length - 1 (key_1)
  int customCount = input.customKeyValues.length;
  // key_1 is always added, so we count it
  int filledCount = 1 + customCount;
  
  int remaining = input.count - filledCount;
  
  // We start loop from 2 because key_1 is handled
  if (remaining > 0) {
      for (int i = 0; i < remaining; i++) {
         // key_index will be 2, 3, 4... etc.
         // But we need to avoid collision with 'key_1'. 
         // The original logic used key_$i where i=1..count.
         // So if we have key_1, next is key_2.
         int keyIndex = i + 2; 
         
         // Generate value based on index pattern (simplified from DataGenerator)
         int typeIndex = keyIndex % 4;
         dynamic value;
         switch (typeIndex) {
            case 1:
              value = double.parse((random.nextDouble() * 100).toStringAsFixed(2));
              break;
            case 2:
              value = random.nextInt(1001);
              break;
            case 3:
              value = 'str_val_${random.nextInt(101)}';
              break;
            case 0:
              value = random.nextInt(2) == 1;
              break;
         }
         data['key_$keyIndex'] = value;
      }
  }

  // 4. Wrap with Timestamp
  final Map<String, dynamic> payload = {
    'ts': input.timestamp,
    'values': data,
  };

  // 5. Serialize (Expensive operation)
  return jsonEncode(payload);
}
