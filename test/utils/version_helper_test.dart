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
}
