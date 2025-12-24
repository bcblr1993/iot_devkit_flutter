import 'dart:io';
import 'dart:ui';
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

  /// Conditionally applies a glass effect (blur) or a simple semi-transparent background.
  /// 
  /// [child]: The widget content.
  /// [sigmaX], [sigmaY]: Blur intensity (ignored on Windows/Linux).
  /// [fallbackColor]: The background color to use when blur is disabled (e.g., Colors.black54).
  /// [borderRadius]: Optional border radius for the fallback container.
  static Widget buildGlassEffect({
    required Widget child,
    double sigmaX = 10.0,
    double sigmaY = 10.0,
    Color fallbackColor = Colors.transparent,
    BorderRadius? borderRadius,
  }) {
    if (isHighPerformancePlatform) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
          child: child,
        ),
      );
    } else {
      // On Windows/Linux, return simple container or just the child.
      // If fallbackColor is transparent, we might want to ensure the child has its own color, 
      // or wrap it in a colored container if requested.
      if (fallbackColor != Colors.transparent) {
        return Container(
          decoration: BoxDecoration(
            color: fallbackColor,
            borderRadius: borderRadius,
          ),
          child: child,
        );
      }
      return child;
    }
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
