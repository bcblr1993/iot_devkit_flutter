import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class StatisticsCollector extends ChangeNotifier {
  int totalDevices = 0;
  int onlineDevices = 0;

  // Computed property
  int get offlineDevices => totalDevices - onlineDevices;

  int totalMessages = 0;
  int successCount = 0;
  // A publish call that threw before it could be handed to the local socket.
  int failureCount = 0;
  // Scheduled reports deliberately discarded after missing their deadline.
  int lateDroppedCount = 0;
  // Payload generation failures. These never reached publishMessage.
  int generationErrorCount = 0;
  // Logical telemetry points accepted by the local MQTT client.
  int totalPoints = 0;
  // Performance Metrics
  double currentTps = 0.0;
  double currentPointsPerSecond = 0.0;
  double currentBandwidth = 0.0; // KB/s
  double currentLatency = 0.0;

  // History Buffers (Last 60s)
  final List<Map<String, double>> tpsHistory = [];
  final List<Map<String, double>> latencyHistory = [];

  // Resources
  double cpuUsage = 0.0; // %
  int memoryUsage = 0; // Bytes

  // Internal tracking
  int _lastTotalMessages = 0;
  int _lastTotalPoints = 0;
  int _lastTotalBytes = 0;
  int totalBytes = 0;
  final Stopwatch _rateStopwatch = Stopwatch();
  Duration _lastRateSample = Duration.zero;

  // Restored missing fields
  int totalLatency = 0;
  int latencySamples = 0;
  int messageSize = 0; // Bytes

  // Maps
  final Map<String, int> groupMessageSizes = {};

  Timer? _updateTimer;
  Timer? _rateTimer;
  Timer? _resourceStartupDelayTimer;
  Timer? _resourceTimer;
  bool _needsUpdate = false;
  bool _usesExternalAggregate = false;

  StatisticsCollector() {
    _rateStopwatch.start();
    _lastRateSample = _rateStopwatch.elapsed;
    _startTimers();
  }

  void _startTimers() {
    _rateTimer?.cancel();
    _resourceTimer?.cancel();
    _resourceStartupDelayTimer?.cancel();

    // 1. Rate Calculation (TPS, Bandwidth) - Fast (1s)
    _rateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateRates();
    });

    // 2. Resource Monitoring — memory only.
    // The old CPU/memory collector shelled out to `wmic` on Windows, which
    // hung/crashed on some machines, so it was disabled. ProcessInfo.currentRss
    // is a pure in-process API (no subprocess), so it is safe on every
    // platform. CPU% has no safe cross-platform source and is left unreported.
    _resourceTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateMemory();
    });
    _updateMemory(); // seed immediately so the meter isn't blank on open
  }

  void _updateMemory() {
    if (_usesExternalAggregate) return;
    try {
      memoryUsage = ProcessInfo.currentRss;
      _needsUpdate = true;
      _flushToUI();
    } catch (_) {
      // currentRss may be unsupported on some platforms — fail silently.
    }
  }

  void _calculateRates({Duration? elapsedOverride}) {
    if (_usesExternalAggregate) {
      _appendRateHistory();
      _needsUpdate = true;
      _flushToUI();
      return;
    }

    final sampleElapsed = _rateStopwatch.elapsed;
    final elapsed = elapsedOverride ?? (sampleElapsed - _lastRateSample);
    _lastRateSample = sampleElapsed;

    int deltaMessages = totalMessages - _lastTotalMessages;
    int deltaPoints = totalPoints - _lastTotalPoints;
    int deltaBytes = totalBytes - _lastTotalBytes;

    _lastTotalMessages = totalMessages;
    _lastTotalPoints = totalPoints;
    _lastTotalBytes = totalBytes;

    final elapsedSeconds =
        elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (elapsedSeconds > 0) {
      currentTps = deltaMessages / elapsedSeconds;
      currentPointsPerSecond = deltaPoints / elapsedSeconds;
      currentBandwidth = deltaBytes / 1024.0 / elapsedSeconds;
    } else {
      currentTps = 0.0;
      currentPointsPerSecond = 0.0;
      currentBandwidth = 0.0;
    }
    currentLatency = latencySamples > 0 ? (totalLatency / latencySamples) : 0.0;

    _appendRateHistory();

    // Force update every second if there is activity or history
    if (currentTps > 0 || tpsHistory.isNotEmpty) {
      _needsUpdate = true;
      _flushToUI();
    }
  }

  void _appendRateHistory() {
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();
    tpsHistory.add({'time': now, 'value': currentTps});
    if (tpsHistory.length > 60) {
      tpsHistory.removeAt(0);
    }

    latencyHistory.add({'time': now, 'value': currentLatency});
    if (latencyHistory.length > 60) {
      latencyHistory.removeAt(0);
    }
  }

  void reset() {
    totalDevices = 0;
    onlineDevices = 0;
    totalMessages = 0;
    successCount = 0;
    failureCount = 0;
    lateDroppedCount = 0;
    generationErrorCount = 0;
    totalPoints = 0;
    totalLatency = 0;
    latencySamples = 0;
    messageSize = 0;
    totalBytes = 0;
    groupMessageSizes.clear();

    // Reset performance metrics
    currentTps = 0.0;
    currentPointsPerSecond = 0.0;
    currentBandwidth = 0.0;
    currentLatency = 0.0;
    tpsHistory.clear();
    latencyHistory.clear();
    _lastTotalMessages = 0;
    _lastTotalPoints = 0;
    _lastTotalBytes = 0;
    _rateStopwatch.reset();
    _lastRateSample = _rateStopwatch.elapsed;

    _needsUpdate = false;
    _updateTimer?.cancel();
    // Restart timers
    _startTimers();

    notifyListeners();
  }

  /// Switches this collector to statistics supplied by worker processes.
  ///
  /// The coordinator process does not publish telemetry itself during an
  /// automatic multi-process run. Worker snapshots already contain their
  /// one-second rates, so the local rate timer must not derive a second set of
  /// rates from asynchronously arriving IPC snapshots.
  void beginExternalAggregation() {
    _usesExternalAggregate = true;
    reset();
    _usesExternalAggregate = true;
  }

  void endExternalAggregation() {
    _usesExternalAggregate = false;
  }

  /// Replaces the visible counters with one coordinator-side aggregate.
  ///
  /// Only the GUI coordinator calls this. Normal simulator/worker processes
  /// continue using the increment methods below, so their hot path is
  /// unchanged.
  void applyExternalAggregate(Map<String, dynamic> snapshot) {
    if (!_usesExternalAggregate) return;

    int readInt(String key) => (snapshot[key] as num?)?.toInt() ?? 0;
    double readDouble(String key) => (snapshot[key] as num?)?.toDouble() ?? 0;

    totalDevices = readInt('totalDevices');
    onlineDevices = readInt('onlineDevices');
    totalMessages = readInt('totalMessages');
    successCount = readInt('successCount');
    failureCount = readInt('failureCount');
    lateDroppedCount = readInt('lateDroppedCount');
    generationErrorCount = readInt('generationErrorCount');
    totalPoints = readInt('totalPoints');
    totalBytes = readInt('totalBytes');
    totalLatency = readInt('totalLatency');
    latencySamples = readInt('latencySamples');
    messageSize = readInt('messageSize');
    memoryUsage = readInt('memoryUsage');
    currentTps = readDouble('currentTps');
    currentPointsPerSecond = readDouble('currentPointsPerSecond');
    currentBandwidth = readDouble('currentBandwidth');
    currentLatency = readDouble('currentLatency');
    _lastTotalMessages = totalMessages;
    _lastTotalPoints = totalPoints;
    _lastTotalBytes = totalBytes;
    _scheduleUpdate();
  }

  void setTotalDevices(int count) {
    totalDevices = count;
    _scheduleUpdate();
  }

  void setOnlineDevices(int count) {
    onlineDevices = count;
    _scheduleUpdate();
  }

  void setMessageSize(int size) {
    messageSize = size;
    totalBytes += size;
    _scheduleUpdate();
  }

  void setGroupMessageSize(String groupName, int size) {
    groupMessageSizes[groupName] = size;
    _scheduleUpdate();
  }

  void incrementSuccess({int latency = 0, int points = 0}) {
    totalMessages++;
    successCount++;
    if (points > 0) {
      totalPoints += points;
    }

    if (latency > 0 && successCount % 10 == 0) {
      totalLatency += latency;
      latencySamples++;
    }
    _scheduleUpdate();
  }

  void incrementFailure({int count = 1}) {
    if (count < 1) return;
    totalMessages += count;
    failureCount += count;
    _scheduleUpdate();
  }

  void incrementLateDropped({int count = 1}) {
    if (count < 1) return;
    lateDroppedCount += count;
    _scheduleUpdate();
  }

  void incrementGenerationError({int count = 1}) {
    if (count < 1) return;
    generationErrorCount += count;
    _scheduleUpdate();
  }

  @visibleForTesting
  void calculateRatesForTest(Duration elapsed) {
    _calculateRates(elapsedOverride: elapsed);
  }

  void _scheduleUpdate() {
    if (!_needsUpdate) {
      _needsUpdate = true;
      if (_updateTimer == null || !_updateTimer!.isActive) {
        _updateTimer = Timer(const Duration(milliseconds: 200), _flushToUI);
      }
    }
  }

  void _flushToUI() {
    if (_needsUpdate) {
      notifyListeners();
      _needsUpdate = false;
    }
  }

  Map<String, dynamic> getSnapshot() {
    int total = successCount + failureCount;
    return {
      'totalDevices': totalDevices,
      'onlineDevices': onlineDevices,
      'offlineDevices': offlineDevices,
      'totalMessages': totalMessages,
      'successCount': successCount,
      'failureCount': failureCount,
      'lateDroppedCount': lateDroppedCount,
      'generationErrorCount': generationErrorCount,
      'totalPoints': totalPoints,
      'totalBytes': totalBytes,
      'totalLatency': totalLatency,
      'latencySamples': latencySamples,
      'currentTps': currentTps,
      'currentPointsPerSecond': currentPointsPerSecond,
      'currentBandwidth': currentBandwidth,
      'currentLatency': currentLatency,
      'memoryUsage': memoryUsage,
      'successRate':
          total > 0 ? (successCount / total * 100).toStringAsFixed(1) : '0.0',
      'failureRate':
          total > 0 ? (failureCount / total * 100).toStringAsFixed(1) : '0.0',
      'avgLatency': latencySamples > 0
          ? (totalLatency / latencySamples).toStringAsFixed(0)
          : '0',
      'messageSize': messageSize,
      'groupMessageSizes': groupMessageSizes
    };
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _rateTimer?.cancel();
    _resourceStartupDelayTimer?.cancel();
    _resourceTimer?.cancel();
    _rateStopwatch.stop();
    super.dispose();
  }
}
