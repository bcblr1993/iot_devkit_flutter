import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/models/app_feature.dart';
import 'package:iot_devkit/services/feature_visibility_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('optional features are disabled by default', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = FeatureVisibilityProvider();

    await provider.initialized;

    expect(provider.isEnabled(AppFeature.textDiff), isFalse);
    expect(provider.isEnabled(AppFeature.timesheet), isFalse);
  });

  test('feature preference is persisted and restored', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = FeatureVisibilityProvider();
    await provider.initialized;

    await provider.setEnabled(AppFeature.textDiff, true);

    final restored = FeatureVisibilityProvider();
    await restored.initialized;
    expect(restored.isEnabled(AppFeature.textDiff), isTrue);
  });

  test('existing timesheet preference remains compatible', () async {
    SharedPreferences.setMockInitialValues({'ts_enabled': true});
    final provider = FeatureVisibilityProvider();

    await provider.initialized;

    expect(provider.isEnabled(AppFeature.timesheet), isTrue);
  });
}
