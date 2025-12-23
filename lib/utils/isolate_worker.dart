import 'dart:async';
import 'dart:convert';
import 'dart:io'; // NEW: For Platform.numberOfProcessors
import 'dart:isolate';
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

/// A request to the background isolate
class _WorkerRequest {
  final int id;
  final WorkerInput input;
  final SendPort replyPort;

  _WorkerRequest(this.id, this.input, this.replyPort);
}

/// A response from the background isolate
class _WorkerResponse {
  final int id;
  final String? json; // Success
  final String? error; // Failure

  _WorkerResponse(this.id, this.json, this.error);
}

/// Manager for a POOL of background Isolates.
/// Uses Round-Robin scheduling to distribute load across multiple cores.
class PersistentIsolateManager {
  static final PersistentIsolateManager instance = PersistentIsolateManager._internal();
  
  PersistentIsolateManager._internal();

  // Pool Configuration
  final List<_IsolateWorkerContainer> _workers = [];
  int _submitIndex = 0;
  bool _isReady = false;
  
  /// Initialize the background isolate pool.
  /// Dynamically scales based on CPU cores to maximize throughput.
  Future<void> init() async {
    if (_isReady) return;

    try {
      // DYNAMIC SCALING: Use CPU Core count.
      // Leave 1 core for UI/Main thread, use the rest for workers.
      // Minimum 2 workers, Maximum 12 (to prevent OS limits).
      int cores = Platform.numberOfProcessors;
      int poolSize = (cores - 1).clamp(2, 12); 
      
      print('[IsolateManager] Detected $cores CPU cores. Spawning $poolSize workers.');

      final List<Future<_IsolateWorkerContainer>> futures = [];
      for (int i = 0; i < poolSize; i++) {
        futures.add(_spawnWorker(i));
      }
      _workers.addAll(await Future.wait(futures));
      _isReady = true;
    } catch (e) {
      print('[IsolateManager] Failed to spawn pool: $e');
      _isReady = false;
    }
  }

  Future<_IsolateWorkerContainer> _spawnWorker(int index) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(_isolateEntry, receivePort.sendPort);
    final sendPort = await receivePort.first as SendPort;
    
    final responsePort = ReceivePort();
    sendPort.send(responsePort.sendPort); // Handshake
    
    final container = _IsolateWorkerContainer(index, isolate, sendPort);
    
    // Listen for this specific worker's responses
    responsePort.listen((message) {
      if (message is _WorkerResponse) {
        container.completeJob(message.id, message.json, message.error);
      }
    });

    return container;
  }

  void dispose() {
    for (var w in _workers) {
      w.dispose();
    }
    _workers.clear();
    _isReady = false;
  }

  /// Offload a task to the pool (Round-Robin).
  Future<String> computeTask(WorkerInput input) async {
    if (!_isReady || _workers.isEmpty) {
      return generatePayloadJson(input); // Fallback
    }

    // Round Robin Selection
    final worker = _workers[_submitIndex % _workers.length];
    _submitIndex++;

    return worker.submit(input);
  }

  /// Entry point for EACH isolate
  static void _isolateEntry(SendPort mainSendPort) { // Removed 'async' as we don't await
    final commandPort = ReceivePort();
    mainSendPort.send(commandPort.sendPort); 

    // Single listener to handle both Handshake and Requests
    SendPort? replyPort;
    
    commandPort.listen((message) {
      // 1. Handshake Phase: Expecting a SendPort
      if (replyPort == null) {
        if (message is SendPort) {
          replyPort = message;
        }
        return;
      }

      // 2. Work Phase: Expecting WorkerRequests
      if (message is _WorkerRequest) {
        try {
          final result = generatePayloadJson(message.input);
          replyPort!.send(_WorkerResponse(message.id, result, null));
        } catch (e) {
          replyPort!.send(_WorkerResponse(message.id, null, e.toString()));
        }
      }
    });
  }
}

/// Helper container for managing a single worker's state
class _IsolateWorkerContainer {
  final int index;
  final Isolate isolate;
  final SendPort sendPort;
  
  int _nextId = 0;
  final Map<int, Completer<String>> _pendingJobs = {};

  _IsolateWorkerContainer(this.index, this.isolate, this.sendPort);

  Future<String> submit(WorkerInput input) {
    final id = _nextId++;
    final completer = Completer<String>();
    _pendingJobs[id] = completer;
    sendPort.send(_WorkerRequest(id, input, sendPort)); // replyPort is unused in this flow but kept for structure
    return completer.future;
  }

  void completeJob(int id, String? json, String? error) {
    final completer = _pendingJobs.remove(id);
    if (completer != null) {
      if (error != null) completer.completeError(error);
      else completer.complete(json!);
    }
  }

  void dispose() {
    isolate.kill();
    _pendingJobs.clear();
  }
}

/// Logic function (Same as before)
String generatePayloadJson(WorkerInput input) {
  final Random random = Random();
  final Map<String, dynamic> data = {};
  
  // 1. Add key_1
  data['key_1'] = input.key1Value;

  // 2. Add Custom Keys
  data.addAll(input.customKeyValues);
  
  // 3. Generate Random Keys
  int customCount = input.customKeyValues.length;
  int filledCount = 1 + customCount;
  int remaining = input.count - filledCount;
  
  if (remaining > 0) {
      for (int i = 0; i < remaining; i++) {
         int keyIndex = i + 2; 
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

  // 4. Wrap & Encoded
  final Map<String, dynamic> payload = {
    'ts': input.timestamp,
    'values': data,
  };

  return jsonEncode(payload);
}
