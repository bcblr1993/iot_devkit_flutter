import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/digests/sha256.dart';

import '../models/app_release_info.dart';

enum AppUpdateErrorKind {
  network,
  invalidMirrorUrl,
  invalidResponse,
  assetUnavailable,
  checksumMismatch,
  cancelled,
  installerLaunchFailed,
}

class AppUpdateException implements Exception {
  final AppUpdateErrorKind kind;
  final String message;
  final Object? cause;

  const AppUpdateException(this.kind, this.message, [this.cause]);

  @override
  String toString() => 'AppUpdateException($kind): $message';
}

enum InstallActionOutcome {
  launchedInstallerRequiresExit,
  mountedDiskImage,
  openedArchiveDirectory,
}

class UpdateDownloadCancelToken {
  bool _isCancelled = false;
  final List<VoidCallbackLike> _listeners = [];

  bool get isCancelled => _isCancelled;

  void addListener(VoidCallbackLike listener) {
    if (_isCancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in List<VoidCallbackLike>.from(_listeners)) {
      listener();
    }
    _listeners.clear();
  }
}

typedef VoidCallbackLike = void Function();

typedef UpdateProgressCallback = void Function(int receivedBytes, int? totalBytes);

typedef JsonHttpFetcher = Future<Map<String, dynamic>> Function(Uri uri);

typedef BinaryStreamDownloader = Future<void> Function({
  required Uri uri,
  required IOSink sink,
  required void Function(Uint8List chunk) onChunk,
  required UpdateProgressCallback onProgress,
  required UpdateDownloadCancelToken cancelToken,
});

typedef PlatformInstallerRunner = Future<InstallActionOutcome> Function(
  AppUpdatePlatform platform,
  String filePath,
);

typedef FileRevealer = Future<void> Function(
  AppUpdatePlatform platform,
  String filePath,
);

typedef ExternalUrlOpener = Future<void> Function(Uri uri);

class AppUpdateService {
  static final Logger _log = Logger('AppUpdateService');

  static const String defaultRepo = 'bcblr1993/iot_devkit_flutter';
  static const String defaultManifestUrl =
      'https://github.com/$defaultRepo/releases/latest/download/latest.json';
  static const String defaultGitHubApiUrl =
      'https://api.github.com/repos/$defaultRepo/releases/latest';
  static const String defaultReleasesPageUrl =
      'https://github.com/$defaultRepo/releases/latest';

  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _progressThrottle = Duration(milliseconds: 80);

  final JsonHttpFetcher _fetchJson;
  final BinaryStreamDownloader _downloadStream;
  final Future<Directory> Function() _getTempDirectory;
  final PlatformInstallerRunner _runInstaller;
  final FileRevealer _revealFile;
  final ExternalUrlOpener _openUrl;
  final AppUpdatePlatform? _platformOverride;

  AppUpdateService({
    JsonHttpFetcher? fetchJson,
    BinaryStreamDownloader? downloadStream,
    Future<Directory> Function()? getTempDirectory,
    PlatformInstallerRunner? runInstaller,
    FileRevealer? revealFile,
    ExternalUrlOpener? openUrl,
    AppUpdatePlatform? platformOverride,
  })  : _fetchJson = fetchJson ?? _defaultFetchJson,
        _downloadStream = downloadStream ?? _defaultDownloadStream,
        _getTempDirectory = getTempDirectory ?? getTemporaryDirectory,
        _runInstaller = runInstaller ?? _defaultRunInstaller,
        _revealFile = revealFile ?? _defaultRevealFile,
        _openUrl = openUrl ?? _defaultOpenUrl,
        _platformOverride = platformOverride;

  AppUpdatePlatform? get currentPlatform =>
      _platformOverride ?? AppUpdatePlatform.detectCurrent();

  /// Validates and normalizes a user-configured mirror prefix or custom
  /// `latest.json` URL. Returns empty string when [raw] is blank.
  static String normalizeMirrorInput(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const AppUpdateException(
        AppUpdateErrorKind.invalidMirrorUrl,
        'Mirror URL must start with https:// or http://',
      );
    }
    return trimmed;
  }

  /// Resolves an asset download URL using an optional mirror prefix or custom
  /// manifest base URL.
  static Uri resolveAssetDownloadUri(
    String assetUrl, {
    String mirrorInput = '',
  }) {
    final normalizedMirror = normalizeMirrorInput(mirrorInput);
    final parsedAsset = Uri.tryParse(assetUrl.trim());

    if (normalizedMirror.isEmpty) {
      if (parsedAsset == null || !parsedAsset.hasScheme) {
        throw AppUpdateException(
          AppUpdateErrorKind.invalidResponse,
          'Invalid asset download URL: $assetUrl',
        );
      }
      return parsedAsset;
    }

    // Custom manifest endpoint: resolve relative asset paths against it.
    if (normalizedMirror.toLowerCase().endsWith('.json')) {
      final manifestUri = Uri.parse(normalizedMirror);
      if (parsedAsset != null && parsedAsset.hasScheme) {
        return parsedAsset;
      }
      return manifestUri.resolve(assetUrl.trim());
    }

    // GitHub release proxy prefix (e.g. https://ghfast.top): wrap github.com URLs.
    final trimmedAsset = assetUrl.trim();
    if (trimmedAsset.startsWith('https://github.com/') &&
        !trimmedAsset.startsWith(normalizedMirror)) {
      return Uri.parse('$normalizedMirror/$trimmedAsset');
    }

    if (parsedAsset == null || !parsedAsset.hasScheme) {
      throw AppUpdateException(
        AppUpdateErrorKind.invalidResponse,
        'Invalid asset download URL: $assetUrl',
      );
    }
    return parsedAsset;
  }

  /// Queries the latest release metadata, trying `latest.json` first (via
  /// mirror if configured) and falling back to GitHub Releases REST API.
  Future<AppReleaseInfo> fetchLatestRelease({String mirrorInput = ''}) async {
    final normalizedMirror = normalizeMirrorInput(mirrorInput);

    // 1. Direct custom manifest URL (*.json).
    if (normalizedMirror.isNotEmpty &&
        normalizedMirror.toLowerCase().endsWith('.json')) {
      final json = await _fetchJson(Uri.parse(normalizedMirror));
      return _parseManifestOrThrow(json, baseManifestUrl: normalizedMirror);
    }

    // 2. Mirrored GitHub `latest.json` when a mirror prefix is configured.
    if (normalizedMirror.isNotEmpty) {
      final mirroredManifestUri =
          Uri.parse('$normalizedMirror/$defaultManifestUrl');
      try {
        final json = await _fetchJson(mirroredManifestUri);
        return _parseManifestOrThrow(json);
      } catch (e) {
        _log.warning('Mirrored latest.json check failed, falling back: $e');
      }
    }

    // 3. Official GitHub Release `latest.json` asset (no 60 req/hr API limit).
    try {
      final json = await _fetchJson(Uri.parse(defaultManifestUrl));
      return _parseManifestOrThrow(json);
    } catch (e) {
      _log.info('Direct latest.json unavailable, falling back to GitHub API: $e');
    }

    // 4. Fallback to GitHub Releases REST API (supports releases published
    //    before `latest.json` was added to CI).
    try {
      final json = await _fetchJson(Uri.parse(defaultGitHubApiUrl));
      final release = AppReleaseInfo.fromGitHubReleaseJson(json);
      if (release.version.isEmpty) {
        throw const AppUpdateException(
          AppUpdateErrorKind.invalidResponse,
          'GitHub release response is missing tag_name/version.',
        );
      }
      return release;
    } catch (e) {
      if (e is AppUpdateException) rethrow;
      throw AppUpdateException(
        AppUpdateErrorKind.network,
        'Failed to fetch latest release info.',
        e,
      );
    }
  }

  AppReleaseInfo _parseManifestOrThrow(
    Map<String, dynamic> json, {
    String? baseManifestUrl,
  }) {
    final parsed = AppReleaseInfo.fromManifestJson(json);
    if (parsed.version.isEmpty) {
      throw const AppUpdateException(
        AppUpdateErrorKind.invalidResponse,
        'Update manifest is missing version.',
      );
    }
    if (baseManifestUrl == null) return parsed;

    final resolvedAssets = <AppUpdatePlatform, ReleaseAssetInfo>{};
    for (final entry in parsed.assets.entries) {
      final asset = entry.value;
      final resolvedUri = resolveAssetDownloadUri(
        asset.downloadUrl,
        mirrorInput: baseManifestUrl,
      );
      resolvedAssets[entry.key] = ReleaseAssetInfo(
        name: asset.name,
        downloadUrl: resolvedUri.toString(),
        sha256: asset.sha256,
        sizeBytes: asset.sizeBytes,
      );
    }
    return AppReleaseInfo(
      tagName: parsed.tagName,
      version: parsed.version,
      publishedAt: parsed.publishedAt,
      releaseNotes: parsed.releaseNotes,
      htmlUrl: parsed.htmlUrl,
      prerelease: parsed.prerelease,
      assets: Map.unmodifiable(resolvedAssets),
    );
  }

  /// Downloads the platform installer for [release] into `<temp>/iot_devkit_updates/`,
  /// verifies its SHA-256 digest when present, and returns the local file path.
  Future<String> downloadReleaseAsset({
    required AppReleaseInfo release,
    required UpdateProgressCallback onProgress,
    required UpdateDownloadCancelToken cancelToken,
    String mirrorInput = '',
  }) async {
    final platform = currentPlatform;
    final asset = release.assetForPlatform(platform);
    if (platform == null || asset == null || asset.downloadUrl.isEmpty) {
      throw const AppUpdateException(
        AppUpdateErrorKind.assetUnavailable,
        'No installer package found for the current platform.',
      );
    }

    final safeName = sanitizeFileName(
      asset.name.isNotEmpty
          ? asset.name
          : 'iot_devkit_${release.version}_${platform.name}',
    );
    final baseTempDir = await _getTempDirectory();
    final updateDir = Directory(p.join(baseTempDir.path, 'iot_devkit_updates'));
    if (!await updateDir.exists()) {
      await updateDir.create(recursive: true);
    }

    final targetFile = File(p.join(updateDir.path, safeName));
    if (await targetFile.exists() && asset.hasChecksum) {
      final existingHash = await computeFileSha256(targetFile);
      if (existingHash == asset.sha256!.toLowerCase()) {
        final len = await targetFile.length();
        onProgress(len, len);
        return targetFile.path;
      }
      await _tryDelete(targetFile);
    }

    final partFile = File('${targetFile.path}.part');
    await _tryDelete(partFile);

    final downloadUri = resolveAssetDownloadUri(
      asset.downloadUrl,
      mirrorInput: mirrorInput,
    );

    final digest = SHA256Digest();
    final sink = partFile.openWrite();
    try {
      await _downloadStream(
        uri: downloadUri,
        sink: sink,
        onChunk: (chunk) {
          digest.update(chunk, 0, chunk.length);
        },
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      await sink.flush();
      await sink.close();
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      await _tryDelete(partFile);
      if (cancelToken.isCancelled ||
          (e is AppUpdateException && e.kind == AppUpdateErrorKind.cancelled)) {
        throw const AppUpdateException(
          AppUpdateErrorKind.cancelled,
          'Update download was cancelled.',
        );
      }
      if (e is AppUpdateException) rethrow;
      throw AppUpdateException(
        AppUpdateErrorKind.network,
        'Failed to download update package.',
        e,
      );
    }

    if (cancelToken.isCancelled) {
      await _tryDelete(partFile);
      throw const AppUpdateException(
        AppUpdateErrorKind.cancelled,
        'Update download was cancelled.',
      );
    }

    final out = Uint8List(digest.digestSize);
    digest.doFinal(out, 0);
    final actualSha256 = _bytesToHex(out);

    if (asset.hasChecksum && actualSha256 != asset.sha256!.toLowerCase()) {
      await _tryDelete(partFile);
      throw AppUpdateException(
        AppUpdateErrorKind.checksumMismatch,
        'SHA-256 mismatch: expected ${asset.sha256}, got $actualSha256',
      );
    }

    if (await targetFile.exists()) {
      await _tryDelete(targetFile);
    }
    await partFile.rename(targetFile.path);
    return targetFile.path;
  }

  Future<InstallActionOutcome> launchInstaller(String filePath) async {
    final platform = currentPlatform;
    if (platform == null) {
      throw const AppUpdateException(
        AppUpdateErrorKind.installerLaunchFailed,
        'Unsupported desktop platform.',
      );
    }
    final file = File(filePath);
    if (!await file.exists()) {
      throw AppUpdateException(
        AppUpdateErrorKind.installerLaunchFailed,
        'Installer file does not exist: $filePath',
      );
    }
    try {
      return await _runInstaller(platform, filePath);
    } catch (e) {
      if (e is AppUpdateException) rethrow;
      throw AppUpdateException(
        AppUpdateErrorKind.installerLaunchFailed,
        'Failed to launch installer.',
        e,
      );
    }
  }

  Future<void> revealDownloadedFile(String filePath) async {
    final platform = currentPlatform;
    if (platform == null) return;
    await _revealFile(platform, filePath);
  }

  Future<void> openExternalUrl(String rawUrl) async {
    final fallback =
        rawUrl.trim().isEmpty ? defaultReleasesPageUrl : rawUrl.trim();
    final uri = Uri.tryParse(fallback);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw AppUpdateException(
        AppUpdateErrorKind.invalidResponse,
        'Refusing to open non-HTTP(S) URL: $fallback',
      );
    }
    await _openUrl(uri);
  }

  static String sanitizeFileName(String rawName) {
    final base = p.basename(rawName.trim());
    final cleaned = base.replaceAll(RegExp(r'[^A-Za-z0-9._+-]'), '_');
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      return 'iot_devkit_update.pkg';
    }
    return cleaned;
  }

  static Future<String> computeFileSha256(File file) async {
    final digest = SHA256Digest();
    await for (final chunk in file.openRead()) {
      final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
      digest.update(bytes, 0, bytes.length);
    }
    final out = Uint8List(digest.digestSize);
    digest.doFinal(out, 0);
    return _bytesToHex(out);
  }

  static String _bytesToHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final byte in bytes) {
      sb.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static Future<void> _tryDelete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> _defaultFetchJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = _requestTimeout;
    try {
      final req = await client.getUrl(uri).timeout(_requestTimeout);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set(HttpHeaders.userAgentHeader, 'IoT-DevKit-Updater');
      final resp = await req.close().timeout(_requestTimeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        await resp.drain<void>();
        throw AppUpdateException(
          AppUpdateErrorKind.network,
          'HTTP ${resp.statusCode} from $uri',
        );
      }
      final body = await utf8.decoder.bind(resp).join().timeout(_requestTimeout);
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const AppUpdateException(
          AppUpdateErrorKind.invalidResponse,
          'Expected JSON object response.',
        );
      }
      return Map<String, dynamic>.from(decoded);
    } finally {
      client.close(force: false);
    }
  }

  static Future<void> _defaultDownloadStream({
    required Uri uri,
    required IOSink sink,
    required void Function(Uint8List chunk) onChunk,
    required UpdateProgressCallback onProgress,
    required UpdateDownloadCancelToken cancelToken,
  }) async {
    final client = HttpClient()..connectionTimeout = _requestTimeout;
    cancelToken.addListener(() => client.close(force: true));

    try {
      final req = await client.getUrl(uri).timeout(_requestTimeout);
      req.headers.set(HttpHeaders.userAgentHeader, 'IoT-DevKit-Updater');
      final resp = await req.close().timeout(const Duration(seconds: 30));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        await resp.drain<void>();
        throw AppUpdateException(
          AppUpdateErrorKind.network,
          'HTTP ${resp.statusCode} while downloading $uri',
        );
      }

      final total = resp.contentLength > 0 ? resp.contentLength : null;
      var received = 0;
      var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

      await for (final chunk in resp) {
        if (cancelToken.isCancelled) {
          throw const AppUpdateException(
            AppUpdateErrorKind.cancelled,
            'Download cancelled.',
          );
        }
        final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
        onChunk(bytes);
        sink.add(bytes);
        received += bytes.length;

        final now = DateTime.now();
        if (now.difference(lastEmit) >= _progressThrottle) {
          lastEmit = now;
          onProgress(received, total);
        }
      }
      onProgress(received, total ?? received);
    } finally {
      client.close(force: false);
    }
  }

  static Future<InstallActionOutcome> _defaultRunInstaller(
    AppUpdatePlatform platform,
    String filePath,
  ) async {
    switch (platform) {
      case AppUpdatePlatform.windows:
        await Process.start(
          filePath,
          const [],
          mode: ProcessStartMode.detached,
        );
        return InstallActionOutcome.launchedInstallerRequiresExit;
      case AppUpdatePlatform.macos:
        final result = await Process.run('open', [filePath]);
        if (result.exitCode != 0) {
          throw AppUpdateException(
            AppUpdateErrorKind.installerLaunchFailed,
            'open exited with code ${result.exitCode}: ${result.stderr}',
          );
        }
        return InstallActionOutcome.mountedDiskImage;
      case AppUpdatePlatform.linux:
        final result = await Process.run('xdg-open', [p.dirname(filePath)]);
        if (result.exitCode != 0) {
          throw AppUpdateException(
            AppUpdateErrorKind.installerLaunchFailed,
            'xdg-open exited with code ${result.exitCode}: ${result.stderr}',
          );
        }
        return InstallActionOutcome.openedArchiveDirectory;
    }
  }

  static Future<void> _defaultRevealFile(
    AppUpdatePlatform platform,
    String filePath,
  ) async {
    switch (platform) {
      case AppUpdatePlatform.windows:
        await Process.run('explorer.exe', ['/select,$filePath']);
      case AppUpdatePlatform.macos:
        await Process.run('open', ['-R', filePath]);
      case AppUpdatePlatform.linux:
        await Process.run('xdg-open', [p.dirname(filePath)]);
    }
  }

  static Future<void> _defaultOpenUrl(Uri uri) async {
    final url = uri.toString();
    if (Platform.isWindows) {
      await Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    }
  }
}
