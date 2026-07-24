enum AppFeature {
  textDiff,
  timesheet,
}

extension AppFeaturePersistence on AppFeature {
  String get storageKey {
    return switch (this) {
      AppFeature.textDiff => 'feature_text_diff_enabled',
      // Keep the existing key so current users do not lose their preference.
      AppFeature.timesheet => 'ts_enabled',
    };
  }

  bool get defaultEnabled => false;
}
