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
  int failureCount = 0;
  // Performance Metrics
  double currentTps = 0.0;
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
  int _lastTotalBytes = 0;
  int totalBytes = 0;
  
  // Restored missing fields
  int totalLatency = 0;
  int latencySamples = 0;
  int messageSize = 0; // Bytes
  
  // Maps 
  final Map<String, int> groupMessageSizes = {};

  Timer? _updateTimer;
  Timer? _rateTimer;
  Timer? _resourceTimer;
  bool _needsUpdate = false;
  bool _isUpdatingResources = false;

  StatisticsCollector() {
    _startTimers();
  }
  
  void _startTimers() {
    _rateTimer?.cancel();
    _resourceTimer?.cancel();
    
    // 1. Rate Calculation (TPS, Bandwidth) - Fast (1s)
    _rateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
       _calculateRates();
    });
    
    // 2. Resource Monitoring (CPU, Memory) - Slow (3s) & Guarded
    _resourceTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
       if (!_isUpdatingResources) {
         _updateResources();
       }
    });
  }
  
  Future<void> _updateResources() async {
    _isUpdatingResources = true;
    try {
      // Process Memory (RSS) - Fast (dart:io)
      memoryUsage = ProcessInfo.currentRss;

      
      // CPU Usage (Platform Specific)
      if (Platform.isMacOS || Platform.isLinux) {
        // macOS/Linux: ps -A -o %cpu
        // Pipe to awk to sum it up
        final result = await Process.run('sh', ['-c', "ps -A -o %cpu | awk '{s+=\$1} END {print s}'"]);
        if (result.exitCode == 0) {
          cpuUsage = double.tryParse(result.stdout.toString().trim()) ?? 0.0;
        }
      } else if (Platform.isWindows) {
        // Windows: wmic cpu get loadpercentage
        final result = await Process.run('wmic', ['cpu', 'get', 'loadpercentage']);
        if (result.exitCode == 0) {
          // Output is distinct lines, e.g. "LoadPercentage \n 12 \n"
          final lines = result.stdout.toString().split('\n');
          for (var line in lines) {
             final val = double.tryParse(line.trim());
             if (val != null) {
               cpuUsage = val;
               break;
             }
          }
        }
      }
      
      // Force update to refresh stats
      _needsUpdate = true; 
      _flushToUI();
      
    } catch (e) {
      // ignore silently to avoid log spam
    } finally {
      _isUpdatingResources = false;
    }
  }

  void _calculateRates() {
     int deltaMessages = totalMessages - _lastTotalMessages;
     int deltaBytes = totalBytes - _lastTotalBytes;
     
     _lastTotalMessages = totalMessages;
     _lastTotalBytes = totalBytes;
     
     currentTps = deltaMessages.toDouble();
     currentBandwidth = deltaBytes / 1024.0;
     currentLatency = latencySamples > 0 ? (totalLatency / latencySamples) : 0.0;
     
     // Update History
     double now = DateTime.now().millisecondsSinceEpoch.toDouble();
     
     tpsHistory.add({'time': now, 'value': currentTps});
     if (tpsHistory.length > 60) tpsHistory.removeAt(0);
     
     latencyHistory.add({'time': now, 'value': currentLatency});
     if (latencyHistory.length > 60) latencyHistory.removeAt(0);
     
     // Force update every second if there is activity or history
     if (currentTps > 0 || tpsHistory.isNotEmpty) {
       _needsUpdate = true;
       _flushToUI();
     }
  }

  void reset() {
    totalDevices = 0;
    onlineDevices = 0;
    totalMessages = 0;
    successCount = 0;
    failureCount = 0;
    totalLatency = 0;
    latencySamples = 0;
    messageSize = 0;
    totalBytes = 0;
    groupMessageSizes.clear();
    
    // Reset performance metrics
    currentTps = 0.0;
    currentBandwidth = 0.0;
    currentLatency = 0.0;
    tpsHistory.clear();
    latencyHistory.clear();
    _lastTotalMessages = 0;
    _lastTotalBytes = 0;

    _needsUpdate = false;
    _updateTimer?.cancel();
    // Restart timers 
    _startTimers(); 
    
    notifyListeners();
  }

  void setTotalDevices(int count) {
    totalDevices = count;
    _scheduleUpdate();
  }

  void setOnlineDevices(int count) {
    onlineDevices = count;
    _scheduleUpdate();
  }

  @override
  void setMessageSize(int size) {
    messageSize = size;
    totalBytes += size; 
    _scheduleUpdate();
  }

  void setGroupMessageSize(String groupName, int size) {
    groupMessageSizes[groupName] = size;
    _scheduleUpdate();
  }

  void incrementSuccess({int latency = 0}) {
    totalMessages++;
    successCount++;

    if (latency > 0 && successCount % 10 == 0) {
      totalLatency += latency;
      latencySamples++;
    }
    _scheduleUpdate();
  }

  void incrementFailure({int count = 1}) {
    totalMessages += count;
    failureCount += count;
    _scheduleUpdate();
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
      'successRate': total > 0 ? (successCount / total * 100).toStringAsFixed(1) : '0.0',
      'failureRate': total > 0 ? (failureCount / total * 100).toStringAsFixed(1) : '0.0',
      'avgLatency': latencySamples > 0 ? (totalLatency / latencySamples).toStringAsFixed(0) : '0',
      'messageSize': messageSize,
      'groupMessageSizes': groupMessageSizes
    };
  }
}
