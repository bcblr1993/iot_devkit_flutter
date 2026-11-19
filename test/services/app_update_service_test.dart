import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/models/app_release_info.dart';
import 'package:iot_devkit/services/app_update_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('iot_devkit_update_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('fetches latest.json manifest and parses platform assets', () async {
    final requestedUris = <Uri>[];
    final service = AppUpdateService(
      platformOverride: AppUpdatePlatform.macos,
      getTempDirectory: () async => tempDir,
      fetchJson: (uri) async {
        requestedUris.add(uri);
        return {
          'version': '1.11.0',
          'tag': 'v1.11.0',
          'publishedAt': '2026-11-19',
          'htmlUrl':
              'https://github.com/bcblr1993/iot_devkit_flutter/releases/tag/v1.11.0',
          'notes': '## 新增\n- 支持应用内更新',
          'platforms': {
            'macos': {
              'name': 'iot_devkit-1.11.0-macos.dmg',
              'url':
                  'https://github.com/bcblr1993/iot_devkit_flutter/releases/download/v1.11.0/iot_devkit-1.11.0-macos.dmg',
              'sha256':
                  'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
              'size': 3,
            },
            'windows': {
              'name': 'iot_devkit-1.11.0-windows.exe',
              'url':
                  'https://github.com/bcblr1993/iot_devkit_flutter/releases/download/v1.11.0/iot_devkit-1.11.0-windows.exe',
              'sha256':
                  'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
              'size': 3,
            },
          },
        };
      },
    );

    final release = await service.fetchLatestRelease();

    expect(requestedUris.single.toString(), AppUpdateService.defaultManifestUrl);
    expect(release.version, '1.11.0');
    expect(release.publishedAt, '2026-11-19');
    expect(
      release.assetForPlatform(AppUpdatePlatform.macos)?.name,
      'iot_devkit-1.11.0-macos.dmg',
    );
    expect(
      release.assetForPlatform(AppUpdatePlatform.macos)?.hasChecksum,
      isTrue,
    );
  });

  test('falls back to GitHub Releases API when latest.json is missing',
      () async {
    final requestedUris = <Uri>[];
    final service = AppUpdateService(
      platformOverride: AppUpdatePlatform.windows,
      getTempDirectory: () async => tempDir,
      fetchJson: (uri) async {
        requestedUris.add(uri);
        if (uri.toString().endsWith('latest.json')) {
          throw const AppUpdateException(
            AppUpdateErrorKind.network,
            'HTTP 404',
          );
        }
        return {
          'tag_name': 'v1.10.7',
          'published_at': '2026-11-18T12:00:00Z',
          'html_url':
              'https://github.com/bcblr1993/iot_devkit_flutter/releases/tag/v1.10.7',
          'body': '## 修复\n- 证书校验优化',
          'assets': [
            {
              'name': 'iot_devkit-1.10.7-20261118-windows.exe',
              'browser_download_url':
                  'https://github.com/bcblr1993/iot_devkit_flutter/releases/download/v1.10.7/iot_devkit-1.10.7-20261118-windows.exe',
              'size': 20971520,
              'digest':
                  'sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
            },
            {
              'name': 'iot_devkit_linux.tar.gz',
              'browser_download_url':
                  'https://github.com/bcblr1993/iot_devkit_flutter/releases/download/v1.10.7/iot_devkit_linux.tar.gz',
              'size': 15728640,
            },
          ],
        };
      },
    );

    final release = await service.fetchLatestRelease();

    expect(requestedUris.length, 2);
    expect(release.version, '1.10.7');
    expect(
      release.assetForPlatform(AppUpdatePlatform.windows)?.sha256,
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      release.assetForPlatform(AppUpdatePlatform.linux)?.name,
      'iot_devkit_linux.tar.gz',
    );
  });

  test('rewrites GitHub URLs with mirror prefix and resolves custom manifest',
      () async {
    final mirrored = AppUpdateService.resolveAssetDownloadUri(
      'https://github.com/bcblr1993/iot_devkit_flutter/releases/download/v1.11.0/app.dmg',
      mirrorInput: 'https://ghfast.top/',
    );
    expect(
      mirrored.toString(),
      'https://ghfast.top/https://github.com/bcblr1993/iot_devkit_flutter/releases/download/v1.11.0/app.dmg',
    );

    final customRelative = AppUpdateService.resolveAssetDownloadUri(
      'packages/iot_devkit-1.11.0-windows.exe',
      mirrorInput: 'https://cdn.example.com/iot/latest.json',
    );
    expect(
      customRelative.toString(),
      'https://cdn.example.com/iot/packages/iot_devkit-1.11.0-windows.exe',
    );

    expect(
      () => AppUpdateService.normalizeMirrorInput('ftp://bad.example.com'),
      throwsA(
        isA<AppUpdateException>().having(
          (e) => e.kind,
          'kind',
          AppUpdateErrorKind.invalidMirrorUrl,
        ),
      ),
    );
  });

  test('verifies SHA-256 on download and reuses verified cached package',
      () async {
    // SHA-256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
    const expectedSha =
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
    var downloadCallCount = 0;

    final service = AppUpdateService(
      platformOverride: AppUpdatePlatform.macos,
      getTempDirectory: () async => tempDir,
      downloadStream: ({
        required uri,
        required sink,
        required onChunk,
        required onProgress,
        required cancelToken,
      }) async {
        downloadCallCount++;
        final bytes = Uint8List.fromList(utf8.encode('abc'));
        onChunk(bytes);
        sink.add(bytes);
        onProgress(bytes.length, bytes.length);
      },
    );

    const release = AppReleaseInfo(
      tagName: 'v1.11.0',
      version: '1.11.0',
      releaseNotes: 'notes',
      htmlUrl: 'https://github.com/bcblr1993/iot_devkit_flutter/releases',
      assets: {
        AppUpdatePlatform.macos: ReleaseAssetInfo(
          name: 'iot_devkit-1.11.0.dmg',
          downloadUrl:
              'https://github.com/bcblr1993/iot_devkit_flutter/releases/download/v1.11.0/iot_devkit-1.11.0.dmg',
          sha256: expectedSha,
          sizeBytes: 3,
        ),
      },
    );

    final path1 = await service.downloadReleaseAsset(
      release: release,
      onProgress: (_, __) {},
      cancelToken: UpdateDownloadCancelToken(),
    );
    expect(File(path1).existsSync(), isTrue);
    expect(downloadCallCount, 1);

    // Second call hits verified cache without downloading again.
    final path2 = await service.downloadReleaseAsset(
      release: release,
      onProgress: (_, __) {},
      cancelToken: UpdateDownloadCancelToken(),
    );
    expect(path2, path1);
    expect(downloadCallCount, 1);
  });

  test('deletes partial file and throws on SHA-256 mismatch', () async {
    final service = AppUpdateService(
      platformOverride: AppUpdatePlatform.windows,
      getTempDirectory: () async => tempDir,
      downloadStream: ({
        required uri,
        required sink,
        required onChunk,
        required onProgress,
        required cancelToken,
      }) async {
        final bytes = Uint8List.fromList(utf8.encode('tampered-binary'));
        onChunk(bytes);
        sink.add(bytes);
        onProgress(bytes.length, bytes.length);
      },
    );

    const release = AppReleaseInfo(
      tagName: 'v1.11.0',
      version: '1.11.0',
      releaseNotes: 'notes',
      htmlUrl: 'https://github.com/bcblr1993/iot_devkit_flutter/releases',
      assets: {
        AppUpdatePlatform.windows: ReleaseAssetInfo(
          name: 'iot_devkit-1.11.0-windows.exe',
          downloadUrl:
              'https://github.com/bcblr1993/iot_devkit_flutter/releases/download/v1.11.0/iot_devkit-1.11.0-windows.exe',
          sha256:
              '0000000000000000000000000000000000000000000000000000000000000000',
          sizeBytes: 15,
        ),
      },
    );

    await expectLater(
      service.downloadReleaseAsset(
        release: release,
        onProgress: (_, __) {},
        cancelToken: UpdateDownloadCancelToken(),
      ),
      throwsA(
        isA<AppUpdateException>().having(
          (e) => e.kind,
          'kind',
          AppUpdateErrorKind.checksumMismatch,
        ),
      ),
    );

    final updatesDir = Directory(p.join(tempDir.path, 'iot_devkit_updates'));
    expect(updatesDir.listSync(), isEmpty);
  });

  test('rejects non-http schemes in openExternalUrl', () async {
    final opened = <Uri>[];
    final service = AppUpdateService(
      openUrl: (uri) async => opened.add(uri),
    );

    await expectLater(
      service.openExternalUrl('file:///etc/passwd'),
      throwsA(isA<AppUpdateException>()),
    );
    expect(opened, isEmpty);

    await service.openExternalUrl(
      'https://github.com/bcblr1993/iot_devkit_flutter/releases',
    );
    expect(opened.single.host, 'github.com');
  });
}
