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

class JsonSearchResult {
  const JsonSearchResult({
    required this.paths,
    required this.isTruncated,
  });

  final List<List<dynamic>> paths;
  final bool isTruncated;
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

  static Future<JsonSearchResult> search(
    String source,
    String query, {
    int maxMatches = 1000,
  }) {
    return Isolate.run(
      () => searchSync(source, query, maxMatches: maxMatches),
    );
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

  static JsonSearchResult searchSync(
    String source,
    String query, {
    int maxMatches = 1000,
  }) {
    final normalizedQuery = query.toLowerCase();
    if (normalizedQuery.isEmpty || maxMatches <= 0) {
      return const JsonSearchResult(paths: [], isTruncated: false);
    }

    final data = jsonDecode(source);
    final paths = <List<dynamic>>[];
    var isTruncated = false;

    void addMatch(List<dynamic> path) {
      if (paths.length < maxMatches) {
        paths.add(List<dynamic>.from(path));
      } else {
        isTruncated = true;
      }
    }

    void visit(dynamic value, List<dynamic> currentPath) {
      if (isTruncated) {
        return;
      }
      if (value is Map) {
        for (final entry in value.entries) {
          final nextPath = [...currentPath, entry.key];
          if (entry.key.toString().toLowerCase().contains(normalizedQuery)) {
            addMatch(nextPath);
            if (isTruncated) return;
          }
          visit(entry.value, nextPath);
          if (isTruncated) return;
        }
        return;
      }
      if (value is List) {
        for (var index = 0; index < value.length; index++) {
          visit(value[index], [...currentPath, index]);
          if (isTruncated) return;
        }
        return;
      }
      if (value.toString().toLowerCase().contains(normalizedQuery)) {
        addMatch(currentPath);
      }
    }

    visit(data, const []);
    return JsonSearchResult(paths: paths, isTruncated: isTruncated);
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
