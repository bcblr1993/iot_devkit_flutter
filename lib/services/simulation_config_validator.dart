import '../models/custom_key_config.dart';
import '../models/group_config.dart';

enum SimulationMode { basic, advanced }

class SimulationConfigLimits {
  static const int maxDevicesPerRun = 50000;
  static const int maxDataPoints = 10000;
  static const int maxIntervalSeconds = 86400;
  static const int maxGroups = 12;
}

class SimulationConfigIssue {
  final String field;
  final String zhMessage;
  final String enMessage;

  const SimulationConfigIssue({
    required this.field,
    required this.zhMessage,
    required this.enMessage,
  });

  String messageFor(String languageCode) {
    return languageCode == 'zh' ? zhMessage : enMessage;
  }
}

class SimulationConfigValidationResult {
  final List<SimulationConfigIssue> issues;

  const SimulationConfigValidationResult(this.issues);

  bool get isValid => issues.isEmpty;

  SimulationConfigIssue? get firstIssue => issues.isEmpty ? null : issues.first;

  String firstMessageFor(String languageCode) {
    return firstIssue?.messageFor(languageCode) ?? '';
  }
}

class SimulationConfigValidator {
  const SimulationConfigValidator();

  SimulationConfigValidationResult validate(
    Map<String, dynamic> config, {
    required SimulationMode mode,
  }) {
    final issues = <SimulationConfigIssue>[];
    _validateMqtt(config, issues);

    if (mode == SimulationMode.basic) {
      _validateBasic(config, issues);
    } else {
      _validateAdvanced(config, issues);
    }

    return SimulationConfigValidationResult(issues);
  }

  void _validateMqtt(
    Map<String, dynamic> config,
    List<SimulationConfigIssue> issues,
  ) {
    final mqtt = _asMap(config['mqtt']);
    final host = (mqtt['host'] ?? '').toString().trim();
    final topic = (mqtt['topic'] ?? '').toString().trim();
    final port = _toInt(mqtt['port']);

    if (host.isEmpty) {
      issues.add(const SimulationConfigIssue(
        field: 'mqtt.host',
        zhMessage: '服务器地址不能为空。',
        enMessage: 'Host is required.',
      ));
    }
    if (port == null || port < 1 || port > 65535) {
      issues.add(const SimulationConfigIssue(
        field: 'mqtt.port',
        zhMessage: '端口必须在 1 到 65535 之间。',
        enMessage: 'Port must be between 1 and 65535.',
      ));
    }
    if (topic.isEmpty) {
      issues.add(const SimulationConfigIssue(
        field: 'mqtt.topic',
        zhMessage: 'MQTT 主题不能为空。',
        enMessage: 'MQTT topic is required.',
      ));
    }
  }

  void _validateBasic(
    Map<String, dynamic> config,
    List<SimulationConfigIssue> issues,
  ) {
    final start = _toInt(config['device_start_number']);
    final end = _toInt(config['device_end_number']);
    final interval = _toInt(config['send_interval']);
    final data = _asMap(config['data']);
    final dataPointCount = _toInt(data['data_point_count']);

    _validateRange(
      issues,
      start: start,
      end: end,
      fieldPrefix: 'basic',
      zhName: '基础模式',
      enName: 'Basic mode',
    );
    _validateRequiredText(
      issues,
      field: 'client_id_prefix',
      value: config['client_id_prefix'],
      zhLabel: 'Client ID 前缀',
      enLabel: 'Client ID prefix',
    );
    _validatePositiveInt(
      issues,
      field: 'send_interval',
      value: interval,
      max: SimulationConfigLimits.maxIntervalSeconds,
      zhLabel: '发送间隔',
      enLabel: 'Send interval',
    );
    _validatePositiveInt(
      issues,
      field: 'data.data_point_count',
      value: dataPointCount,
      max: SimulationConfigLimits.maxDataPoints,
      zhLabel: '数据点数量',
      enLabel: 'Data point count',
    );
    _validateCustomKeys(
      issues,
      _customKeysFrom(config['custom_keys']),
      maxKeys: dataPointCount ?? SimulationConfigLimits.maxDataPoints,
      ownerLabelZh: '基础模式',
      ownerLabelEn: 'Basic mode',
    );
  }

  void _validateAdvanced(
    Map<String, dynamic> config,
    List<SimulationConfigIssue> issues,
  ) {
    final groups = _groupsFrom(config['groups']);
    if (groups.isEmpty) {
      issues.add(const SimulationConfigIssue(
        field: 'groups',
        zhMessage: '高级模式至少需要 1 个模拟分组。',
        enMessage: 'Advanced mode requires at least one simulation group.',
      ));
      return;
    }
    if (groups.length > SimulationConfigLimits.maxGroups) {
      issues.add(const SimulationConfigIssue(
        field: 'groups',
        zhMessage: '最多允许 ${SimulationConfigLimits.maxGroups} 个模拟分组。',
        enMessage:
            'At most ${SimulationConfigLimits.maxGroups} simulation groups are allowed.',
      ));
    }

    var totalDevices = 0;
    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      final index = i + 1;
      final groupNameZh = '分组 $index';
      final groupNameEn = 'Group $index';

      _validateRequiredText(
        issues,
        field: 'groups[$i].name',
        value: group.name,
        zhLabel: '$groupNameZh 名称',
        enLabel: '$groupNameEn name',
      );
      _validateRequiredText(
        issues,
        field: 'groups[$i].clientIdPrefix',
        value: group.clientIdPrefix,
        zhLabel: '$groupNameZh Client ID 前缀',
        enLabel: '$groupNameEn Client ID prefix',
      );
      _validateRange(
        issues,
        start: group.startDeviceNumber,
        end: group.endDeviceNumber,
        fieldPrefix: 'groups[$i]',
        zhName: group.name.trim().isEmpty ? groupNameZh : group.name.trim(),
        enName: group.name.trim().isEmpty ? groupNameEn : group.name.trim(),
      );

      final count = group.endDeviceNumber - group.startDeviceNumber + 1;
      if (count > 0) totalDevices += count;

      _validatePositiveInt(
        issues,
        field: 'groups[$i].totalKeyCount',
        value: group.totalKeyCount,
        max: SimulationConfigLimits.maxDataPoints,
        zhLabel: '$groupNameZh 键总数',
        enLabel: '$groupNameEn total keys',
      );
      _validatePositiveInt(
        issues,
        field: 'groups[$i].changeIntervalSeconds',
        value: group.changeIntervalSeconds,
        max: SimulationConfigLimits.maxIntervalSeconds,
        zhLabel: '$groupNameZh 变化频率',
        enLabel: '$groupNameEn change interval',
      );
      _validatePositiveInt(
        issues,
        field: 'groups[$i].fullIntervalSeconds',
        value: group.fullIntervalSeconds,
        max: SimulationConfigLimits.maxIntervalSeconds,
        zhLabel: '$groupNameZh 全量频率',
        enLabel: '$groupNameEn full interval',
      );
      if (group.changeRatio < 0 || group.changeRatio > 1) {
        issues.add(SimulationConfigIssue(
          field: 'groups[$i].changeRatio',
          zhMessage: '$groupNameZh 变化比例必须在 0 到 1 之间。',
          enMessage: '$groupNameEn change ratio must be between 0 and 1.',
        ));
      }
      _validateCustomKeys(
        issues,
        group.customKeys,
        maxKeys: group.totalKeyCount,
        ownerLabelZh: groupNameZh,
        ownerLabelEn: groupNameEn,
      );
    }

    if (totalDevices > SimulationConfigLimits.maxDevicesPerRun) {
      issues.add(const SimulationConfigIssue(
        field: 'groups',
        zhMessage: '本次模拟设备总数不能超过 ${SimulationConfigLimits.maxDevicesPerRun} 台。',
        enMessage:
            'Total devices cannot exceed ${SimulationConfigLimits.maxDevicesPerRun}.',
      ));
    }
  }

  void _validateRange(
    List<SimulationConfigIssue> issues, {
    required int? start,
    required int? end,
    required String fieldPrefix,
    required String zhName,
    required String enName,
  }) {
    if (start == null || start < 1) {
      issues.add(SimulationConfigIssue(
        field: '$fieldPrefix.start',
        zhMessage: '$zhName 起始索引必须大于等于 1。',
        enMessage: '$enName start index must be at least 1.',
      ));
    }
    if (end == null || end < 1) {
      issues.add(SimulationConfigIssue(
        field: '$fieldPrefix.end',
        zhMessage: '$zhName 结束索引必须大于等于 1。',
        enMessage: '$enName end index must be at least 1.',
      ));
    }
    if (start == null || end == null || start < 1 || end < 1) return;
    if (end < start) {
      issues.add(SimulationConfigIssue(
        field: '$fieldPrefix.range',
        zhMessage: '$zhName 结束索引不能小于起始索引。',
        enMessage: '$enName end index cannot be smaller than start index.',
      ));
      return;
    }

    final count = end - start + 1;
    if (count > SimulationConfigLimits.maxDevicesPerRun) {
      issues.add(SimulationConfigIssue(
        field: '$fieldPrefix.range',
        zhMessage:
            '$zhName 单次设备数量不能超过 ${SimulationConfigLimits.maxDevicesPerRun} 台。',
        enMessage:
            '$enName device count cannot exceed ${SimulationConfigLimits.maxDevicesPerRun}.',
      ));
    }
  }

  void _validatePositiveInt(
    List<SimulationConfigIssue> issues, {
    required String field,
    required int? value,
    required int max,
    required String zhLabel,
    required String enLabel,
  }) {
    if (value == null || value < 1) {
      issues.add(SimulationConfigIssue(
        field: field,
        zhMessage: '$zhLabel 必须大于等于 1。',
        enMessage: '$enLabel must be at least 1.',
      ));
    } else if (value > max) {
      issues.add(SimulationConfigIssue(
        field: field,
        zhMessage: '$zhLabel 不能超过 $max。',
        enMessage: '$enLabel cannot exceed $max.',
      ));
    }
  }

  void _validateRequiredText(
    List<SimulationConfigIssue> issues, {
    required String field,
    required Object? value,
    required String zhLabel,
    required String enLabel,
  }) {
    if ((value ?? '').toString().trim().isEmpty) {
      issues.add(SimulationConfigIssue(
        field: field,
        zhMessage: '$zhLabel 不能为空。',
        enMessage: '$enLabel is required.',
      ));
    }
  }

  void _validateCustomKeys(
    List<SimulationConfigIssue> issues,
    List<CustomKeyConfig> keys, {
    required int maxKeys,
    required String ownerLabelZh,
    required String ownerLabelEn,
  }) {
    if (keys.length > maxKeys) {
      issues.add(SimulationConfigIssue(
        field: 'custom_keys',
        zhMessage: '$ownerLabelZh 自定义 Key 数量不能超过键总数。',
        enMessage: '$ownerLabelEn custom keys cannot exceed total keys.',
      ));
    }

    final seenNames = <String>{};
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      final name = key.name.trim();
      if (name.isEmpty) {
        issues.add(SimulationConfigIssue(
          field: 'custom_keys[$i].name',
          zhMessage: '$ownerLabelZh 第 ${i + 1} 个自定义 Key 名称不能为空。',
          enMessage: '$ownerLabelEn custom key ${i + 1} name is required.',
        ));
        continue;
      }
      if (!seenNames.add(name)) {
        issues.add(SimulationConfigIssue(
          field: 'custom_keys[$i].name',
          zhMessage: '$ownerLabelZh 存在重复自定义 Key：$name。',
          enMessage: '$ownerLabelEn has duplicate custom key: $name.',
        ));
      }

      if (key.mode == CustomKeyMode.random &&
          (key.type == CustomKeyType.integer ||
              key.type == CustomKeyType.float)) {
        final min = key.min;
        final max = key.max;
        if (min == null || max == null) {
          issues.add(SimulationConfigIssue(
            field: 'custom_keys[$i].range',
            zhMessage: '$ownerLabelZh 自定义 Key「$name」随机范围不能为空。',
            enMessage:
                '$ownerLabelEn custom key "$name" random range is required.',
          ));
        } else if (min > max) {
          issues.add(SimulationConfigIssue(
            field: 'custom_keys[$i].range',
            zhMessage: '$ownerLabelZh 自定义 Key「$name」最小值不能大于最大值。',
            enMessage:
                '$ownerLabelEn custom key "$name" min cannot exceed max.',
          ));
        }
      }

      if (key.mode == CustomKeyMode.static &&
          !_isStaticValueCompatible(key.staticValue, key.type)) {
        issues.add(SimulationConfigIssue(
          field: 'custom_keys[$i].static_value',
          zhMessage: '$ownerLabelZh 自定义 Key「$name」固定值与类型不匹配。',
          enMessage:
              '$ownerLabelEn custom key "$name" static value does not match its type.',
        ));
      }
    }
  }

  bool _isStaticValueCompatible(String? value, CustomKeyType type) {
    if (value == null || value.isEmpty) {
      return type == CustomKeyType.string;
    }
    switch (type) {
      case CustomKeyType.integer:
        return int.tryParse(value) != null;
      case CustomKeyType.float:
        return double.tryParse(value) != null;
      case CustomKeyType.boolean:
        final normalized = value.toLowerCase();
        return normalized == 'true' ||
            normalized == 'false' ||
            normalized == '1' ||
            normalized == '0';
      case CustomKeyType.string:
        return true;
    }
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return const {};
  }

  List<CustomKeyConfig> _customKeysFrom(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => CustomKeyConfig.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  List<GroupConfig> _groupsFrom(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) {
          if (item is GroupConfig) return item;
          if (item is Map) return GroupConfig.fromJson(_asMap(item));
          return null;
        })
        .whereType<GroupConfig>()
        .toList(growable: false);
  }

  int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString());
  }
}
