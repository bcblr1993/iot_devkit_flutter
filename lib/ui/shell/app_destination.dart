import '../../models/app_feature.dart';
import '../../services/feature_visibility_provider.dart';

enum AppDestination {
  simulator,
  timestamp,
  json,
  certificates,
  textDiff,
  timesheet,
}

extension AppDestinationFeature on AppDestination {
  AppFeature? get feature {
    return switch (this) {
      AppDestination.textDiff => AppFeature.textDiff,
      AppDestination.timesheet => AppFeature.timesheet,
      _ => null,
    };
  }
}

List<AppDestination> visibleAppDestinations(
  FeatureVisibilityProvider features,
) {
  return AppDestination.values.where((destination) {
    final feature = destination.feature;
    return feature == null || features.isEnabled(feature);
  }).toList(growable: false);
}
