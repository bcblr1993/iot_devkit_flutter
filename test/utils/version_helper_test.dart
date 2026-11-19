import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/utils/version_helper.dart';

void main() {
  test('extracts release date from packaged version', () {
    expect(
      VersionHelper.releaseDateFromVersion('1.10.4-20260723'),
      '2026-07-23',
    );
    expect(
      VersionHelper.releaseDateFromVersion('1.10.4-20260723+42'),
      '2026-07-23',
    );
  });

  test('returns null when a development version has no build date', () {
    expect(VersionHelper.releaseDateFromVersion('1.10.4'), isNull);
  });

  test('treats packaged build date suffix as equal to bare release tag', () {
    expect(VersionHelper.normalizeVersion('v1.10.7'), '1.10.7');
    expect(VersionHelper.normalizeVersion('1.10.7-20261119+42'), '1.10.7');
    expect(
      VersionHelper.compareVersions('1.10.7-20261119', 'v1.10.7'),
      0,
    );
    expect(
      VersionHelper.isNewerVersion(
        current: '1.10.7-20261119',
        candidate: 'v1.10.7',
      ),
      isFalse,
    );
  });

  test('compares major, minor, patch, and semver pre-releases accurately', () {
    expect(
      VersionHelper.isNewerVersion(
        current: '1.10.7-20261119',
        candidate: 'v1.11.0',
      ),
      isTrue,
    );
    expect(
      VersionHelper.isNewerVersion(
        current: '1.11.0',
        candidate: '1.10.99',
      ),
      isFalse,
    );
    expect(
      VersionHelper.isNewerVersion(
        current: '1.11.0-rc.1',
        candidate: '1.11.0-rc.2',
      ),
      isTrue,
    );
    expect(
      VersionHelper.isNewerVersion(
        current: '1.11.0-rc.2-20261119',
        candidate: '1.11.0',
      ),
      isTrue,
    );
    expect(
      VersionHelper.isNewerVersion(
        current: '1.11.0',
        candidate: 'invalid-tag',
      ),
      isFalse,
    );
  });
}
