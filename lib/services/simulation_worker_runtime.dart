import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/process_shard.dart';
import 'mqtt_controller.dart';
import 'simulation_process_supervisor.dart';

class SimulationWorkerRuntime {
  final MqttController controller;
  final ProcessShard processShard;
  final Stream<List<int>> input;
  final IOSink output;

  final Completer<int> _done = Completer<int>();
  StreamSubscription<String>? _inputSubscription;
  Timer? _statusTimer;
  Future<void>? _shutdownFuture;
  Future<void> _pendingOutput = Future<void>.value();
  bool _startAccepted = false;

  SimulationWorkerRuntime({
    required this.controller,
    required this.processShard,
    Stream<List<int>>? input,
    IOSink? output,
  })  : input = input ?? stdin,
        output = output ?? stdout;

  Future<int> run() {
    _send({
      'type': 'hello',
      'pid': pid,
      'shardIndex': processShard.index,
      'shardCount': processShard.count,
    });

    _inputSubscription =
        input.transform(utf8.decoder).transform(const LineSplitter()).listen(
      _handleLine,
      onError: (Object error, StackTrace stack) {
        _send({'type': 'fatal', 'error': 'IPC input failed: $error'});
        unawaited(_shutdown(1));
      },
      onDone: () {
        // Anonymous stdin closes automatically if the GUI coordinator exits.
        unawaited(_shutdown(0));
      },
      cancelOnError: false,
    );
    return _done.future;
  }

  void _handleLine(String line) {
    if (!line.startsWith(workerIpcPrefix)) return;

    try {
      final decoded = jsonDecode(line.substring(workerIpcPrefix.length));
      if (decoded is! Map) {
        throw const FormatException('IPC payload is not an object');
      }
      final message = Map<String, dynamic>.from(decoded);
      switch (message['type']) {
        case 'start':
          if (_startAccepted) {
            throw StateError('worker received more than one start command');
          }
          final rawConfig = message['config'];
          if (rawConfig is! Map) {
            throw const FormatException('start command has no config object');
          }
          _startAccepted = true;
          _send(const {'type': 'accepted'});
          _statusTimer = Timer.periodic(
            const Duration(seconds: 1),
            (_) => _sendStatus(),
          );
          final config = Map<String, dynamic>.from(rawConfig);
          final startFuture = controller.start(config);
          _sendStatus();
          unawaited(startFuture.then((_) => _handleStartCompleted()).catchError(
            (Object error, StackTrace stack) {
              _send({
                'type': 'fatal',
                'error': 'Simulation start failed: $error'
              });
              return _shutdown(1);
            },
          ));
          break;
        case 'stop':
          unawaited(_shutdown(0));
          break;
        default:
          throw FormatException(
            'Unknown coordinator command: ${message['type']}',
          );
      }
    } catch (error) {
      _send({'type': 'fatal', 'error': 'Invalid coordinator command: $error'});
      unawaited(_shutdown(1));
    }
  }

  void _handleStartCompleted() {
    if (_shutdownFuture != null) return;
    if (controller.runState == SimulationRunState.failed ||
        controller.runState == SimulationRunState.idle) {
      _send({
        'type': 'fatal',
        'error': controller.runStateMessage ??
            'Simulation did not enter a runnable state.',
      });
      unawaited(_shutdown(1));
      return;
    }
    _sendStatus();
  }

  void _sendStatus() {
    _send({
      'type': 'status',
      'state': controller.runState.name,
      'stateMessage': controller.runStateMessage,
      'statistics': controller.statisticsCollector.getSnapshot(),
    });
  }

  void _send(Map<String, dynamic> message) {
    final line = '$workerIpcPrefix${jsonEncode(message)}';
    _pendingOutput = _pendingOutput.then((_) async {
      output.writeln(line);
      await output.flush();
    }).catchError((_) {
      // A broken output pipe means the coordinator is gone. stdin onDone will
      // drive the normal shutdown path; there is nowhere left to report to.
    });
  }

  Future<void> _shutdown(int exitCode) {
    return _shutdownFuture ??= _shutdownInternal(exitCode);
  }

  Future<void> _shutdownInternal(int exitCode) async {
    _statusTimer?.cancel();
    if (controller.isRunning || controller.isBusy) {
      await controller.stop();
    }
    _sendStatus();
    _send(const {'type': 'stopped'});
    await _pendingOutput;
    await _inputSubscription?.cancel();
    if (!_done.isCompleted) _done.complete(exitCode);
  }
}
