import 'package:uuid/uuid.dart';

/// A subscription the simulator registers on every connected MQTT client.
///
/// Stored as part of the profile JSON under `subscriptions: [...]`.
/// Backwards-compatible: legacy profiles without this key load as an empty list.
class SubscriptionConfig {
  /// Stable id for list operations; not persisted to broker.
  final String id;

  /// MQTT topic filter, may include `+` / `#` wildcards.
  String topic;

  /// QoS 0 / 1 / 2.
  int qos;

  /// User can temporarily disable a row without deleting it.
  bool enabled;

  /// ThingsBoard convention: when set on `v1/devices/me/rpc/request/+`
  /// the simulator auto-publishes an empty `{}` to `v1/devices/me/rpc/response/{id}`.
  /// Ignored for non-RPC topics.
  bool autoAck;

  /// Optional human-readable label shown in the UI list.
  String? label;

  SubscriptionConfig({
    String? id,
    this.topic = '',
    this.qos = 1,
    this.enabled = true,
    this.autoAck = false,
    this.label,
  }) : id = id ?? const Uuid().v4();

  // ── ThingsBoard presets ────────────────────────────────────────────
  // Kept here so UI / tests reference a single source of truth.

  /// `v1/devices/me/rpc/request/+` — RPC requests pushed by the platform.
  /// Auto-ACK on by default so the device "responds" to the call.
  static SubscriptionConfig thingsboardRpcPreset() => SubscriptionConfig(
        topic: 'v1/devices/me/rpc/request/+',
        qos: 1,
        autoAck: true,
        label: 'ThingsBoard RPC',
      );

  /// `v1/devices/me/attributes` — shared attribute updates.
  static SubscriptionConfig thingsboardAttributesPreset() => SubscriptionConfig(
        topic: 'v1/devices/me/attributes',
        qos: 1,
        label: 'ThingsBoard Shared Attributes',
      );

  /// True when [topic] looks like a ThingsBoard server-side RPC request filter.
  /// Accepted forms (case-sensitive, per TB docs):
  ///   v1/devices/me/rpc/request/+
  ///   v1/devices/me/rpc/request/#
  bool get isThingsBoardRpcFilter {
    return topic == 'v1/devices/me/rpc/request/+' ||
        topic == 'v1/devices/me/rpc/request/#';
  }

  SubscriptionConfig copyWith({
    String? topic,
    int? qos,
    bool? enabled,
    bool? autoAck,
    String? label,
  }) {
    return SubscriptionConfig(
      id: id,
      topic: topic ?? this.topic,
      qos: qos ?? this.qos,
      enabled: enabled ?? this.enabled,
      autoAck: autoAck ?? this.autoAck,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic': topic,
      'qos': qos,
      'enabled': enabled,
      'auto_ack': autoAck,
      'label': label,
    };
  }

  factory SubscriptionConfig.fromJson(Map<String, dynamic> json) {
    return SubscriptionConfig(
      id: json['id'] as String?,
      topic: (json['topic'] as String?) ?? '',
      qos: _readQos(json['qos']),
      enabled: (json['enabled'] as bool?) ?? true,
      autoAck: (json['auto_ack'] as bool?) ?? false,
      label: json['label'] as String?,
    );
  }

  /// Clamp incoming qos to 0/1/2; treat unknown / missing as 1 (TB default).
  static int _readQos(dynamic raw) {
    if (raw is int) return raw.clamp(0, 2);
    if (raw is num) return raw.toInt().clamp(0, 2);
    return 1;
  }

  /// Decode the `subscriptions` list off a profile JSON map.
  /// Returns `[]` when the key is absent / wrong type (legacy profiles).
  static List<SubscriptionConfig> listFromProfile(
      Map<String, dynamic> profile) {
    final raw = profile['subscriptions'];
    if (raw is! List) return <SubscriptionConfig>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SubscriptionConfig.fromJson)
        .toList();
  }
}
