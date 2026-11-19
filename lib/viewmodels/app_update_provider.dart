import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../models/app_release_info.dart';
import '../services/app_update_service.dart';
import '../utils/version_helper.dart';

enum AppUpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  readyToInstall,
  installing,
  error,
}

class AppUpdateProvider extends ChangeNotifier {
  static final Logger _log = Logger('AppUpdateProvider');

  static const String prefAutoCheck = 'update_auto_check';
  static const String prefSkippedVersion = 'update_skipped_version';
  static const String prefMirrorUrl = 'update_mirror_url';
  static const String prefLastCheckEpochMs = 'update_last_check_ms';

  static const Duration _mirrorDebounceDuration = Duration(milliseconds: 600);

  final AppUpdateService _service;
  final Future<String> Function() _versionLoader;
  final Future<void> Function() _exitApp;
  final bool autoCheckOnStart;
  final Duration startupCheckDelay;

  String _currentVersion = '';
  AppUpdatePhase _phase = AppUpdatePhase.idle;
  AppReleaseInfo? _latestRelease;
  AppUpdateErrorKind? _errorKind;
  String? _errorDetail;

  bool _autoCheckEnabled = true;
  String _skippedVersion = '';
  String _mirrorUrl = '';
  DateTime? _lastCheckedAt;
  bool _bannerDismissedForSession = false;

  int _downloadedBytes = 0;
  int? _totalBytes;
  String? _downloadedFilePath;
  InstallActionOutcome? _lastInstallOutcome;

  UpdateDownloadCancelToken? _cancelToken;
  Timer? _startupCheckTimer;
  Timer? _mirrorSaveDebounce;
  bool _disposed = false;

  AppUpdateProvider({
    AppUpdateService? service,
    Future<String> Function()? versionLoader,
    Future<void> Function()? exitApp,
    this.autoCheckOnStart = true,
    this.startupCheckDelay = const Duration(seconds: 2),
  })  : _service = service ?? AppUpdateService(),
        _versionLoader = versionLoader ?? VersionHelper.getAppVersion,
        _exitApp = exitApp ?? _defaultExitApplication;

  String get currentVersion => _currentVersion;
  String get normalizedCurrentVersion =>
      VersionHelper.normalizeVersion(_currentVersion);
  AppUpdatePhase get phase => _phase;
  AppReleaseInfo? get latestRelease => _latestRelease;
  AppUpdateErrorKind? get errorKind => _errorKind;
  String? get errorDetail => _errorDetail;

  bool get autoCheckEnabled => _autoCheckEnabled;
  String get skippedVersion => _skippedVersion;
  String get mirrorUrl => _mirrorUrl;
  DateTime? get lastCheckedAt => _lastCheckedAt;
  AppUpdatePlatform? get currentPlatform => _service.currentPlatform;

  int get downloadedBytes => _downloadedBytes;
  int? get totalBytes => _totalBytes;
  String? get downloadedFilePath => _downloadedFilePath;
  InstallActionOutcome? get lastInstallOutcome => _lastInstallOutcome;

  double? get downloadProgress {
    final total = _totalBytes;
    if (total == null || total <= 0) return null;
    return (_downloadedBytes / total).clamp(0.0, 1.0);
  }

  ReleaseAssetInfo? get currentPlatformAsset =>
      _latestRelease?.assetForPlatform(_service.currentPlatform);

  bool get hasUpdate {
    final release = _latestRelease;
    if (release == null || _currentVersion.isEmpty) return false;
    return VersionHelper.isNewerVersion(
      current: _currentVersion,
      candidate: release.version,
    );
  }

  /// True when a newer version is available and has not been permanently
  /// skipped by the user. Drives the Settings gear dot & menu badge.
  bool get hasBadgeUpdate {
    if (!hasUpdate) return false;
    return _skippedVersion != _latestRelease!.version;
  }

  /// True when the global bottom update bar should be visible.
  bool get shouldShowBottomBanner {
    if (_phase == AppUpdatePhase.downloading ||
        _phase == AppUpdatePhase.readyToInstall) {
      return true;
    }
    return hasBadgeUpdate && !_bannerDismissedForSession;
  }

  Future<void> initialize() async {
    try {
      _currentVersion = await _versionLoader();
    } catch (e) {
      _log.warning('Failed to read current version: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _autoCheckEnabled = prefs.getBool(prefAutoCheck) ?? true;
      _skippedVersion = prefs.getString(prefSkippedVersion) ?? '';
      _mirrorUrl = prefs.getString(prefMirrorUrl) ?? '';
      final lastEpoch = prefs.getInt(prefLastCheckEpochMs);
      if (lastEpoch != null && lastEpoch > 0) {
        _lastCheckedAt = DateTime.fromMillisecondsSinceEpoch(lastEpoch);
      }
    } catch (e) {
      _log.warning('Failed to load update preferences: $e');
    }

    if (_disposed) return;
    notifyListeners();

    if (autoCheckOnStart && _autoCheckEnabled) {
      _startupCheckTimer?.cancel();
      _startupCheckTimer = Timer(startupCheckDelay, () {
        if (!_disposed) {
          checkForUpdates(manual: false);
        }
      });
    }
  }

  Future<void> checkForUpdates({bool manual = true}) async {
    if (_phase == AppUpdatePhase.checking ||
        _phase == AppUpdatePhase.downloading ||
        _phase == AppUpdatePhase.installing) {
      return;
    }

    if (_currentVersion.isEmpty) {
      try {
        _currentVersion = await _versionLoader();
      } catch (_) {}
    }

    if (manual) {
      _bannerDismissedForSession = false;
    }

    _errorKind = null;
    _errorDetail = null;
    _phase = AppUpdatePhase.checking;
    _safeNotify();

    try {
      final release = await _service.fetchLatestRelease(mirrorInput: _mirrorUrl);
      if (_disposed) return;

      _latestRelease = release;
      _lastCheckedAt = DateTime.now();
      unawaited(_persistLastCheck(_lastCheckedAt!));

      final newer = _currentVersion.isNotEmpty &&
          VersionHelper.isNewerVersion(
            current: _currentVersion,
            candidate: release.version,
          );

      if (newer) {
        if (manual && _skippedVersion == release.version) {
          // Manual check clears a previously skipped flag for this version so
          // the user can act on it right away.
          _skippedVersion = '';
          unawaited(_persistString(prefSkippedVersion, ''));
        }
        _downloadedFilePath = null;
        _downloadedBytes = 0;
        _totalBytes = release.assetForPlatform(_service.currentPlatform)?.sizeBytes;
        _phase = AppUpdatePhase.available;
      } else {
        _phase = AppUpdatePhase.upToDate;
      }
      _safeNotify();
    } on AppUpdateException catch (e) {
      if (_disposed) return;
      _log.warning('Update check failed: $e');
      if (manual) {
        _errorKind = e.kind;
        _errorDetail = e.message;
        _phase = AppUpdatePhase.error;
      } else {
        _phase = AppUpdatePhase.idle;
      }
      _safeNotify();
    } catch (e) {
      if (_disposed) return;
      _log.warning('Unexpected update check error: $e');
      if (manual) {
        _errorKind = AppUpdateErrorKind.network;
        _errorDetail = e.toString();
        _phase = AppUpdatePhase.error;
      } else {
        _phase = AppUpdatePhase.idle;
      }
      _safeNotify();
    }
  }

  Future<void> startDownload() async {
    final release = _latestRelease;
    if (release == null || _phase == AppUpdatePhase.downloading) return;

    final token = UpdateDownloadCancelToken();
    _cancelToken = token;
    _errorKind = null;
    _errorDetail = null;
    _downloadedBytes = 0;
    _totalBytes = currentPlatformAsset?.sizeBytes;
    _downloadedFilePath = null;
    _lastInstallOutcome = null;
    _phase = AppUpdatePhase.downloading;
    _safeNotify();

    try {
      final path = await _service.downloadReleaseAsset(
        release: release,
        mirrorInput: _mirrorUrl,
        cancelToken: token,
        onProgress: (received, total) {
          if (_disposed) return;
          _downloadedBytes = received;
          if (total != null && total > 0) {
            _totalBytes = total;
          }
          _safeNotify();
        },
      );
      if (_disposed) return;
      _cancelToken = null;
      _downloadedFilePath = path;
      _phase = AppUpdatePhase.readyToInstall;
      _safeNotify();
    } on AppUpdateException catch (e) {
      if (_disposed) return;
      _cancelToken = null;
      if (e.kind == AppUpdateErrorKind.cancelled) {
        _downloadedBytes = 0;
        _phase = hasUpdate ? AppUpdatePhase.available : AppUpdatePhase.idle;
      } else {
        _errorKind = e.kind;
        _errorDetail = e.message;
        _phase = AppUpdatePhase.error;
      }
      _safeNotify();
    } catch (e) {
      if (_disposed) return;
      _cancelToken = null;
      _errorKind = AppUpdateErrorKind.network;
      _errorDetail = e.toString();
      _phase = AppUpdatePhase.error;
      _safeNotify();
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel();
    _cancelToken = null;
  }

  Future<InstallActionOutcome?> installUpdate({
    Future<void> Function()? onBeforeExitApp,
  }) async {
    final filePath = _downloadedFilePath;
    if (filePath == null || _phase == AppUpdatePhase.installing) return null;

    _errorKind = null;
    _errorDetail = null;
    _phase = AppUpdatePhase.installing;
    _safeNotify();

    try {
      if (_service.currentPlatform == AppUpdatePlatform.windows &&
          onBeforeExitApp != null) {
        await onBeforeExitApp();
      }
      final outcome = await _service.launchInstaller(filePath);
      if (_disposed) return outcome;
      _lastInstallOutcome = outcome;

      if (outcome == InstallActionOutcome.launchedInstallerRequiresExit) {
        await _exitApp();
        return outcome;
      }

      _phase = AppUpdatePhase.readyToInstall;
      _safeNotify();
      return outcome;
    } on AppUpdateException catch (e) {
      if (_disposed) return null;
      _errorKind = e.kind;
      _errorDetail = e.message;
      _phase = AppUpdatePhase.error;
      _safeNotify();
      return null;
    } catch (e) {
      if (_disposed) return null;
      _errorKind = AppUpdateErrorKind.installerLaunchFailed;
      _errorDetail = e.toString();
      _phase = AppUpdatePhase.error;
      _safeNotify();
      return null;
    }
  }

  Future<void> revealDownloadedPackage() async {
    final filePath = _downloadedFilePath;
    if (filePath == null) return;
    await _service.revealDownloadedFile(filePath);
  }

  Future<void> openReleasePageInBrowser() async {
    final url = _latestRelease?.htmlUrl ?? AppUpdateService.defaultReleasesPageUrl;
    await _service.openExternalUrl(url);
  }

  void dismissBannerForSession() {
    if (_bannerDismissedForSession) return;
    _bannerDismissedForSession = true;
    _safeNotify();
  }

  Future<void> skipAvailableVersion() async {
    final version = _latestRelease?.version;
    if (version == null || version.isEmpty) return;
    _skippedVersion = version;
    _bannerDismissedForSession = true;
    _safeNotify();
    await _persistString(prefSkippedVersion, version);
  }

  Future<void> setAutoCheckEnabled(bool enabled) async {
    if (_autoCheckEnabled == enabled) return;
    _autoCheckEnabled = enabled;
    _safeNotify();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefAutoCheck, enabled);
    } catch (e) {
      _log.warning('Failed to save auto-check setting: $e');
    }
  }

  void setMirrorUrl(String value) {
    if (_mirrorUrl == value) return;
    _mirrorUrl = value;
    _safeNotify();

    _mirrorSaveDebounce?.cancel();
    _mirrorSaveDebounce = Timer(_mirrorDebounceDuration, () {
      _persistString(prefMirrorUrl, value.trim());
    });
  }

  Future<void> _persistLastCheck(DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prefLastCheckEpochMs, timestamp.millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _persistString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      _log.warning('Failed to persist $key: $e');
    }
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  static Future<void> _defaultExitApplication() async {
    try {
      await LogStorageDebugFlush.flush();
      await windowManager.destroy();
    } catch (_) {}
    exit(0);
  }

  @override
  void dispose() {
    _disposed = true;
    _startupCheckTimer?.cancel();
    _mirrorSaveDebounce?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }
}

class LogStorageDebugFlush {
  static Future<void> flush() async {
    // Allow pending async file writes/logs to settle briefly before process exit.
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }
}
