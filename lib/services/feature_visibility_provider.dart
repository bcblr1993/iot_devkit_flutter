import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_feature.dart';

class FeatureVisibilityProvider extends ChangeNotifier {
  FeatureVisibilityProvider() {
    initialized = _load();
  }

  late final Future<void> initialized;
  final Set<AppFeature> _enabled = <AppFeature>{};

  bool isEnabled(AppFeature feature) => _enabled.contains(feature);

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    for (final feature in AppFeature.values) {
      final enabled =
          preferences.getBool(feature.storageKey) ?? feature.defaultEnabled;
      if (enabled) {
        _enabled.add(feature);
      }
    }
    notifyListeners();
  }

  Future<void> setEnabled(AppFeature feature, bool enabled) async {
    final changed = enabled ? _enabled.add(feature) : _enabled.remove(feature);
    if (!changed) return;

    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(feature.storageKey, enabled);
  }

  Future<void> toggle(AppFeature feature) {
    return setEnabled(feature, !isEnabled(feature));
  }
}
