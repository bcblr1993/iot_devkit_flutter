import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iot_devkit/models/group_config.dart';
import 'package:iot_devkit/models/custom_key_config.dart';
import 'package:iot_devkit/services/config_service.dart';
import 'package:iot_devkit/services/mqtt_controller.dart';
import 'package:iot_devkit/services/data_generator.dart';

class MqttViewModel extends ChangeNotifier {
  
  // Forms
  final formKeyBasic = GlobalKey<FormState>();
  final formKeyAdvanced = GlobalKey<FormState>();
  final formKeyMqtt = GlobalKey<FormState>();

  // Controllers (Basic Mode & MQTT)
  final hostController = TextEditingController(text: 'localhost');
  final portController = TextEditingController(text: '1883');
  final topicController = TextEditingController(text: 'v1/devices/me/telemetry');
  final caPathController = TextEditingController();
  final certPathController = TextEditingController();
  final keyPathController = TextEditingController();
  
  final startIdxController = TextEditingController(text: '1');
  final endIdxController = TextEditingController(text: '10');
  final intervalController = TextEditingController(text: '1');
  final dataPointController = TextEditingController(text: '10');
  final devicePrefixController = TextEditingController(text: 'device');
  final clientIdPrefixController = TextEditingController(text: 'device');
  final usernamePrefixController = TextEditingController(text: 'user');
  final passwordPrefixController = TextEditingController(text: 'pass');

  // State
  bool _enableSsl = false;
  bool get enableSsl => _enableSsl;
  
  int _qos = 0;
  int get qos => _qos;
  
  List<CustomKeyConfig> _basicCustomKeys = [];
  List<CustomKeyConfig> get basicCustomKeys => _basicCustomKeys;
  
  List<GroupConfig> _groups = [];
  List<GroupConfig> get groups => _groups;
  
  String _format = 'default';
  String get format => _format;
  
  void setFormat(String val) {
    if (_format != val) {
      _format = val;
      notifyListeners();
      scheduleAutoSave();
    }
  }

  // Auto-Save
  Timer? _autoSaveTimer;

  MqttViewModel() {
    _initListeners();
    loadConfig();
  }

  void _initListeners() {
    final controllers = [
      hostController, portController, topicController,
      caPathController, certPathController, keyPathController,
      startIdxController, endIdxController, intervalController,
      dataPointController, devicePrefixController, clientIdPrefixController,
      usernamePrefixController, passwordPrefixController
    ];
    for (var c in controllers) {
      c.addListener(scheduleAutoSave);
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    hostController.dispose();
    portController.dispose();
    topicController.dispose();
    caPathController.dispose();
    certPathController.dispose();
    keyPathController.dispose();
    startIdxController.dispose();
    endIdxController.dispose();
    intervalController.dispose();
    dataPointController.dispose();
    devicePrefixController.dispose();
    clientIdPrefixController.dispose();
    usernamePrefixController.dispose();
    passwordPrefixController.dispose();
    super.dispose();
  }

  // --- Actions ---

  void setEnableSsl(bool val) {
    if (_enableSsl != val) {
      _enableSsl = val;
      notifyListeners();
      scheduleAutoSave();
    }
  }

  void setQos(int val) {
    if (_qos != val) {
      _qos = val;
      notifyListeners();
      scheduleAutoSave();
    }
  }
  
  void updateBasicCustomKeys(List<CustomKeyConfig> keys) {
    _basicCustomKeys = keys;
    notifyListeners();
    scheduleAutoSave();
  }

  void updateGroups(List<GroupConfig> newGroups) {
    _groups = newGroups;
    notifyListeners();
    scheduleAutoSave();
  }

  // --- Logic ---

  void scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 1), () {
      final config = getCompleteConfig();
      ConfigService.saveToLocalStorage(config);
      debugPrint('[MqttViewModel] Config auto-saved.');
    });
  }

  Future<void> loadConfig() async {
    final config = await ConfigService.loadFromLocalStorage();
    if (config != null) {
      _applyConfig(config);
    } else {
      // Initialize with one default group if empty
      updateGroups([GroupConfig()]);
    }
  }

  void _applyConfig(Map<String, dynamic> config) {
    final mqtt = config['mqtt'] ?? {};
    hostController.text = mqtt['host'] ?? 'localhost';
    portController.text = (mqtt['port'] ?? 1883).toString();
    topicController.text = mqtt['topic'] ?? 'v1/devices/me/telemetry';
    _qos = mqtt['qos'] ?? 0;
    _enableSsl = mqtt['enable_ssl'] ?? false;
    caPathController.text = mqtt['ca_path'] ?? '';
    certPathController.text = mqtt['cert_path'] ?? '';
    keyPathController.text = mqtt['key_path'] ?? '';

    startIdxController.text = (config['device_start_number'] ?? 1).toString();
    endIdxController.text = (config['device_end_number'] ?? 10).toString();
    intervalController.text = (config['send_interval'] ?? 1).toString();
      _format = config['data']?['format'] ?? 'default';
      dataPointController.text = (config['data']?['data_point_count'] ?? 10).toString();
    
    devicePrefixController.text = config['device_prefix'] ?? 'device';
    clientIdPrefixController.text = config['client_id_prefix'] ?? 'device';
    usernamePrefixController.text = config['username_prefix'] ?? 'user';
    passwordPrefixController.text = config['password_prefix'] ?? 'pass';

    if (config['custom_keys'] != null) {
      _basicCustomKeys = (config['custom_keys'] as List)
          .map((e) => CustomKeyConfig.fromJson(e))
          .toList();
    }

    if (config['groups'] != null) {
      _groups = (config['groups'] as List)
          .map((e) => GroupConfig.fromJson(e))
          .toList();
    }
    
    notifyListeners();
  }

  Map<String, dynamic> getCompleteConfig() {
    return {
      'mqtt': {
        'host': hostController.text,
        'port': int.tryParse(portController.text) ?? 1883,
        'topic': topicController.text,
        'qos': _qos,
        'enable_ssl': _enableSsl,
        'ca_path': caPathController.text,
        'cert_path': certPathController.text,
        'key_path': keyPathController.text,
      },
      'device_start_number': int.tryParse(startIdxController.text) ?? 1,
      'device_end_number': int.tryParse(endIdxController.text) ?? 10,
      'device_prefix': devicePrefixController.text,
      'client_id_prefix': clientIdPrefixController.text,
      'username_prefix': usernamePrefixController.text,
      'password_prefix': passwordPrefixController.text,
      'send_interval': int.tryParse(intervalController.text) ?? 1,
      'data': {
        'format': _format,
        'data_point_count': int.tryParse(dataPointController.text) ?? 10,
      },
      'custom_keys': _basicCustomKeys.map((e) => e.toJson()).toList(),
      'groups': _groups.map((e) => e.toJson()).toList(),
    };
  }
  
  Map<String, dynamic>? generatePreviewData({required bool isBasic}) {
    try {
      if (isBasic) {
        final count = int.tryParse(dataPointController.text) ?? 10;
        if (_format == 'tn') {
           return DataGenerator.generateTnPayload(count);
        } else if (_format == 'tn-empty') {
           return DataGenerator.generateTnEmptyPayload();
        } else {
           return DataGenerator.generateBatteryStatus(
             count,
             customKeys: _basicCustomKeys,
             clientId: 'preview_client',
           );
        }
      } else {
        // Advanced Mode
        if (_groups.isEmpty) return null;
        final group = _groups.first;
        if (group.format == 'tn') {
          return DataGenerator.generateTnPayload(group.totalKeyCount);
        } else if (group.format == 'tn-empty') {
          return DataGenerator.generateTnEmptyPayload();
        } else {
          return DataGenerator.generateBatteryStatus(
            group.totalKeyCount,
            customKeys: group.customKeys,
            clientId: '${group.clientIdPrefix}preview',
          );
        }
      }
    } catch (e) {
      debugPrint('Error generating preview: $e');
      return null;
    }
  }
  
  void startBasicSimulation(BuildContext context, Function(Map<String, dynamic>, bool) showPreviewCallback) {
    if (formKeyBasic.currentState!.validate() && formKeyMqtt.currentState!.validate()) {
       final config = getCompleteConfig();
       config['mode'] = 'basic';
       ConfigService.saveToLocalStorage(config);
       showPreviewCallback(config, true);
    }
  }

  void startAdvancedSimulation(BuildContext context, Function(Map<String, dynamic>, bool) showPreviewCallback) {
    if (formKeyAdvanced.currentState!.validate() && formKeyMqtt.currentState!.validate()) {
       final config = getCompleteConfig();
       config['mode'] = 'advanced';
       ConfigService.saveToLocalStorage(config);
       showPreviewCallback(config, false);
    }
  }
}
