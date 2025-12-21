import 'package:package_info_plus/package_info_plus.dart';

class VersionHelper {
  static Future<String> getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}-${packageInfo.buildNumber}';
  }

  static Future<String> getAppName() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.appName;
  }
}
