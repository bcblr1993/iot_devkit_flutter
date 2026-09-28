import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Helper to provide platform-specific UI rendering strategies.
/// Primarily used to optimize performance on Windows/Linux by disabling excessive blur/shadows.
class PlatformUIHelper {
  /// Returns determined platform performance capability.
  /// MacOS and iOS generally handle blur (BackdropFilter) well.
  /// Windows (Skia/Angle) often struggles with BackdropFilter.
  static bool get isHighPerformancePlatform {
    if (kIsWeb) return true;
    return Platform.isMacOS || Platform.isIOS;
  }

  /// Returns a box shadow list optimized for the platform.
  /// Reduces shadow complexity on Windows.
  static List<BoxShadow> optimizeShadows(List<BoxShadow> shadows) {
    if (isHighPerformancePlatform) {
      return shadows;
    }

    // On Windows, simplify: take only the first shadow, or reduce blur.
    if (shadows.isEmpty) return [];

    // Return a simplified single shadow with less spread/blur if possible
    final original = shadows.first;
    return [
      BoxShadow(
        color: original.color,
        blurRadius: original.blurRadius * 0.5, // Reduce blur radius
        offset: original.offset,
        spreadRadius: 0, // Remove spread
      )
    ];
  }
}
