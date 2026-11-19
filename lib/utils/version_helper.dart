import 'package:package_info_plus/package_info_plus.dart';

/// Parsed semantic version with build-date metadata separated from SemVer
/// pre-release identifiers so packaged versions like `1.10.7-20261119` compare
/// equal to tag `v1.10.7` instead of sorting below it as a pre-release.
class ParsedAppVersion implements Comparable<ParsedAppVersion> {
  final int major;
  final int minor;
  final int patch;
  final List<String> preRelease;
  final String? buildDate;
  final String? buildMetadata;

  const ParsedAppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease = const [],
    this.buildDate,
    this.buildMetadata,
  });

  bool get isPreRelease => preRelease.isNotEmpty;

  String get coreVersion {
    if (preRelease.isEmpty) {
      return '$major.$minor.$patch';
    }
    return '$major.$minor.$patch-${preRelease.join('.')}';
  }

  @override
  int compareTo(ParsedAppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    // Release > pre-release per SemVer 2.0.
    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;

    final minLen = preRelease.length < other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;
    for (var i = 0; i < minLen; i++) {
      final a = preRelease[i];
      final b = other.preRelease[i];
      if (a == b) continue;

      final aNum = int.tryParse(a);
      final bNum = int.tryParse(b);
      if (aNum != null && bNum != null) {
        return aNum.compareTo(bNum);
      }
      if (aNum != null) return -1;
      if (bNum != null) return 1;
      return a.compareTo(b);
    }
    return preRelease.length.compareTo(other.preRelease.length);
  }
}

class VersionHelper {
  static final RegExp _buildDateSuffixPattern = RegExp(r'-(20\d{6})$');
  static final RegExp _releaseDatePattern = RegExp(r'(20\d{2})(\d{2})(\d{2})');
  static final RegExp _coreVersionPattern =
      RegExp(r'^(\d+)\.(\d+)(?:\.(\d+))?(?:-(.+))?$');

  static Future<String> getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (packageInfo.buildNumber.isEmpty ||
        packageInfo.buildNumber == packageInfo.version) {
      return packageInfo.version;
    }
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }

  static Future<String> getAppName() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.appName;
  }

  static String? releaseDateFromVersion(String version) {
    final match = _releaseDatePattern.firstMatch(version);
    if (match == null) {
      return null;
    }
    return '${match.group(1)}-${match.group(2)}-${match.group(3)}';
  }

  /// Parses version strings such as `v1.11.0`, `1.10.7-20261119+42`, or
  /// `1.11.0-rc.1-20261119`. Returns null when [raw] has no valid major.minor.
  static ParsedAppVersion? tryParse(String raw) {
    var cleaned = raw.trim();
    if (cleaned.isEmpty) return null;
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1).trim();
    }

    String? buildMetadata;
    final plusIndex = cleaned.indexOf('+');
    if (plusIndex >= 0) {
      buildMetadata = cleaned.substring(plusIndex + 1);
      cleaned = cleaned.substring(0, plusIndex);
    }

    String? buildDate;
    final dateMatch = _buildDateSuffixPattern.firstMatch(cleaned);
    if (dateMatch != null) {
      buildDate = dateMatch.group(1);
      cleaned = cleaned.substring(0, dateMatch.start);
    }

    final match = _coreVersionPattern.firstMatch(cleaned);
    if (match == null) return null;

    final major = int.tryParse(match.group(1)!);
    final minor = int.tryParse(match.group(2)!);
    final patch =
        match.group(3) != null ? int.tryParse(match.group(3)!) : 0;
    if (major == null || minor == null || patch == null) return null;

    final preRaw = match.group(4);
    final preRelease = (preRaw == null || preRaw.isEmpty)
        ? const <String>[]
        : preRaw
            .split('.')
            .where((part) => part.isNotEmpty)
            .toList(growable: false);

    return ParsedAppVersion(
      major: major,
      minor: minor,
      patch: patch,
      preRelease: preRelease,
      buildDate: buildDate,
      buildMetadata: buildMetadata,
    );
  }

  /// Returns canonical `major.minor.patch` (with pre-release if any), stripping
  /// leading `v`, `+build`, and `-YYYYMMDD` build-date suffix.
  static String normalizeVersion(String raw) {
    final parsed = tryParse(raw);
    if (parsed != null) return parsed.coreVersion;
    final trimmed = raw.trim();
    if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
      return trimmed.substring(1);
    }
    return trimmed;
  }

  /// Compares two version strings. Returns > 0 if [a] > [b], < 0 if [a] < [b],
  /// and 0 if equivalent.
  static int compareVersions(String a, String b) {
    final parsedA = tryParse(a);
    final parsedB = tryParse(b);
    if (parsedA != null && parsedB != null) {
      return parsedA.compareTo(parsedB);
    }
    return normalizeVersion(a).compareTo(normalizeVersion(b));
  }

  /// Returns true when [candidate] is strictly newer than [current].
  static bool isNewerVersion({
    required String current,
    required String candidate,
  }) {
    final parsedCurrent = tryParse(current);
    final parsedCandidate = tryParse(candidate);
    if (parsedCurrent == null || parsedCandidate == null) {
      return false;
    }
    return parsedCandidate.compareTo(parsedCurrent) > 0;
  }
}
