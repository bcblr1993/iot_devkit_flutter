import 'dart:convert';
import 'dart:isolate';

enum JsonOutputStyle { pretty, compact }

class JsonFormatResult {
  const JsonFormatResult({
    required this.output,
    required this.data,
  });

  final String output;
  final dynamic data;
}

class JsonFormatterService {
  const JsonFormatterService._();

  static Future<JsonFormatResult> transform(
    String source,
    JsonOutputStyle style,
  ) {
    return Isolate.run(() => transformSync(source, style));
  }

  static Future<dynamic> parse(String source) {
    return Isolate.run(() => jsonDecode(source));
  }

  static JsonFormatResult transformSync(
    String source,
    JsonOutputStyle style,
  ) {
    final data = jsonDecode(source);
    final encoder = style == JsonOutputStyle.pretty
        ? const JsonEncoder.withIndent('    ')
        : const JsonEncoder();
    var output = encoder.convert(data);

    // Avoid replacing an already-formatted large document solely because the
    // encoder uses LF while the source file uses CRLF.
    if (style == JsonOutputStyle.pretty && _usesOnlyCrLf(source)) {
      output = output.replaceAll('\n', '\r\n');
    }

    return JsonFormatResult(output: output, data: data);
  }

  static bool _usesOnlyCrLf(String source) {
    final firstNewline = source.indexOf('\n');
    if (firstNewline < 0) {
      return false;
    }

    for (var index = firstNewline; index < source.length; index++) {
      if (source.codeUnitAt(index) == 0x0A &&
          (index == 0 || source.codeUnitAt(index - 1) != 0x0D)) {
        return false;
      }
    }
    return true;
  }
}
