import 'dart:async';
import 'package:flutter/foundation.dart';

class StatisticsCollector extends ChangeNotifier {
  int totalDevices = 0;
  int onlineDevices = 0;
  
  // Computed property
  int get offlineDevices => totalDevices - onlineDevices;
  
  int totalMessages = 0;
  int successCount = 0;
  int failureCount = 0;
  int totalLatency = 0;
  int latencySamples = 0;
  int messageSize = 0; // Bytes
  final Map<String, int> groupMessageSizes = {};

  Timer? _updateTimer;
  bool _needsUpdate = false;

  void reset() {
    totalDevices = 0;
    onlineDevices = 0;
    totalMessages = 0;
    successCount = 0;
    failureCount = 0;
    totalLatency = 0;
    latencySamples = 0;
    messageSize = 0;
    groupMessageSizes.clear();
    
    _needsUpdate = false;
    _updateTimer?.cancel();
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

  void setMessageSize(int size) {
    messageSize = size;
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

  void incrementFailure() {
    totalMessages++;
    failureCount++;
    _scheduleUpdate();
  }

  void _scheduleUpdate() {
    if (!_needsUpdate) {
      _needsUpdate = true;
      if (_updateTimer == null || !_updateTimer!.isActive) {
        _updateTimer = Timer(const Duration(milliseconds: 1000), _flushToUI);
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
