import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/services/mqtt_controller.dart';
import 'package:iot_devkit/services/simulation_process_supervisor.dart';

void main() {
  test('aggregates cumulative and live statistics from worker shards', () {
    final aggregate = aggregateWorkerStatistics([
      _worker(
        index: 0,
        statistics: {
          'totalDevices': 667,
          'onlineDevices': 667,
          'totalMessages': 100,
          'successCount': 99,
          'failureCount': 1,
          'totalPoints': 1000,
          'totalBytes': 2048,
          'totalLatency': 20,
          'latencySamples': 2,
          'currentTps': 1000.0,
          'currentPointsPerSecond': 266800.0,
          'currentBandwidth': 20.0,
          'memoryUsage': 80 * 1024 * 1024,
          'messageSize': 8000,
        },
      ),
      _worker(
        index: 1,
        statistics: {
          'totalDevices': 667,
          'onlineDevices': 666,
          'totalMessages': 200,
          'successCount': 200,
          'failureCount': 0,
          'totalPoints': 2000,
          'totalBytes': 4096,
          'totalLatency': 90,
          'latencySamples': 3,
          'currentTps': 1100.0,
          'currentPointsPerSecond': 266800.0,
          'currentBandwidth': 30.0,
          'memoryUsage': 82 * 1024 * 1024,
          'messageSize': 8200,
        },
      ),
    ]);

    expect(aggregate['totalDevices'], 1334);
    expect(aggregate['onlineDevices'], 1333);
    expect(aggregate['totalMessages'], 300);
    expect(aggregate['successCount'], 299);
    expect(aggregate['failureCount'], 1);
    expect(aggregate['totalPoints'], 3000);
    expect(aggregate['currentPointsPerSecond'], 533600);
    expect(aggregate['memoryUsage'], 162 * 1024 * 1024);
    expect(aggregate['messageSize'], 8200);
    expect(aggregate['currentLatency'], 22);
  });

  test('exited workers keep cumulative totals but no live statistics', () {
    final aggregate = aggregateWorkerStatistics([
      _worker(
        index: 0,
        exited: true,
        exitCode: 0,
        statistics: {
          'totalDevices': 667,
          'onlineDevices': 667,
          'totalMessages': 100,
          'successCount': 99,
          'totalPoints': 1000,
          'currentTps': 1000.0,
          'currentPointsPerSecond': 266800.0,
          'currentBandwidth': 20.0,
          'memoryUsage': 80 * 1024 * 1024,
        },
      ),
    ]);

    expect(aggregate['totalDevices'], 667);
    expect(aggregate['totalMessages'], 100);
    expect(aggregate['successCount'], 99);
    expect(aggregate['totalPoints'], 1000);
    expect(aggregate['onlineDevices'], 0);
    expect(aggregate['currentTps'], 0);
    expect(aggregate['currentPointsPerSecond'], 0);
    expect(aggregate['currentBandwidth'], 0);
    expect(aggregate['memoryUsage'], 0);
  });

  test('hard process limit rejects a launch before creating workers', () async {
    var launches = 0;
    final supervisor = SimulationProcessSupervisor(
      maxProcessCount: 2,
      processLauncher: (_, __) async {
        launches++;
        throw StateError('must not launch');
      },
    );
    addTearDown(supervisor.dispose);

    await expectLater(
      supervisor.start(
        config: const {},
        processCount: 3,
        onSnapshot: (_) {},
      ),
      throwsArgumentError,
    );
    expect(launches, 0);
    expect(supervisor.isActive, isFalse);
  });

  test('stop cancels a delayed worker launch without leaving a process',
      () async {
    final launch = Completer<Process>();
    final supervisor = SimulationProcessSupervisor(
      processLauncher: (_, __) => launch.future,
    );
    addTearDown(supervisor.dispose);

    final start = supervisor.start(
      config: const {},
      processCount: 2,
      onSnapshot: (_) {},
    );
    final stop = supervisor.stop(force: true);
    final process = _FakeWorkerProcess(shardIndex: 0, shardCount: 2);
    launch.complete(process);

    await expectLater(start, throwsA(isA<SimulationProcessStartCancelled>()));
    await stop;
    expect(process.wasKilled, isTrue);
    expect(supervisor.isActive, isFalse);
  });

  test('stop completes when the operating system worker launch hangs',
      () async {
    final launch = Completer<Process>();
    final supervisor = SimulationProcessSupervisor(
      processLauncher: (_, __) => launch.future,
      processLaunchTimeout: const Duration(milliseconds: 40),
    );
    addTearDown(supervisor.dispose);

    final start = supervisor.start(
      config: const {},
      processCount: 2,
      onSnapshot: (_) {},
    );
    final stop = supervisor.stop(force: true);

    await expectLater(start, throwsA(isA<SimulationProcessStartCancelled>()));
    await stop.timeout(const Duration(seconds: 1));
    expect(supervisor.isActive, isFalse);

    final lateProcess = _FakeWorkerProcess(shardIndex: 0, shardCount: 2);
    launch.complete(lateProcess);
    await _eventually(() => lateProcess.wasKilled);
  });

  test('unexpected exit code zero is failed and removed from ready count',
      () async {
    final processes = <_FakeWorkerProcess>[];
    WorkerClusterSnapshot? latest;
    final supervisor = SimulationProcessSupervisor(
      processLauncher: (_, arguments) async {
        final shard = arguments
            .firstWhere((argument) => argument.startsWith('--shard='))
            .substring('--shard='.length)
            .split('/');
        final process = _FakeWorkerProcess(
          shardIndex: int.parse(shard[0]) - 1,
          shardCount: int.parse(shard[1]),
        );
        processes.add(process);
        return process;
      },
    );
    addTearDown(supervisor.dispose);

    await supervisor.start(
      config: const {},
      processCount: 2,
      onSnapshot: (snapshot) => latest = snapshot,
    );
    expect(latest?.readyProcessCount, 2);

    processes.first.completeExit(0);
    await _eventually(() => latest?.aliveProcessCount == 1);

    expect(latest?.readyProcessCount, 1);
    expect(latest?.workers[0]?.error, contains('unexpectedly'));
    expect(latest?.error, contains('exited unexpectedly with code 0'));
  });

  test('a partial launcher failure is cleaned and the cluster can restart',
      () async {
    var launchCount = 0;
    final processes = <_FakeWorkerProcess>[];
    final supervisor = SimulationProcessSupervisor(
      processLauncher: (_, arguments) async {
        launchCount++;
        if (launchCount == 2) throw StateError('synthetic launch failure');
        final shard = arguments
            .firstWhere((argument) => argument.startsWith('--shard='))
            .substring('--shard='.length)
            .split('/');
        final process = _FakeWorkerProcess(
          shardIndex: int.parse(shard[0]) - 1,
          shardCount: int.parse(shard[1]),
        );
        processes.add(process);
        return process;
      },
    );
    addTearDown(supervisor.dispose);

    await expectLater(
      supervisor.start(
        config: const {},
        processCount: 2,
        onSnapshot: (_) {},
      ),
      throwsA(isA<StateError>()),
    );
    expect(processes.single.wasKilled, isTrue);
    expect(supervisor.isActive, isFalse);

    await supervisor.start(
      config: const {},
      processCount: 2,
      onSnapshot: (_) {},
    );
    expect(supervisor.isActive, isTrue);
    await supervisor.stop();
    expect(supervisor.isActive, isFalse);
  });

  test('controller routes an 800k peak through three supervised workers',
      () async {
    final supervisor = _FakeProcessSupervisor();
    final controller = MqttController(
      initializeWorkers: false,
      processSupervisor: supervisor,
    );
    addTearDown(controller.dispose);

    await controller.start(_reportedAdvancedConfig());

    expect(supervisor.startedProcessCount, 3);
    expect(controller.isMultiProcess, isTrue);
    expect(controller.activeProcessCount, 3);
    expect(controller.readyProcessCount, 3);
    expect(controller.runState, SimulationRunState.running);
    expect(controller.statisticsCollector.totalDevices, 2000);
    expect(controller.statisticsCollector.onlineDevices, 2000);
    expect(
      controller.statisticsCollector.currentPointsPerSecond,
      800000,
    );

    await controller.stop();
    expect(supervisor.stopCalls, 1);
    expect(controller.runState, SimulationRunState.idle);
    expect(controller.isMultiProcess, isFalse);
  });

  test('controller blocks a load that device sharding cannot satisfy',
      () async {
    final supervisor = _FakeProcessSupervisor();
    final controller = MqttController(
      initializeWorkers: false,
      processSupervisor: supervisor,
    );
    addTearDown(controller.dispose);

    await controller.start({
      'mode': 'basic',
      'device_start_number': 7,
      'device_end_number': 7,
      'send_interval': 1,
      'data': {'data_point_count': 600001},
    });

    expect(controller.runState, SimulationRunState.failed);
    expect(controller.runStateMessage, contains('cannot be kept below'));
    expect(supervisor.startCalls, 0);
  });

  test('controller cleans an all-exited cluster and can start again', () async {
    final supervisor = _FakeProcessSupervisor();
    final controller = MqttController(
      initializeWorkers: false,
      processSupervisor: supervisor,
    );
    addTearDown(controller.dispose);

    await controller.start(_reportedAdvancedConfig());
    supervisor.failAll();
    await _eventually(
      () =>
          controller.runState == SimulationRunState.failed &&
          !controller.isMultiProcess &&
          !supervisor.isActive,
    );

    await controller.start(_reportedAdvancedConfig());
    expect(supervisor.startCalls, 2);
    expect(controller.runState, SimulationRunState.running);
  });

  test('controller cleans a live worker in failed state and can start again',
      () async {
    final supervisor = _FakeProcessSupervisor();
    final controller = MqttController(
      initializeWorkers: false,
      processSupervisor: supervisor,
    );
    addTearDown(controller.dispose);

    await controller.start(_reportedAdvancedConfig());
    supervisor.failOneAlive();
    await _eventually(
      () =>
          controller.runState == SimulationRunState.failed &&
          !controller.isMultiProcess &&
          !supervisor.isActive,
    );

    await controller.start(_reportedAdvancedConfig());
    expect(supervisor.startCalls, 2);
    expect(controller.runState, SimulationRunState.running);
  });
}

WorkerProcessSnapshot _worker({
  required int index,
  required Map<String, dynamic> statistics,
  bool exited = false,
  int? exitCode,
}) {
  return WorkerProcessSnapshot(
    shardIndex: index,
    shardCount: 3,
    pid: 100 + index,
    accepted: true,
    exited: exited,
    exitCode: exitCode,
    state: 'running',
    stateMessage: null,
    error: null,
    statistics: statistics,
  );
}

class _FakeProcessSupervisor extends SimulationProcessSupervisor {
  bool _active = false;
  int? startedProcessCount;
  int startCalls = 0;
  int stopCalls = 0;
  WorkerClusterListener? _listener;

  @override
  bool get isActive => _active;

  @override
  Future<void> start({
    required Map<String, dynamic> config,
    required int processCount,
    required WorkerClusterListener onSnapshot,
  }) async {
    _active = true;
    startCalls++;
    startedProcessCount = processCount;
    _listener = onSnapshot;
    final workers = <int, WorkerProcessSnapshot>{};
    for (var index = 0; index < processCount; index++) {
      workers[index] = _worker(
        index: index,
        statistics: {
          'totalDevices': index == 2 ? 666 : 667,
          'onlineDevices': index == 2 ? 666 : 667,
          'currentPointsPerSecond': index == 2 ? 266400.0 : 266800.0,
          'memoryUsage': 80 * 1024 * 1024,
        },
      );
    }
    onSnapshot(WorkerClusterSnapshot(
      expectedProcessCount: processCount,
      readyProcessCount: processCount,
      aliveProcessCount: processCount,
      workers: workers,
      statistics: aggregateWorkerStatistics(workers.values),
    ));
  }

  @override
  Future<void> stop({bool force = false}) async {
    stopCalls++;
    _active = false;
  }

  void failAll() {
    final listener = _listener;
    if (listener == null || startedProcessCount == null) return;
    final count = startedProcessCount!;
    final workers = <int, WorkerProcessSnapshot>{
      for (var index = 0; index < count; index++)
        index: WorkerProcessSnapshot(
          shardIndex: index,
          shardCount: count,
          pid: 100 + index,
          accepted: true,
          exited: true,
          exitCode: 0,
          state: 'running',
          stateMessage: null,
          error: 'worker exited unexpectedly with code 0',
          statistics: const {},
        ),
    };
    listener(WorkerClusterSnapshot(
      expectedProcessCount: count,
      readyProcessCount: 0,
      aliveProcessCount: 0,
      workers: workers,
      statistics: aggregateWorkerStatistics(workers.values),
      error: 'All workers exited unexpectedly.',
    ));
  }

  void failOneAlive() {
    final listener = _listener;
    if (listener == null || startedProcessCount == null) return;
    final count = startedProcessCount!;
    final workers = <int, WorkerProcessSnapshot>{
      for (var index = 0; index < count; index++)
        index: WorkerProcessSnapshot(
          shardIndex: index,
          shardCount: count,
          pid: 100 + index,
          accepted: true,
          exited: false,
          exitCode: null,
          state: index == 0 ? 'failed' : 'running',
          stateMessage: index == 0 ? 'synthetic worker failure' : null,
          error: null,
          statistics: const {},
        ),
    };
    listener(WorkerClusterSnapshot(
      expectedProcessCount: count,
      readyProcessCount: count,
      aliveProcessCount: count,
      workers: workers,
      statistics: aggregateWorkerStatistics(workers.values),
      error: 'Worker 1/$count entered failed state.',
    ));
  }
}

Future<void> _eventually(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > timeout) {
      fail('Condition was not satisfied within $timeout.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _FakeWorkerProcess implements Process {
  static int _nextPid = 1000;

  final int shardIndex;
  final int shardCount;
  final int _pid = _nextPid++;
  final StreamController<List<int>> _stdout = StreamController<List<int>>();
  final StreamController<List<int>> _stderr = StreamController<List<int>>();
  final _InputConsumer _input = _InputConsumer();
  final Completer<int> _exitCode = Completer<int>();
  late final IOSink _stdin = IOSink(_input);
  late final StreamSubscription<String> _inputSubscription;
  bool wasKilled = false;

  _FakeWorkerProcess({required this.shardIndex, required this.shardCount}) {
    _inputSubscription = _input.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleCommand);
    scheduleMicrotask(() {
      _send({
        'type': 'hello',
        'pid': _pid,
        'shardIndex': shardIndex,
        'shardCount': shardCount,
      });
    });
  }

  void _handleCommand(String line) {
    if (!line.startsWith(workerIpcPrefix)) return;
    final message = Map<String, dynamic>.from(
      jsonDecode(line.substring(workerIpcPrefix.length)) as Map,
    );
    switch (message['type']) {
      case 'start':
        _send(const {'type': 'accepted'});
        _send(const {
          'type': 'status',
          'state': 'running',
          'statistics': <String, dynamic>{},
        });
        break;
      case 'stop':
        _send(const {'type': 'stopped'});
        completeExit(0);
        break;
    }
  }

  void _send(Map<String, dynamic> message) {
    if (_stdout.isClosed) return;
    _stdout.add(utf8.encode('$workerIpcPrefix${jsonEncode(message)}\n'));
  }

  void completeExit(int code) {
    if (_exitCode.isCompleted) return;
    _exitCode.complete(code);
    unawaited(_inputSubscription.cancel());
    unawaited(_stdout.close());
    unawaited(_stderr.close());
  }

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  int get pid => _pid;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  IOSink get stdin => _stdin;

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    wasKilled = true;
    completeExit(-1);
    return true;
  }
}

class _InputConsumer implements StreamConsumer<List<int>> {
  final StreamController<List<int>> _controller = StreamController<List<int>>();

  Stream<List<int>> get stream => _controller.stream;

  @override
  Future<void> addStream(Stream<List<int>> stream) =>
      _controller.addStream(stream);

  @override
  Future<void> close() => _controller.close();
}

Map<String, dynamic> _reportedAdvancedConfig() {
  return {
    'mode': 'advanced',
    'mqtt': {
      'host': '127.0.0.1',
      'port': 1883,
      'topic': 'v1/devices/me/telemetry',
      'qos': 0,
      'enable_ssl': false,
    },
    'groups': [
      {
        'id': 'reported',
        'name': 'Reported Load',
        'startDeviceNumber': 1,
        'endDeviceNumber': 2000,
        'clientIdPrefix': 'c',
        'usernamePrefix': 'c',
        'passwordPrefix': 'c',
        'format': 'timestamped',
        'totalKeyCount': 500,
        'changeRatio': 0.3,
        'changeIntervalSeconds': 1,
        'fullIntervalSeconds': 300,
        'customKeys': <Map<String, dynamic>>[],
      },
    ],
    'subscriptions': <Map<String, dynamic>>[],
  };
}
