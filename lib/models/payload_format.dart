/// ThingsBoard telemetry payload format identifiers and shaping helpers.
///
/// The three standard ThingsBoard formats:
///   · [simpleKv]      `{"temperature": 22.5, "humidity": 61}`
///   · [timestamped]   `{"ts": 1451649600512, "values": {...}}`
///   · [array]         `[{"ts": 1451649600512, "values": {...}}]`
///
/// Plus the legacy custom "TieNiu" formats ([tieNiu] / [tieNiuEmpty]) which are
/// generated separately and left unchanged.
class PayloadFormat {
  PayloadFormat._();

  /// Simple key-value — server records the receive time as the timestamp.
  static const String simpleKv = 'tb-kv';

  /// Object with a client-side millisecond `ts` and a `values` map.
  static const String timestamped = 'tb-ts';

  /// Array of one client-side-timestamped reading.
  static const String array = 'tb-array';

  /// TieNiu custom formats (unchanged).
  static const String tieNiu = 'tn';
  static const String tieNiuEmpty = 'tn-empty';

  /// Normalize a stored format string. The legacy value `'default'` produced a
  /// `ts`+`values` object, so it maps to [timestamped]. null / empty / unknown
  /// also default to [timestamped] so a selector always has a valid value.
  static String normalize(String? format) {
    switch (format) {
      case null:
      case '':
      case 'default':
        return timestamped;
      default:
        return format;
    }
  }

  /// Shape a flat [values] map into the selected standard TB payload. Handles
  /// [simpleKv] / [timestamped] / [array] only; TieNiu formats are generated
  /// by their own dedicated generators.
  static Object buildStandard(
    Map<String, dynamic> values,
    int timestamp,
    String format,
  ) {
    switch (normalize(format)) {
      case simpleKv:
        return values;
      case array:
        return <Map<String, dynamic>>[
          {'ts': timestamp, 'values': values},
        ];
      case timestamped:
      default:
        return <String, dynamic>{'ts': timestamp, 'values': values};
    }
  }
}
