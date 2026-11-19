import 'dart:io';

import '../utils/version_helper.dart';

enum AppUpdatePlatform {
  macos,
  windows,
  linux;

  static AppUpdatePlatform? detectCurrent() {
    if (Platform.isMacOS) return AppUpdatePlatform.macos;
    if (Platform.isWindows) return AppUpdatePlatform.windows;
    if (Platform.isLinux) return AppUpdatePlatform.linux;
    return null;
  }

  static AppUpdatePlatform? fromKey(String key) {
    return switch (key.trim().toLowerCase()) {
      'macos' || 'darwin' || 'osx' => AppUpdatePlatform.macos,
      'windows' || 'win' || 'win64' => AppUpdatePlatform.windows,
      'linux' => AppUpdatePlatform.linux,
      _ => null,
    };
  }
}

class ReleaseAssetInfo {
  final String name;
  final String downloadUrl;
  final String? sha256;
  final int? sizeBytes;

  const ReleaseAssetInfo({
    required this.name,
    required this.downloadUrl,
    this.sha256,
    this.sizeBytes,
  });

  bool get hasChecksum => sha256 != null && sha256!.trim().length == 64;

  String? get formattedSize {
    final bytes = sizeBytes;
    if (bytes == null || bytes <= 0) return null;
    return formatByteCount(bytes);
  }

  static String formatByteCount(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  factory ReleaseAssetInfo.fromManifestJson(Map<String, dynamic> json) {
    final rawSha = (json['sha256'] as String?)?.trim();
    final cleanSha = _extractSha256Hex(rawSha);
    return ReleaseAssetInfo(
      name: (json['name'] as String? ?? '').trim(),
      downloadUrl: (json['url'] as String? ?? '').trim(),
      sha256: cleanSha,
      sizeBytes: _asInt(json['size']),
    );
  }

  factory ReleaseAssetInfo.fromGitHubAssetJson(Map<String, dynamic> json) {
    final digest = (json['digest'] as String?)?.trim();
    return ReleaseAssetInfo(
      name: (json['name'] as String? ?? '').trim(),
      downloadUrl: (json['browser_download_url'] as String? ?? '').trim(),
      sha256: _extractSha256Hex(digest),
      sizeBytes: _asInt(json['size']),
    );
  }

  static String? _extractSha256Hex(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.trim();
    final candidate = trimmed.toLowerCase().startsWith('sha256:')
        ? trimmed.substring('sha256:'.length).trim()
        : trimmed;
    if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(candidate)) {
      return candidate.toLowerCase();
    }
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class AppReleaseInfo {
  final String tagName;
  final String version;
  final String? publishedAt;
  final String releaseNotes;
  final String htmlUrl;
  final bool prerelease;
  final Map<AppUpdatePlatform, ReleaseAssetInfo> assets;

  const AppReleaseInfo({
    required this.tagName,
    required this.version,
    required this.releaseNotes,
    required this.htmlUrl,
    required this.assets,
    this.publishedAt,
    this.prerelease = false,
  });

  ReleaseAssetInfo? assetForPlatform(AppUpdatePlatform? platform) {
    if (platform == null) return null;
    return assets[platform];
  }

  /// Parses the CI-generated `latest.json` manifest attached to GitHub Releases
  /// or hosted on a custom mirror/CDN.
  factory AppReleaseInfo.fromManifestJson(Map<String, dynamic> json) {
    final rawTag = (json['tag'] as String? ?? '').trim();
    final rawVersion = (json['version'] as String? ?? rawTag).trim();
    final version = VersionHelper.normalizeVersion(rawVersion);
    final tagName = rawTag.isNotEmpty ? rawTag : 'v$version';

    final platformsMap = <AppUpdatePlatform, ReleaseAssetInfo>{};
    final rawPlatforms = json['platforms'];
    if (rawPlatforms is Map) {
      for (final entry in rawPlatforms.entries) {
        final platform = AppUpdatePlatform.fromKey('${entry.key}');
        final value = entry.value;
        if (platform != null && value is Map) {
          final asset = ReleaseAssetInfo.fromManifestJson(
            Map<String, dynamic>.from(value),
          );
          if (asset.downloadUrl.isNotEmpty) {
            platformsMap[platform] = asset;
          }
        }
      }
    }

    return AppReleaseInfo(
      tagName: tagName,
      version: version,
      publishedAt: _normalizeDateString(json['publishedAt'] as String?),
      releaseNotes: (json['notes'] as String? ?? '').trim(),
      htmlUrl: (json['htmlUrl'] as String? ?? '').trim(),
      prerelease: json['prerelease'] == true,
      assets: Map.unmodifiable(platformsMap),
    );
  }

  /// Parses GitHub REST API `/repos/{owner}/{repo}/releases/latest` response.
  factory AppReleaseInfo.fromGitHubReleaseJson(Map<String, dynamic> json) {
    final rawTag = (json['tag_name'] as String? ?? '').trim();
    final version = VersionHelper.normalizeVersion(rawTag);
    final tagName = rawTag.isNotEmpty ? rawTag : 'v$version';

    final platformsMap = <AppUpdatePlatform, ReleaseAssetInfo>{};
    final rawAssets = json['assets'];
    if (rawAssets is List) {
      for (final item in rawAssets) {
        if (item is! Map) continue;
        final asset = ReleaseAssetInfo.fromGitHubAssetJson(
          Map<String, dynamic>.from(item),
        );
        if (asset.name.isEmpty || asset.downloadUrl.isEmpty) continue;
        final platform = inferPlatformFromAssetName(asset.name);
        if (platform != null) {
          final existing = platformsMap[platform];
          if (existing == null || _isPreferredAsset(platform, asset.name)) {
            platformsMap[platform] = asset;
          }
        }
      }
    }

    return AppReleaseInfo(
      tagName: tagName,
      version: version,
      publishedAt: _normalizeDateString(json['published_at'] as String?),
      releaseNotes: (json['body'] as String? ?? '').trim(),
      htmlUrl: (json['html_url'] as String? ?? '').trim(),
      prerelease: json['prerelease'] == true,
      assets: Map.unmodifiable(platformsMap),
    );
  }

  static AppUpdatePlatform? inferPlatformFromAssetName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower == 'latest.json' ||
        lower.endsWith('.sha256') ||
        lower == 'sha256sums.txt') {
      return null;
    }
    if (lower.endsWith('.dmg') ||
        (lower.contains('macos') && lower.endsWith('.zip'))) {
      return AppUpdatePlatform.macos;
    }
    if (lower.endsWith('.exe') || lower.endsWith('.msi')) {
      return AppUpdatePlatform.windows;
    }
    if (lower.endsWith('.tar.gz') ||
        lower.endsWith('.deb') ||
        lower.endsWith('.appimage')) {
      return AppUpdatePlatform.linux;
    }
    return null;
  }

  static bool _isPreferredAsset(AppUpdatePlatform platform, String fileName) {
    final lower = fileName.toLowerCase();
    return switch (platform) {
      AppUpdatePlatform.macos => lower.endsWith('.dmg'),
      AppUpdatePlatform.windows => lower.endsWith('.exe'),
      AppUpdatePlatform.linux => lower.endsWith('.tar.gz'),
    };
  }

  static String? _normalizeDateString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      return trimmed;
    }
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return trimmed;
    final local = parsed.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
