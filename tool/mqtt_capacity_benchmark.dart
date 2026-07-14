import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:iot_devkit/models/payload_format.dart';
import 'package:iot_devkit/utils/isolate_worker.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

const int _usageExitCode = 64;
const int _capacityFailedExitCode = 2;

const String _usage = '''
IoT DevKit MQTT capacity benchmark

Usage:
  dart run tool/mqtt_capacity_benchmark.dart [options]

Options:
  --host HOST                       Broker host (default: 127.0.0.1)
  --port PORT                       Broker port (default: 18884)
  --clients N                       Simulated MQTT clients (default: 2000)
  --keys N                          Keys in a full report (default: 500)
  --change-ratio R                  Change-report ratio, 0 < R < 1 (default: 0.3)
  --change-interval-seconds N       Change cadence (default: 1)
  --full-interval-seconds N         Full cadence; use 10 for a short test (default: 10)
  --duration-seconds N              Test duration; must cover two full bursts (default: 14)
  --bucket-ms N                     Scheduling bucket size (default: 50)
  --connect-concurrency N           Concurrent MQTT connects (default: 100)
  --connect-timeout-ms N            Per-client connect timeout (default: 3000)
  --drain-timeout-seconds N         Pending publish drain timeout (default: 30)
  --settle-ms N                     Network settle time before disconnect (default: 250)
  --prefix TEXT                     Unique client/topic prefix
  --topic TOPIC                     Publish topic (default: benchmark/<prefix>)
  --qos N                           MQTT QoS 0, 1, or 2 (default: 0)
  --username-prefix TEXT            Optional username prefix; suffix is 1-based device number
  --password-prefix TEXT            Optional password prefix; suffix is 1-based device number
  --self-check                      Run argument and early-failure self-checks
  --help                            Show this help

Exit codes:
  0   Capacity criteria passed
  1   Runtime or broker error
  2   Benchmark completed but capacity criteria failed
  64  Invalid command-line arguments
  130 Interrupted
''';

Future<void> main(List<String> arguments) async {
  if (arguments.length == 1 && arguments.single == '--self-check') {
    exit(_runSelfCheck() ? 0 : 1);
  }

  BenchmarkConfig config;
  try {
    config = BenchmarkConfig.parse(arguments);
  } on _HelpRequested {
    stdout.write(_usage);
    exit(0);
  } on FormatException catch (error) {
    stderr.writeln('Argument error: ${error.message}');
    stderr.writeln();
    stderr.write(_usage);
    exit(_usageExitCode);
  }

  final runner = CapacityBenchmark(config);
  final signalSubscriptions = <StreamSubscription<ProcessSignal>>[];
  var interrupted = false;

  void handleSignal(ProcessSignal signal) {
    if (interrupted) return;
    interrupted = true;
    stderr.writeln('Received $signal; stopping after in-flight work drains.');
    runner.requestStop();
  }

  for (final signal in <ProcessSignal>[
    ProcessSignal.sigint,
    ProcessSignal.sigterm,
  ]) {
    try {
      signalSubscriptions.add(signal.watch().listen(handleSignal));
    } on SignalException {
      // Some signals are unavailable on Windows. SIGINT remains sufficient for
      // an interactive stop, and normal process shutdown still reaches finally.
    }
  }

  var resultCode = 1;
  try {
    final outcome = await runner.run();
    stdout.writeln(jsonEncode(outcome.json));
    resultCode = outcome.passed ? 0 : _capacityFailedExitCode;
  } catch (error, stackTrace) {
    stderr.writeln('Benchmark failed: $error');
    stderr.writeln(stackTrace);
    resultCode = 1;
  } finally {
    await runner.close();
    for (final subscription in signalSubscriptions) {
      await subscription.cancel();
    }
  }

  exit(interrupted ? 130 : resultCode);
}

class BenchmarkConfig {
  static const Set<String> _valueOptions = {
    '--host',
    '--port',
    '--clients',
    '--keys',
    '--change-ratio',
    '--change-interval-seconds',
    '--full-interval-seconds',
    '--duration-seconds',
    '--bucket-ms',
    '--connect-concurrency',
    '--connect-timeout-ms',
    '--drain-timeout-seconds',
    '--settle-ms',
    '--prefix',
    '--topic',
    '--qos',
    '--username-prefix',
    '--password-prefix',
  };

  final String host;
  final int port;
  final int clients;
  final int keys;
  final double changeRatio;
  final int changeIntervalSeconds;
  final int fullIntervalSeconds;
  final int durationSeconds;
  final int bucketMs;
  final int connectConcurrency;
  final int connectTimeoutMs;
  final int drainTimeoutSeconds;
  final int settleMs;
  final String prefix;
  final String topic;
  final int qos;
  final String? usernamePrefix;
  final String? passwordPrefix;

  const BenchmarkConfig({
    required this.host,
    required this.port,
    required this.clients,
    required this.keys,
    required this.changeRatio,
    required this.changeIntervalSeconds,
    required this.fullIntervalSeconds,
    required this.durationSeconds,
    required this.bucketMs,
    required this.connectConcurrency,
    required this.connectTimeoutMs,
    required this.drainTimeoutSeconds,
    required this.settleMs,
    required this.prefix,
    required this.topic,
    required this.qos,
    required this.usernamePrefix,
    required this.passwordPrefix,
  });

  factory BenchmarkConfig.parse(List<String> arguments) {
    if (arguments.contains('--help')) throw const _HelpRequested();

    final values = <String, String>{};
    for (var index = 0; index < arguments.length; index++) {
      final option = arguments[index];
      if (!_valueOptions.contains(option)) {
        throw FormatException('Unknown option: $option');
      }
      if (values.containsKey(option)) {
        throw FormatException('Option specified more than once: $option');
      }
      if (index + 1 >= arguments.length ||
          arguments[index + 1].startsWith('--')) {
        throw FormatException('Missing value for $option');
      }
      values[option] = arguments[++index];
    }

    int readInt(String option, int fallback) {
      final raw = values[option];
      if (raw == null) return fallback;
      final parsed = int.tryParse(raw);
      if (parsed == null) {
        throw FormatException('$option must be an integer, got "$raw"');
      }
      return parsed;
    }

    double readDouble(String option, double fallback) {
      final raw = values[option];
      if (raw == null) return fallback;
      final parsed = double.tryParse(raw);
      if (parsed == null || !parsed.isFinite) {
        throw FormatException('$option must be a finite number, got "$raw"');
      }
      return parsed;
    }

    final prefix = values['--prefix'] ??
        'capacity_${pid}_${DateTime.now().millisecondsSinceEpoch}';
    final config = BenchmarkConfig(
      host: values['--host'] ?? '127.0.0.1',
      port: readInt('--port', 18884),
      clients: readInt('--clients', 2000),
      keys: readInt('--keys', 500),
      changeRatio: readDouble('--change-ratio', 0.3),
      changeIntervalSeconds: readInt('--change-interval-seconds', 1),
      fullIntervalSeconds: readInt('--full-interval-seconds', 10),
      durationSeconds: readInt('--duration-seconds', 14),
      bucketMs: readInt('--bucket-ms', 50),
      connectConcurrency: readInt('--connect-concurrency', 100),
      connectTimeoutMs: readInt('--connect-timeout-ms', 3000),
      drainTimeoutSeconds: readInt('--drain-timeout-seconds', 30),
      settleMs: readInt('--settle-ms', 250),
      prefix: prefix,
      topic: values['--topic'] ?? 'benchmark/$prefix',
      qos: readInt('--qos', 0),
      usernamePrefix: values['--username-prefix'],
      passwordPrefix: values['--password-prefix'],
    );
    config.validate();
    return config;
  }

  int get changePointCount => (keys * changeRatio).floor();
  int get changeIntervalMs => changeIntervalSeconds * 1000;
  int get fullIntervalMs => fullIntervalSeconds * 1000;
  int get durationMs => durationSeconds * 1000;
  int get changeStaggerMs => min(changeIntervalMs, 2000);
  int get fullStaggerMs => min(fullIntervalMs, 2000);

  void validate() {
    void inRange(String name, int value, int minimum, int maximum) {
      if (value < minimum || value > maximum) {
        throw FormatException(
          '$name must be in $minimum..$maximum, got $value',
        );
      }
    }

    if (host.trim().isEmpty) {
      throw const FormatException('--host cannot be empty');
    }
    inRange('--port', port, 1, 65535);
    inRange('--clients', clients, 1, 100000);
    inRange('--keys', keys, 1, 100000);
    inRange('--change-interval-seconds', changeIntervalSeconds, 1, 3600);
    inRange('--full-interval-seconds', fullIntervalSeconds, 2, 86400);
    inRange('--duration-seconds', durationSeconds, 1, 86400);
    inRange('--bucket-ms', bucketMs, 1, 1000);
    inRange('--connect-concurrency', connectConcurrency, 1, 1000);
    inRange('--connect-timeout-ms', connectTimeoutMs, 100, 60000);
    inRange('--drain-timeout-seconds', drainTimeoutSeconds, 1, 300);
    inRange('--settle-ms', settleMs, 0, 10000);
    inRange('--qos', qos, 0, 2);

    if (changeRatio <= 0 || changeRatio >= 1) {
      throw FormatException(
        '--change-ratio must be greater than 0 and less than 1, got '
        '$changeRatio',
      );
    }
    if (changePointCount < 1) {
      throw const FormatException(
        '--keys * --change-ratio must produce at least one changed key',
      );
    }
    if (changeIntervalSeconds >= fullIntervalSeconds) {
      throw const FormatException(
        '--change-interval-seconds must be less than '
        '--full-interval-seconds',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(prefix)) {
      throw const FormatException(
        '--prefix may contain only letters, digits, dot, underscore, and dash',
      );
    }
    if (topic.trim().isEmpty || topic.contains('#') || topic.contains('+')) {
      throw const FormatException(
        '--topic must be a non-empty publish topic without MQTT wildcards',
      );
    }
    if ((usernamePrefix == null) != (passwordPrefix == null)) {
      throw const FormatException(
        '--username-prefix and --password-prefix must be supplied together',
      );
    }

    for (final entry in <String, int>{
      'change interval': changeIntervalMs,
      'full interval': fullIntervalMs,
      'duration': durationMs,
      'change stagger window': changeStaggerMs,
      'full stagger window': fullStaggerMs,
    }.entries) {
      if (entry.value % bucketMs != 0) {
        throw FormatException(
          '--bucket-ms ($bucketMs) must divide the ${entry.key} '
          '(${entry.value}ms)',
        );
      }
    }

    final minimumDurationMs = fullIntervalMs + fullStaggerMs;
    if (durationMs < minimumDurationMs) {
      throw FormatException(
        '--duration-seconds must be at least '
        '${(minimumDurationMs / 1000).ceil()} to include two complete full '
        'bursts',
      );
    }
  }

  Map<String, Object?> publicJson() => {
        'host': host,
        'port': port,
        'clients': clients,
        'keys': keys,
        'changeRatio': changeRatio,
        'changePointCount': changePointCount,
        'changeIntervalSeconds': changeIntervalSeconds,
        'fullIntervalSeconds': fullIntervalSeconds,
        'durationSeconds': durationSeconds,
        'bucketMs': bucketMs,
        'connectConcurrency': connectConcurrency,
        'qos': qos,
        'prefix': prefix,
        'topic': topic,
        'authenticated': usernamePrefix != null,
        'historicalOverlapStress': true,
      };
}

class CapacityBenchmark {
  final BenchmarkConfig config;
  late final List<MqttServerClient?> _clients;

  bool _stopRequested = false;
  bool _workersInitialized = false;
  bool _closed = false;

  int _nextClient = 0;
  int _connectFailures = 0;
  String? _firstConnectError;
  String? _firstPublishError;

  late List<bool> _changeBusy;
  late List<bool> _fullBusy;
  late List<Map<String, int>> _perSecond;
  final List<int> _latencyUs = [];

  int _pending = 0;
  int _offered = 0;
  int _offeredPoints = 0;
  int _scheduled = 0;
  int _published = 0;
  int _publishedPoints = 0;
  int _publishFailures = 0;
  int _skippedBusy = 0;
  int _skippedBusyPoints = 0;
  int _schedulerLateBuckets = 0;
  int _maxSchedulerLatenessUs = 0;
  int _payloadBytes = 0;
  double _connectSeconds = 0;
  double _runSeconds = 0;
  double _drainSeconds = 0;

  late DateTime _runEpoch;

  CapacityBenchmark(this.config) {
    _clients = List<MqttServerClient?>.filled(config.clients, null);
    _changeBusy = List<bool>.filled(config.clients, false);
    _fullBusy = List<bool>.filled(config.clients, false);
    _perSecond = _emptyPerSecondRows();
  }

  void requestStop() {
    _stopRequested = true;
  }

  BenchmarkOutcome earlyFailureOutcomeForSelfCheck() {
    return _outcome(aborted: true);
  }

  Future<BenchmarkOutcome> run() async {
    await _preflightBroker();
    await PersistentIsolateManager.instance.init();
    if (!PersistentIsolateManager.instance.isReady) {
      throw StateError('Payload isolate pool failed to initialize');
    }
    _workersInitialized = true;

    await _connectAllClients();
    final connected = _connectedCount;
    stdout.writeln(jsonEncode({
      'event': 'connected',
      'connected': connected,
      'connectFailures': _connectFailures,
      'connectSeconds': _connectSeconds,
      'rssBytes': ProcessInfo.currentRss,
      'config': config.publicJson(),
      if (_firstConnectError != null) 'firstConnectError': _firstConnectError,
    }));

    if (_stopRequested || connected != config.clients) {
      return _outcome(aborted: true);
    }

    _perSecond = _emptyPerSecondRows();

    final changeSlots = _buildStaggerSlots(
      windowMs: config.changeStaggerMs,
      salt: 12345,
    );
    final fullSlots = _buildStaggerSlots(
      windowMs: config.fullStaggerMs,
      salt: 0,
    );

    _runEpoch = DateTime.now();
    final bucketCount = config.durationMs ~/ config.bucketMs;
    final changeCycleBuckets = config.changeIntervalMs ~/ config.bucketMs;
    final fullCycleBuckets = config.fullIntervalMs ~/ config.bucketMs;

    for (var bucket = 0; bucket < bucketCount && !_stopRequested; bucket++) {
      final target = _runEpoch.add(
        Duration(milliseconds: bucket * config.bucketMs),
      );
      await _waitUntil(target);
      if (_stopRequested) break;

      final latenessUs = DateTime.now().difference(target).inMicroseconds;
      if (latenessUs > 20000) _schedulerLateBuckets++;
      _maxSchedulerLatenessUs = max(_maxSchedulerLatenessUs, latenessUs);

      final changePosition = bucket % changeCycleBuckets;
      if (changePosition < changeSlots.length) {
        for (final index in changeSlots[changePosition]) {
          _offer(
            index: index,
            pointCount: config.changePointCount,
            full: false,
            target: target,
          );
        }
      }

      final fullPosition = bucket % fullCycleBuckets;
      if (fullPosition < fullSlots.length) {
        for (final index in fullSlots[fullPosition]) {
          _offer(
            index: index,
            pointCount: config.keys,
            full: true,
            target: target,
          );
        }
      }
    }

    if (!_stopRequested) {
      await _waitUntil(
        _runEpoch.add(Duration(seconds: config.durationSeconds)),
      );
    }

    final drainWatch = Stopwatch()..start();
    final drainLimit = Duration(seconds: config.drainTimeoutSeconds);
    while (_pending > 0 && drainWatch.elapsed < drainLimit) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    drainWatch.stop();
    _drainSeconds = drainWatch.elapsedMicroseconds / 1000000;
    _runSeconds = DateTime.now().difference(_runEpoch).inMicroseconds / 1000000;

    if (config.settleMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: config.settleMs));
    }
    return _outcome(aborted: _stopRequested);
  }

  List<Map<String, int>> _emptyPerSecondRows() {
    return List.generate(
      config.durationSeconds + config.drainTimeoutSeconds + 2,
      (_) => <String, int>{
        'changeMessages': 0,
        'fullMessages': 0,
        'changePoints': 0,
        'fullPoints': 0,
        'bytes': 0,
      },
    );
  }

  Future<void> _preflightBroker() async {
    final socket = await Socket.connect(
      config.host,
      config.port,
      timeout: Duration(milliseconds: config.connectTimeoutMs),
    );
    socket.destroy();
  }

  Future<void> _connectAllClients() async {
    final watch = Stopwatch()..start();

    Future<void> worker() async {
      while (!_stopRequested) {
        final index = _nextClient++;
        if (index >= config.clients) return;
        await _connectClient(index);
      }
    }

    final workerCount = min(config.connectConcurrency, config.clients);
    await Future.wait([
      for (var index = 0; index < workerCount; index++) worker(),
    ]);
    watch.stop();
    _connectSeconds = watch.elapsedMicroseconds / 1000000;
  }

  Future<void> _connectClient(int index) async {
    final clientId = _clientId(index);
    final client = MqttServerClient(config.host, clientId)
      ..port = config.port
      ..connectTimeoutPeriod = config.connectTimeoutMs
      ..keepAlivePeriod = 30
      ..autoReconnect = false
      ..secure = false
      ..logging(on: false, logPayloads: false);

    var connectMessage =
        MqttConnectMessage().withClientIdentifier(clientId).startClean();
    if (config.usernamePrefix case final usernamePrefix?) {
      final deviceNumber = index + 1;
      connectMessage = connectMessage.authenticateAs(
        '$usernamePrefix$deviceNumber',
        '${config.passwordPrefix}$deviceNumber',
      );
    }
    client.connectionMessage = connectMessage;

    try {
      await client.connect();
      if (client.connectionStatus?.state == MqttConnectionState.connected) {
        _clients[index] = client;
        return;
      }
      _connectFailures++;
      _firstConnectError ??= 'Client $clientId ended in '
          '${client.connectionStatus?.state.name ?? 'unknown'} state';
    } catch (error) {
      _connectFailures++;
      _firstConnectError ??= _shortError(error);
    }
    _disconnectQuietly(client);
  }

  List<List<int>> _buildStaggerSlots({
    required int windowMs,
    required int salt,
  }) {
    final slots = List.generate(
      windowMs ~/ config.bucketMs,
      (_) => <int>[],
    );
    for (var index = 0; index < config.clients; index++) {
      final offset = (_clientId(index).hashCode + salt) % windowMs;
      slots[offset ~/ config.bucketMs].add(index);
    }
    return slots;
  }

  Future<void> _waitUntil(DateTime target) async {
    final delay = target.difference(DateTime.now());
    if (!delay.isNegative && delay != Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  void _offer({
    required int index,
    required int pointCount,
    required bool full,
    required DateTime target,
  }) {
    _offered++;
    _offeredPoints += pointCount;

    final busy = full ? _fullBusy : _changeBusy;
    if (busy[index]) {
      _skippedBusy++;
      _skippedBusyPoints += pointCount;
      return;
    }

    busy[index] = true;
    _pending++;
    _scheduled++;
    unawaited(_publishOne(
      index: index,
      pointCount: pointCount,
      full: full,
      target: target,
    ));
  }

  Future<void> _publishOne({
    required int index,
    required int pointCount,
    required bool full,
    required DateTime target,
  }) async {
    try {
      final payload = await PersistentIsolateManager.instance.computeBytesTask(
        WorkerInput(
          count: pointCount,
          clientId: _clientId(index),
          timestamp: target.millisecondsSinceEpoch,
          key1Value: target.millisecondsSinceEpoch,
          customKeyValues: const {},
          format: PayloadFormat.timestamped,
        ),
      );
      _clients[index]!.publishMessage(
        config.topic,
        _mqttQos(config.qos),
        payload,
      );

      final completedAt = DateTime.now();
      _latencyUs.add(
        max(0, completedAt.difference(target).inMicroseconds),
      );
      final second = completedAt.difference(_runEpoch).inMilliseconds ~/ 1000;
      final safeSecond = second.clamp(0, _perSecond.length - 1);
      final row = _perSecond[safeSecond];
      final kind = full ? 'full' : 'change';
      row['${kind}Messages'] = row['${kind}Messages']! + 1;
      row['${kind}Points'] = row['${kind}Points']! + pointCount;
      row['bytes'] = row['bytes']! + payload.length;

      _published++;
      _publishedPoints += pointCount;
      _payloadBytes += payload.length;
    } catch (error) {
      _publishFailures++;
      _firstPublishError ??= _shortError(error);
    } finally {
      if (full) {
        _fullBusy[index] = false;
      } else {
        _changeBusy[index] = false;
      }
      _pending--;
    }
  }

  BenchmarkOutcome _outcome({required bool aborted}) {
    _latencyUs.sort();
    final p50Us = _percentile(0.50);
    final p95Us = _percentile(0.95);
    final p99Us = _percentile(0.99);
    final maxLatencyUs = _latencyUs.isEmpty ? 0 : _latencyUs.last;
    final connected = _connectedCount;
    final deliveryComplete = connected == config.clients &&
        _published == _offered &&
        _publishFailures == 0 &&
        _skippedBusy == 0 &&
        _pending == 0;
    final latencyHeadroom = p99Us < config.changeIntervalMs * 1000;
    final passed = !aborted && deliveryComplete && latencyHeadroom;
    final measuredSeconds = _runSeconds > 0 ? _runSeconds : 0.0;

    return BenchmarkOutcome(
      passed: passed,
      json: {
        'event': 'result',
        'passed': passed,
        'aborted': aborted,
        'deliveryComplete': deliveryComplete,
        'latencyHeadroom': latencyHeadroom,
        'criteria': {
          'allClientsConnected': connected == config.clients,
          'noPublishFailures': _publishFailures == 0,
          'noBusySkips': _skippedBusy == 0,
          'noPendingAfterDrain': _pending == 0,
          'publishLatencyP99BelowChangeInterval': latencyHeadroom,
        },
        'config': config.publicJson(),
        'connected': connected,
        'connectFailures': _connectFailures,
        'connectSeconds': _connectSeconds,
        'offered': _offered,
        'offeredPoints': _offeredPoints,
        'scheduled': _scheduled,
        'published': _published,
        'publishedPoints': _publishedPoints,
        'publishFailures': _publishFailures,
        'skippedBusy': _skippedBusy,
        'skippedBusyPoints': _skippedBusyPoints,
        'pendingAfterDrain': _pending,
        'runSeconds': measuredSeconds,
        'messagesPerSecond':
            measuredSeconds > 0 ? _published / measuredSeconds : 0,
        'pointsPerSecond':
            measuredSeconds > 0 ? _publishedPoints / measuredSeconds : 0,
        'mibPerSecond': measuredSeconds > 0
            ? _payloadBytes / measuredSeconds / 1024 / 1024
            : 0,
        'schedulerLateBuckets': _schedulerLateBuckets,
        'maxSchedulerLatenessMs': _maxSchedulerLatenessUs / 1000,
        'publishLatencyP50Ms': p50Us / 1000,
        'publishLatencyP95Ms': p95Us / 1000,
        'publishLatencyP99Ms': p99Us / 1000,
        'publishLatencyMaxMs': maxLatencyUs / 1000,
        'drainSeconds': _drainSeconds,
        'payloadBytes': _payloadBytes,
        'rssBytes': ProcessInfo.currentRss,
        if (_firstConnectError != null) 'firstConnectError': _firstConnectError,
        if (_firstPublishError != null) 'firstPublishError': _firstPublishError,
        'perSecond': [
          for (var index = 0; index < _perSecond.length; index++)
            if (_perSecond[index].values.any((value) => value != 0))
              {'second': index, ..._perSecond[index]},
        ],
      },
    );
  }

  int _percentile(double percentile) {
    if (_latencyUs.isEmpty) return 0;
    final index = ((_latencyUs.length - 1) * percentile).round();
    return _latencyUs[index];
  }

  int get _connectedCount => _clients.whereType<MqttServerClient>().length;

  String _clientId(int index) => '${config.prefix}_device_$index';

  String _shortError(Object error) {
    final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 240 ? text : '${text.substring(0, 240)}...';
  }

  MqttQos _mqttQos(int qos) => switch (qos) {
        1 => MqttQos.atLeastOnce,
        2 => MqttQos.exactlyOnce,
        _ => MqttQos.atMostOnce,
      };

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _stopRequested = true;

    for (final client in _clients.whereType<MqttServerClient>()) {
      _disconnectQuietly(client);
    }
    if (_workersInitialized) {
      PersistentIsolateManager.instance.dispose();
      _workersInitialized = false;
    }
  }

  void _disconnectQuietly(MqttServerClient client) {
    try {
      client.disconnect();
    } catch (_) {
      // Best-effort cleanup; the benchmark result already captures send errors.
    }
  }
}

class BenchmarkOutcome {
  final bool passed;
  final Map<String, Object?> json;

  const BenchmarkOutcome({required this.passed, required this.json});
}

class _HelpRequested implements Exception {
  const _HelpRequested();
}

bool _runSelfCheck() {
  try {
    final config = BenchmarkConfig.parse(const [
      '--clients',
      '1',
      '--keys',
      '10',
      '--change-ratio',
      '0.3',
      '--change-interval-seconds',
      '1',
      '--full-interval-seconds',
      '2',
      '--duration-seconds',
      '4',
      '--prefix',
      'self_check',
    ]);
    final earlyOutcome =
        CapacityBenchmark(config).earlyFailureOutcomeForSelfCheck();
    final rows = earlyOutcome.json['perSecond'];
    if (earlyOutcome.passed || rows is! List || rows.isNotEmpty) {
      throw StateError('Early-failure outcome was not initialized safely');
    }

    var invalidArgumentsRejected = false;
    try {
      BenchmarkConfig.parse(const ['--clients', '0']);
    } on FormatException {
      invalidArgumentsRejected = true;
    }
    if (!invalidArgumentsRejected) {
      throw StateError('Invalid arguments were not rejected');
    }

    stdout.writeln(jsonEncode({
      'event': 'self-check',
      'passed': true,
      'checks': [
        'valid-argument-parse',
        'invalid-argument-rejection',
        'early-failure-outcome-initialization',
      ],
    }));
    return true;
  } catch (error, stackTrace) {
    stderr.writeln('Self-check failed: $error');
    stderr.writeln(stackTrace);
    return false;
  }
}
