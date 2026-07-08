import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io'; // NEW: For Platform.numberOfProcessors
import 'dart:isolate';
import 'dart:math';

import '../models/payload_format.dart';

/// Input Data for the Worker
class WorkerInput {
  final int count;
  final String? clientId;
  final int timestamp;
  final int key1Value;
  final Map<String, dynamic> customKeyValues; // Pre-calculated custom keys

  /// Target ThingsBoard payload shape (see [PayloadFormat]). Defaults to the
  /// timestamped object form for backward compatibility.
  final String format;

  /// Size of the full key namespace this payload is a subset of. Only used
  /// (together with [randomKeys]) for random change reports; 0 disables it.
  final int totalKeyCount;

  /// When true and [totalKeyCount] > [count], emit a RANDOM subset of [count]
  /// keys drawn from the full namespace instead of the first [count] keys.
  final bool randomKeys;

  WorkerInput({
    required this.count,
    required this.timestamp,
    required this.key1Value,
    required this.customKeyValues,
    this.clientId,
    this.format = PayloadFormat.timestamped,
    this.totalKeyCount = 0,
    this.randomKeys = false,
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
  static final PersistentIsolateManager instance =
      PersistentIsolateManager._internal();

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

      developer.log(
          '[IsolateManager] Detected $cores CPU cores. Spawning $poolSize workers.');

      final List<Future<_IsolateWorkerContainer>> futures = [];
      for (int i = 0; i < poolSize; i++) {
        futures.add(_spawnWorker(i));
      }
      _workers.addAll(await Future.wait(futures));
      _isReady = true;
    } catch (e) {
      developer.log('[IsolateManager] Failed to spawn pool: $e');
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
  static void _isolateEntry(SendPort mainSendPort) {
    // Removed 'async' as we don't await
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
    sendPort.send(_WorkerRequest(id, input,
        sendPort)); // replyPort is unused in this flow but kept for structure
    return completer.future;
  }

  void completeJob(int id, String? json, String? error) {
    final completer = _pendingJobs.remove(id);
    if (completer != null) {
      if (error != null) {
        completer.completeError(error);
      } else {
        completer.complete(json!);
      }
    }
  }

  void dispose() {
    for (final completer in _pendingJobs.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Isolate worker disposed'));
      }
    }
    _pendingJobs.clear();
    isolate.kill(priority: Isolate.immediate);
  }
}

/// Deterministic value for auto-generated key `key_$keyIndex`, matching the
/// legacy type rotation (float / int / string / bool by `keyIndex % 4`).
dynamic _autoKeyValue(int keyIndex, Random random) {
  switch (keyIndex % 4) {
    case 1:
      return double.parse((random.nextDouble() * 100).toStringAsFixed(2));
    case 2:
      return random.nextInt(1001);
    case 3:
      return 'str_val_${random.nextInt(101)}';
    default: // case 0
      return random.nextInt(2) == 1;
  }
}

/// Write the key occupying [slot] of the full namespace into [data]:
///   slot 0            → key_1 (the increment counter)
///   slot 1..custom    → custom key at that position
///   slot > custom     → auto key `key_(slot - custom + 1)` (auto keys from 2)
void _writeKeyAtSlot(
  Map<String, dynamic> data,
  int slot,
  WorkerInput input,
  List<MapEntry<String, dynamic>> customEntries,
  Random random,
) {
  final int customCount = customEntries.length;
  if (slot == 0) {
    data['key_1'] = input.key1Value;
  } else if (slot <= customCount) {
    final e = customEntries[slot - 1];
    data[e.key] = e.value;
  } else {
    final keyIndex = slot - customCount + 1;
    data['key_$keyIndex'] = _autoKeyValue(keyIndex, random);
  }
}

/// Logic function.
String generatePayloadJson(WorkerInput input) {
  final Random random = Random();
  final Map<String, dynamic> data = {};

  final int customCount = input.customKeyValues.length;
  final bool useRandom = input.randomKeys &&
      input.count > 0 &&
      input.totalKeyCount > input.count;

  if (useRandom) {
    // Random change report: pick `count` distinct slots out of the full
    // `totalKeyCount` namespace via a partial Fisher-Yates shuffle, so a
    // random — not fixed-prefix — subset of keys is reported each tick.
    final customEntries = input.customKeyValues.entries.toList();
    final int total = input.totalKeyCount;
    final pool = List<int>.generate(total, (i) => i);
    for (int i = 0; i < input.count; i++) {
      final j = i + random.nextInt(total - i);
      final tmp = pool[i];
      pool[i] = pool[j];
      pool[j] = tmp;
      _writeKeyAtSlot(data, pool[i], input, customEntries, random);
    }
  } else {
    // Deterministic fill: key_1, then all custom keys, then key_2.. to fill.
    data['key_1'] = input.key1Value;
    data.addAll(input.customKeyValues);
    final int remaining = input.count - (1 + customCount);
    for (int i = 0; i < remaining; i++) {
      final int keyIndex = i + 2;
      data['key_$keyIndex'] = _autoKeyValue(keyIndex, random);
    }
  }

  // Shape into the selected ThingsBoard payload format & encode.
  final Object payload =
      PayloadFormat.buildStandard(data, input.timestamp, input.format);

  return jsonEncode(payload);
}
