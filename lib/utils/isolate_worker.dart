import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io'; // NEW: For Platform.numberOfProcessors
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:typed_data/typed_buffers.dart';

import '../models/payload_format.dart';
import '../services/data_generator.dart';

/// Split the machine-wide generation-worker budget across simulator processes.
/// Each process also needs one main isolate for MQTT scheduling and socket I/O.
int recommendedIsolateWorkerCount({
  required int processorCount,
  int processCount = 1,
}) {
  if (processorCount < 1) {
    throw RangeError.range(processorCount, 1, null, 'processorCount');
  }
  if (processCount < 1) {
    throw RangeError.range(processCount, 1, null, 'processCount');
  }

  return ((processorCount ~/ processCount) - 1).clamp(1, 12);
}

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
  final bool returnUtf8Bytes;

  _WorkerRequest(this.id, this.input, {required this.returnUtf8Bytes});
}

/// A response from the background isolate
class _WorkerResponse {
  final int id;
  final String? json; // Success
  final Uint8Buffer? utf8Bytes;
  final String? error; // Failure

  _WorkerResponse(this.id, this.json, this.utf8Bytes, this.error);
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

  bool get isReady => _isReady;

  /// Initialize the background isolate pool.
  /// Dynamically scales based on CPU cores to maximize throughput.
  Future<void> init({int processCount = 1}) async {
    if (_isReady) return;

    try {
      // Divide the machine-wide worker budget across process shards. Without
      // this, two processes on a 10-core host each create 9 workers and spend
      // time context-switching instead of increasing MQTT throughput.
      final cores = Platform.numberOfProcessors;
      final poolSize = recommendedIsolateWorkerCount(
        processorCount: cores,
        processCount: processCount,
      );

      developer.log(
          '[IsolateManager] Detected $cores CPU cores across $processCount process(es). Spawning $poolSize workers.');

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
    receivePort.close();

    final responsePort = ReceivePort();
    sendPort.send(responsePort.sendPort); // Handshake

    final container =
        _IsolateWorkerContainer(index, isolate, sendPort, responsePort);

    // Listen for this specific worker's responses
    container.responseSubscription = responsePort.listen((message) {
      if (message is _WorkerResponse) {
        container.completeJob(
          message.id,
          message.json,
          message.utf8Bytes,
          message.error,
        );
      }
    });

    return container;
  }

  void dispose() {
    for (var w in _workers) {
      w.dispose();
    }
    _workers.clear();
    _submitIndex = 0;
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

    return worker.submitString(input);
  }

  /// Generate JSON directly as UTF-8 in a background isolate.
  ///
  /// The old String path made the Flutter main isolate walk every UTF-16 code
  /// unit again in [MqttClientPayloadBuilder.addString]. Full reports contain
  /// hundreds of keys, so that extra work becomes the dominant burst cost.
  /// The worker returns mqtt_client's required Uint8Buffer directly. Dart
  /// copies the mutable buffer while sending it, keeping that copy work off the
  /// Flutter main isolate and avoiding a second payload-builder pass there.
  Future<Uint8Buffer> computeBytesTask(WorkerInput input) async {
    if (!_isReady || _workers.isEmpty) {
      return generatePayloadBuffer(input); // Fallback
    }

    final worker = _workers[_submitIndex % _workers.length];
    _submitIndex++;

    return worker.submitBytes(input);
  }

  /// Entry point for EACH isolate
  static void _isolateEntry(SendPort mainSendPort) {
    // Removed 'async' as we don't await
    final commandPort = ReceivePort();
    mainSendPort.send(commandPort.sendPort);

    // Single listener to handle both Handshake and Requests
    SendPort? replyPort;
    final random = Random();

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
          if (message.returnUtf8Bytes) {
            final result = generatePayloadBuffer(message.input, random: random);
            replyPort!.send(_WorkerResponse(message.id, null, result, null));
          } else {
            final result = generatePayloadJson(message.input, random: random);
            replyPort!.send(_WorkerResponse(message.id, result, null, null));
          }
        } catch (e) {
          replyPort!
              .send(_WorkerResponse(message.id, null, null, e.toString()));
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
  final ReceivePort responsePort;
  late final StreamSubscription<dynamic> responseSubscription;

  int _nextId = 0;
  final Map<int, Completer<String>> _pendingStringJobs = {};
  final Map<int, Completer<Uint8Buffer>> _pendingByteJobs = {};

  _IsolateWorkerContainer(
    this.index,
    this.isolate,
    this.sendPort,
    this.responsePort,
  );

  Future<String> submitString(WorkerInput input) {
    final id = _nextId++;
    final completer = Completer<String>();
    _pendingStringJobs[id] = completer;
    sendPort.send(_WorkerRequest(id, input, returnUtf8Bytes: false));
    return completer.future;
  }

  Future<Uint8Buffer> submitBytes(WorkerInput input) {
    final id = _nextId++;
    final completer = Completer<Uint8Buffer>();
    _pendingByteJobs[id] = completer;
    sendPort.send(_WorkerRequest(id, input, returnUtf8Bytes: true));
    return completer.future;
  }

  void completeJob(
    int id,
    String? json,
    Uint8Buffer? utf8Bytes,
    String? error,
  ) {
    final stringCompleter = _pendingStringJobs.remove(id);
    if (stringCompleter != null) {
      if (error != null) {
        stringCompleter.completeError(error);
      } else if (json != null) {
        stringCompleter.complete(json);
      } else {
        stringCompleter.completeError(
          StateError('Worker returned no JSON for string job $id'),
        );
      }
      return;
    }

    final byteCompleter = _pendingByteJobs.remove(id);
    if (byteCompleter != null) {
      if (error != null) {
        byteCompleter.completeError(error);
      } else if (utf8Bytes != null) {
        byteCompleter.complete(utf8Bytes);
      } else {
        byteCompleter.completeError(
          StateError('Worker returned no UTF-8 payload for byte job $id'),
        );
      }
    }
  }

  void dispose() {
    for (final completer in _pendingStringJobs.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Isolate worker disposed'));
      }
    }
    for (final completer in _pendingByteJobs.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Isolate worker disposed'));
      }
    }
    _pendingStringJobs.clear();
    _pendingByteJobs.clear();
    unawaited(responseSubscription.cancel());
    responsePort.close();
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
Object _generatePayloadObject(WorkerInput input, Random random) {
  final format = PayloadFormat.normalize(input.format);
  if (format == PayloadFormat.tieNiu) {
    return DataGenerator.generateTnPayload(
      input.count,
      timestamp: input.timestamp,
    );
  }
  if (format == PayloadFormat.tieNiuEmpty) {
    return DataGenerator.generateTnEmptyPayload(timestamp: input.timestamp);
  }

  final Map<String, dynamic> data = {};

  final customEntries = input.customKeyValues.entries.toList();
  final bool useRandom =
      input.randomKeys && input.count > 0 && input.totalKeyCount > input.count;

  if (useRandom) {
    // Random change report: pick `count` distinct slots out of the full
    // `totalKeyCount` namespace via a partial Fisher-Yates shuffle, so a
    // random — not fixed-prefix — subset of keys is reported each tick.
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
    // Deterministic fill follows the same fixed-size namespace as random
    // reports. This is deliberately slot-based so count=0 emits no keys and
    // custom keys can never make the payload exceed the configured point
    // count used by capacity planning and statistics.
    for (int slot = 0; slot < input.count; slot++) {
      _writeKeyAtSlot(data, slot, input, customEntries, random);
    }
  }

  // Shape into the selected ThingsBoard payload format & encode.
  return PayloadFormat.buildStandard(data, input.timestamp, format);
}

/// Generate a JSON String. Kept for compatibility with callers that need text.
String generatePayloadJson(WorkerInput input, {Random? random}) {
  return jsonEncode(_generatePayloadObject(input, random ?? Random()));
}

/// Generate JSON straight into UTF-8 without allocating an intermediate
/// String. [JsonUtf8Encoder] currently returns a Uint8List; retain a defensive
/// conversion so this remains correct if the SDK implementation changes.
Uint8List generatePayloadUtf8(WorkerInput input, {Random? random}) {
  final encoded = JsonUtf8Encoder()
      .convert(_generatePayloadObject(input, random ?? Random()));

  return encoded is Uint8List ? encoded : Uint8List.fromList(encoded);
}

/// Build the growable byte buffer required by mqtt_client in the worker so the
/// Flutter main isolate can pass it straight to publishMessage.
Uint8Buffer generatePayloadBuffer(WorkerInput input, {Random? random}) {
  final bytes = generatePayloadUtf8(input, random: random);
  final buffer = Uint8Buffer(bytes.length);
  buffer.setRange(0, bytes.length, bytes);
  return buffer;
}
