import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

const String workerIpcPrefix = 'IOT_DEVKIT_IPC ';

typedef SimulatorProcessLauncher = Future<Process> Function(
  String executable,
  List<String> arguments,
);

typedef WorkerClusterListener = void Function(WorkerClusterSnapshot snapshot);

/// Raised when a coordinator stop request cancels an in-flight worker launch.
///
/// This is a normal lifecycle event rather than a worker failure. Callers use
/// the dedicated type to avoid turning an intentional stop into a failed run.
class SimulationProcessStartCancelled implements Exception {
  final String message;

  const SimulationProcessStartCancelled([
    this.message = 'Simulator process startup was cancelled.',
  ]);

  @override
  String toString() => message;
}

/// Immutable coordinator-side view of all sending worker processes.
class WorkerClusterSnapshot {
  final int expectedProcessCount;
  final int readyProcessCount;
  final int aliveProcessCount;
  final Map<int, WorkerProcessSnapshot> workers;
  final Map<String, dynamic> statistics;
  final String? error;

  const WorkerClusterSnapshot({
    required this.expectedProcessCount,
    required this.readyProcessCount,
    required this.aliveProcessCount,
    required this.workers,
    required this.statistics,
    this.error,
  });
}

class WorkerProcessSnapshot {
  final int shardIndex;
  final int shardCount;
  final int? pid;
  final bool accepted;
  final bool exited;
  final int? exitCode;
  final String state;
  final String? stateMessage;
  final String? error;
  final Map<String, dynamic> statistics;

  const WorkerProcessSnapshot({
    required this.shardIndex,
    required this.shardCount,
    required this.pid,
    required this.accepted,
    required this.exited,
    required this.exitCode,
    required this.state,
    required this.stateMessage,
    required this.error,
    required this.statistics,
  });
}

/// Starts and owns the hidden simulator workers for one automatic run.
///
/// Configuration is sent through the anonymous stdin pipe created by
/// [Process.start]. Passwords and certificate paths therefore never appear in
/// command-line arguments or temporary files. Worker stdout is an NDJSON
/// protocol; stderr is continuously drained so a chatty child cannot block.
class SimulationProcessSupervisor {
  final Logger _logger = Logger('SimulationProcessSupervisor');
  final SimulatorProcessLauncher _processLauncher;
  final Duration processLaunchTimeout;
  final Duration startupTimeout;
  final Duration stopTimeout;
  final int maxProcessCount;

  final Map<int, _ManagedWorker> _workers = {};
  WorkerClusterListener? _listener;
  Map<String, dynamic>? _config;
  int _expectedProcessCount = 0;
  bool _stopping = false;
  bool _starting = false;
  int _lifecycleGeneration = 0;
  Future<void>? _startCompletion;
  Future<void>? _stopOperation;
  String? _clusterError;

  SimulationProcessSupervisor({
    SimulatorProcessLauncher? processLauncher,
    this.processLaunchTimeout = const Duration(seconds: 10),
    this.startupTimeout = const Duration(seconds: 20),
    this.stopTimeout = const Duration(seconds: 8),
    this.maxProcessCount = 16,
  })  : assert(maxProcessCount >= 2),
        _processLauncher = processLauncher ?? _launchProcess;

  bool get isActive => _starting || _workers.isNotEmpty;

  static Future<Process> _launchProcess(
    String executable,
    List<String> arguments,
  ) {
    return Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.normal,
      runInShell: false,
    );
  }

  Future<void> start({
    required Map<String, dynamic> config,
    required int processCount,
    required WorkerClusterListener onSnapshot,
  }) async {
    if (processCount < 2) {
      throw ArgumentError.value(
        processCount,
        'processCount',
        'automatic worker mode requires at least two processes',
      );
    }
    if (processCount > maxProcessCount) {
      throw ArgumentError.value(
        processCount,
        'processCount',
        'automatic worker count exceeds the hard limit of $maxProcessCount',
      );
    }
    if (isActive || _stopping) {
      throw StateError('A worker cluster is already active.');
    }

    final generation = ++_lifecycleGeneration;
    final startCompletion = Completer<void>();
    final startCompletionFuture = startCompletion.future;
    _startCompletion = startCompletionFuture;
    _starting = true;
    _listener = onSnapshot;
    _config = Map<String, dynamic>.from(config);
    _expectedProcessCount = processCount;
    _stopping = false;
    _clusterError = null;

    try {
      for (var index = 0; index < processCount; index++) {
        final process = await _launchWorkerProcess([
          '--worker',
          '--shard=${index + 1}/$processCount',
          '--performance',
        ]);
        if (!_isGenerationActive(generation)) {
          await _terminateUnmanagedProcess(process);
          throw const SimulationProcessStartCancelled();
        }
        final worker = _ManagedWorker(
          shardIndex: index,
          shardCount: processCount,
          generation: generation,
          process: process,
        );
        _workers[index] = worker;
        _listenToWorker(worker);
      }

      _ensureGenerationActive(generation);
      _emitSnapshot();
      await Future.wait(_workers.values.map((worker) => worker.accepted.future))
          .timeout(startupTimeout);
      _ensureGenerationActive(generation);
      final failedWorkers = _workers.values
          .where((worker) =>
              worker.error != null || worker.exited || !worker.isAccepted)
          .toList(growable: false);
      if (failedWorkers.isNotEmpty) {
        throw StateError(
          '${failedWorkers.length}/$processCount simulator workers failed '
          'during startup.',
        );
      }
      _emitSnapshot();
    } catch (error) {
      if (error is SimulationProcessStartCancelled ||
          generation != _lifecycleGeneration) {
        throw const SimulationProcessStartCancelled();
      }
      _clusterError = 'Unable to start simulator workers: $error';
      _emitSnapshot();
      _lifecycleGeneration++;
      _stopping = true;
      try {
        await _shutdownWorkers(
          _workers.values
              .where((worker) => worker.generation == generation)
              .toList(growable: false),
          force: true,
        );
      } finally {
        _resetClusterStateIfEmpty();
        _stopping = false;
      }
      rethrow;
    } finally {
      _starting = false;
      if (!startCompletion.isCompleted) startCompletion.complete();
      if (identical(_startCompletion, startCompletionFuture)) {
        _startCompletion = null;
      }
    }
  }

  bool _isGenerationActive(int generation) =>
      !_stopping && generation == _lifecycleGeneration;

  Future<Process> _launchWorkerProcess(List<String> arguments) async {
    final launch = _processLauncher(Platform.resolvedExecutable, arguments);
    try {
      return await launch.timeout(processLaunchTimeout);
    } on TimeoutException {
      // Process.start cannot be cancelled. If the OS eventually returns a
      // process after our timeout, retain ownership long enough to kill it.
      unawaited(launch.then<void>(_terminateUnmanagedProcess).catchError(
        (Object error, StackTrace stack) {
          _logger.warning('Timed-out worker launch later failed: $error');
        },
      ));
      rethrow;
    }
  }

  void _ensureGenerationActive(int generation) {
    if (!_isGenerationActive(generation)) {
      throw const SimulationProcessStartCancelled();
    }
  }

  Future<void> _terminateUnmanagedProcess(Process process) async {
    final stdoutDrain = process.stdout.drain<void>().catchError((_) {});
    final stderrDrain = process.stderr.drain<void>().catchError((_) {});
    try {
      await process.stdin.close();
    } catch (_) {
      // The process may have already closed its anonymous input pipe.
    }
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      _logger
          .warning('A cancelled simulator worker did not exit after kill().');
    }
    try {
      await Future.wait([stdoutDrain, stderrDrain])
          .timeout(const Duration(seconds: 2));
    } on TimeoutException {
      _logger.warning('Cancelled worker pipes did not close after kill().');
    }
  }

  void _listenToWorker(_ManagedWorker worker) {
    worker.stdoutSubscription = worker.process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) => _handleWorkerLine(worker, line),
      onError: (Object error, StackTrace stack) {
        _recordWorkerError(worker, 'stdout error: $error');
      },
    );

    worker.stderrSubscription = worker.process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (line.trim().isNotEmpty) {
          _logger.warning('[worker ${worker.label}] $line');
        }
      },
      onError: (Object error, StackTrace stack) {
        _logger.warning('[worker ${worker.label}] stderr error: $error');
      },
    );

    unawaited(worker.process.exitCode.then((code) {
      worker.exited = true;
      worker.exitCode = code;
      if (!_isCurrentWorker(worker)) return;
      if (!_stopping && worker.generation == _lifecycleGeneration) {
        _recordWorkerError(
          worker,
          'worker exited unexpectedly with code $code',
        );
      } else {
        _emitSnapshot();
      }
    }));
  }

  void _handleWorkerLine(_ManagedWorker worker, String line) {
    if (!_isCurrentWorker(worker)) return;
    if (!line.startsWith(workerIpcPrefix)) {
      if (line.trim().isNotEmpty) {
        _logger.fine('[worker ${worker.label}] $line');
      }
      return;
    }

    try {
      final decoded = jsonDecode(line.substring(workerIpcPrefix.length));
      if (decoded is! Map) {
        throw const FormatException('IPC payload is not an object');
      }
      final message = Map<String, dynamic>.from(decoded);
      final type = message['type'];

      switch (type) {
        case 'hello':
          final reportedIndex = (message['shardIndex'] as num?)?.toInt();
          final reportedCount = (message['shardCount'] as num?)?.toInt();
          if (reportedIndex != worker.shardIndex ||
              reportedCount != worker.shardCount) {
            throw StateError(
              'worker reported shard $reportedIndex/$reportedCount, '
              'expected ${worker.shardIndex}/${worker.shardCount}',
            );
          }
          worker.pid = (message['pid'] as num?)?.toInt();
          if (!worker.startCommandSent) {
            worker.startCommandSent = true;
            _send(worker, {
              'type': 'start',
              'config': _config,
            });
          }
          break;
        case 'accepted':
          worker.isAccepted = true;
          if (!worker.accepted.isCompleted) {
            worker.accepted.complete();
          }
          break;
        case 'status':
          worker.state = message['state']?.toString() ?? worker.state;
          worker.stateMessage = message['stateMessage']?.toString();
          final rawStatistics = message['statistics'];
          if (rawStatistics is Map) {
            worker.statistics = Map<String, dynamic>.from(rawStatistics);
          }
          break;
        case 'stopped':
          worker.state = 'idle';
          worker.stopped = true;
          break;
        case 'fatal':
          _recordWorkerError(
            worker,
            message['error']?.toString() ?? 'unknown worker failure',
          );
          return;
        default:
          throw FormatException('Unknown worker IPC message type: $type');
      }
      _emitSnapshot();
    } catch (error) {
      _recordWorkerError(worker, 'invalid IPC message: $error');
    }
  }

  void _send(_ManagedWorker worker, Map<String, dynamic> message) {
    if (worker.exited) return;
    try {
      worker.process.stdin.writeln('$workerIpcPrefix${jsonEncode(message)}');
      unawaited(worker.process.stdin.flush().catchError((Object error) {
        if (!_stopping) {
          _recordWorkerError(worker, 'unable to flush command: $error');
        }
      }));
    } catch (error) {
      _recordWorkerError(worker, 'unable to send command: $error');
    }
  }

  void _recordWorkerError(_ManagedWorker worker, String error) {
    if (!_isCurrentWorker(worker)) return;
    worker.error = error;
    _clusterError ??= 'Worker ${worker.label}: $error';
    _logger.severe('Worker ${worker.label}: $error');
    if (!worker.accepted.isCompleted) {
      // Complete normally so an early worker failure cannot surface as an
      // unhandled asynchronous error before start() attaches Future.wait.
      // start() inspects worker.error immediately after the barrier.
      worker.accepted.complete();
    }
    _emitSnapshot();
  }

  bool _isCurrentWorker(_ManagedWorker worker) =>
      identical(_workers[worker.shardIndex], worker);

  void _emitSnapshot() {
    final listener = _listener;
    if (listener == null) return;

    final snapshots = <int, WorkerProcessSnapshot>{};
    for (final entry in _workers.entries) {
      final worker = entry.value;
      snapshots[entry.key] = WorkerProcessSnapshot(
        shardIndex: worker.shardIndex,
        shardCount: worker.shardCount,
        pid: worker.pid,
        accepted: worker.isAccepted,
        exited: worker.exited,
        exitCode: worker.exitCode,
        state: worker.state,
        stateMessage: worker.stateMessage,
        error: worker.error,
        statistics: Map<String, dynamic>.unmodifiable(worker.statistics),
      );
    }

    listener(WorkerClusterSnapshot(
      expectedProcessCount: _expectedProcessCount,
      readyProcessCount: _workers.values
          .where((worker) => worker.isAccepted && !worker.exited)
          .length,
      aliveProcessCount:
          _workers.values.where((worker) => !worker.exited).length,
      workers: Map<int, WorkerProcessSnapshot>.unmodifiable(snapshots),
      statistics: Map<String, dynamic>.unmodifiable(
        aggregateWorkerStatistics(snapshots.values),
      ),
      error: _clusterError,
    ));
  }

  Future<void> stop({bool force = false}) {
    final existing = _stopOperation;
    if (existing != null) return existing;

    final operation = _stopInternal(force: force);
    _stopOperation = operation;
    unawaited(operation.then<void>(
      (_) {
        if (identical(_stopOperation, operation)) _stopOperation = null;
      },
      onError: (Object _, StackTrace __) {
        if (identical(_stopOperation, operation)) _stopOperation = null;
      },
    ));
    return operation;
  }

  Future<void> _stopInternal({required bool force}) async {
    ++_lifecycleGeneration;
    _stopping = true;
    final startCompletion = _startCompletion;

    // Release an in-flight startup barrier immediately. The generation check
    // in start() converts the wake-up into a normal cancellation.
    for (final worker in _workers.values) {
      if (!worker.accepted.isCompleted) worker.accepted.complete();
    }

    try {
      await _shutdownWorkers(
        _workers.values.toList(growable: false),
        force: force,
      );
      if (startCompletion != null) {
        await startCompletion;
      }
    } finally {
      // A delayed Process.start may have returned while the first snapshot was
      // being shut down. start() kills that unmanaged process before completing
      // [startCompletion], so this final pass is normally empty but closes the
      // race deterministically.
      await _shutdownWorkers(
        _workers.values.toList(growable: false),
        force: true,
      );
      _resetClusterStateIfEmpty();
      _stopping = false;
    }
  }

  Future<void> _shutdownWorkers(
    List<_ManagedWorker> workers, {
    required bool force,
  }) async {
    if (workers.isEmpty) return;

    if (!force) {
      for (final worker in workers) {
        _send(worker, const {'type': 'stop'});
      }
    } else {
      for (final worker in workers) {
        if (!worker.exited) worker.process.kill();
      }
    }

    try {
      await Future.wait(workers.map((worker) => worker.process.exitCode))
          .timeout(force ? const Duration(seconds: 2) : stopTimeout);
    } on TimeoutException {
      for (final worker in workers) {
        if (!worker.exited) worker.process.kill();
      }
      try {
        await Future.wait(workers.map((worker) => worker.process.exitCode))
            .timeout(const Duration(seconds: 2));
      } on TimeoutException {
        _logger.warning('Some simulator workers did not exit after kill().');
      } catch (error) {
        _logger.warning('Unable to await killed simulator workers: $error');
      }
    } catch (error) {
      _logger.warning('Unable to await simulator workers: $error');
    } finally {
      for (final worker in workers) {
        await _cleanupWorker(worker);
      }
    }
  }

  Future<void> _cleanupWorker(_ManagedWorker worker) async {
    try {
      await worker.stdoutSubscription?.cancel();
    } catch (error) {
      _logger.fine('Unable to cancel ${worker.label} stdout: $error');
    }
    try {
      await worker.stderrSubscription?.cancel();
    } catch (error) {
      _logger.fine('Unable to cancel ${worker.label} stderr: $error');
    }
    try {
      await worker.process.stdin.close();
    } catch (error) {
      _logger.fine('Unable to close ${worker.label} stdin: $error');
    }
    if (_isCurrentWorker(worker)) {
      _workers.remove(worker.shardIndex);
    }
  }

  void _resetClusterStateIfEmpty() {
    if (_workers.isNotEmpty) return;
    _config = null;
    _expectedProcessCount = 0;
    _clusterError = null;
    _listener = null;
  }

  void dispose() {
    unawaited(stop(force: true));
  }
}

/// Sums raw worker snapshots without inventing values that workers do not
/// report. This is public for deterministic unit testing.
Map<String, dynamic> aggregateWorkerStatistics(
  Iterable<WorkerProcessSnapshot> workers,
) {
  final totals = <String, num>{
    'totalDevices': 0,
    'onlineDevices': 0,
    'totalMessages': 0,
    'successCount': 0,
    'failureCount': 0,
    'lateDroppedCount': 0,
    'generationErrorCount': 0,
    'totalPoints': 0,
    'totalBytes': 0,
    'totalLatency': 0,
    'latencySamples': 0,
    'currentTps': 0.0,
    'currentPointsPerSecond': 0.0,
    'currentBandwidth': 0.0,
    'memoryUsage': 0,
    'messageSize': 0,
  };

  const liveOnlyKeys = {
    'onlineDevices',
    'currentTps',
    'currentPointsPerSecond',
    'currentBandwidth',
    'memoryUsage',
  };

  for (final worker in workers) {
    final stats = worker.statistics;
    for (final key in totals.keys.toList(growable: false)) {
      if (worker.exited && liveOnlyKeys.contains(key)) continue;
      final value = stats[key];
      if (value is num) {
        if (key == 'messageSize') {
          if (value > totals[key]!) totals[key] = value;
        } else {
          totals[key] = totals[key]! + value;
        }
      }
    }
  }

  final latencySamples = totals['latencySamples']!.toInt();
  final totalLatency = totals['totalLatency']!.toInt();
  return <String, dynamic>{
    ...totals,
    'currentLatency': latencySamples == 0 ? 0.0 : totalLatency / latencySamples,
  };
}

class _ManagedWorker {
  final int shardIndex;
  final int shardCount;
  final int generation;
  final Process process;
  final Completer<void> accepted = Completer<void>();

  StreamSubscription<String>? stdoutSubscription;
  StreamSubscription<String>? stderrSubscription;
  int? pid;
  bool startCommandSent = false;
  bool isAccepted = false;
  bool stopped = false;
  bool exited = false;
  int? exitCode;
  String state = 'starting';
  String? stateMessage;
  String? error;
  Map<String, dynamic> statistics = const {};

  _ManagedWorker({
    required this.shardIndex,
    required this.shardCount,
    required this.generation,
    required this.process,
  });

  String get label => '${shardIndex + 1}/$shardCount';
}
