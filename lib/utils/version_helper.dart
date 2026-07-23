import 'package:package_info_plus/package_info_plus.dart';

class VersionHelper {
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
    final match = RegExp(r'(20\d{2})(\d{2})(\d{2})').firstMatch(version);
    if (match == null) {
      return null;
    }
    return '${match.group(1)}-${match.group(2)}-${match.group(3)}';
  }
}
